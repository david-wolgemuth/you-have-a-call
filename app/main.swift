import AppKit
import EventKit

let watchedCalendars: Set<String> = ["david.wolgemuth@turquoise.health"]
let onlyVideoMeetings = true
let repeatEvery: TimeInterval = 8
// We still alert when the app starts (or wakes) up to this long after a meeting began.
let lateStartGrace: TimeInterval = 5 * 60

let videoLinkPatterns = [
    #"https://meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}"#,
    #"https://[\w.-]*zoom\.us/j/\d+(\?pwd=[\w.-]+)?"#,
]

let voices: [String] = {
    let say = Process()
    say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    say.arguments = ["-v", "?"]
    let pipe = Pipe()
    say.standardOutput = pipe
    try? say.run()
    let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    return output.split(separator: "\n").compactMap { line in
        line.range(of: #"^.+?(?=\s+[a-z]{2,3}_[A-Z0-9]+\s+#)"#, options: .regularExpression)
            .map { String(line[$0]) }
    }
}()

func videoLink(for event: EKEvent) -> String? {
    let haystack = [event.url?.absoluteString, event.location, event.notes]
        .compactMap { $0 }
        .joined(separator: "\n")
    for pattern in videoLinkPatterns {
        if let range = haystack.range(of: pattern, options: .regularExpression) {
            return String(haystack[range])
        }
    }
    return nil
}

func myStatus(for event: EKEvent) -> EKParticipantStatus? {
    event.attendees?.first(where: { $0.isCurrentUser })?.participantStatus
}

func statusLabel(_ status: EKParticipantStatus?) -> (String, NSColor) {
    switch status {
    case .accepted: return ("Accepted", .systemGreen)
    case .tentative: return ("Maybe", .systemYellow)
    case .pending: return ("Not answered yet", .systemOrange)
    case nil: return ("Your event", .systemBlue)
    default: return ("Unknown response", .systemGray)
    }
}

func alertKey(_ event: EKEvent) -> String {
    "\(event.calendarItemIdentifier)|\(event.startDate.timeIntervalSince1970)"
}

final class CallWindow: NSObject, NSWindowDelegate {
    let event: EKEvent
    let window: NSWindow
    var speaker: Process?
    var ringTimer: Timer?
    var onClose: ((CallWindow, _ snooze: Bool) -> Void)?

    init(event: EKEvent, offset: Int) {
        self.event = event
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()

        let (statusText, statusColor) = statusLabel(myStatus(for: event))
        window.title = "You Have a Call"
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.delegate = self

        let status = NSTextField(labelWithString: statusText)
        status.font = .boldSystemFont(ofSize: 14)
        status.textColor = .white
        status.drawsBackground = true
        status.backgroundColor = statusColor
        status.alignment = .center

        let title = NSTextField(wrappingLabelWithString: event.title ?? "(no title)")
        title.font = .systemFont(ofSize: 26, weight: .semibold)
        title.alignment = .center

        let time = DateFormatter()
        time.dateFormat = "h:mm a"
        let when = NSTextField(labelWithString:
            "\(time.string(from: event.startDate)) to \(time.string(from: event.endDate))")
        when.textColor = .secondaryLabelColor

        let snooze = NSButton(title: "Snooze 1 min", target: self, action: #selector(snoozeTapped))
        let dismiss = NSButton(title: "Dismiss", target: self, action: #selector(dismiss))
        dismiss.keyEquivalent = "\r"
        let buttons = NSStackView(views: [snooze, dismiss])
        buttons.spacing = 12

        let stack = NSStackView(views: [status, title, when, buttons])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        status.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48).isActive = true
        window.contentView = stack

        window.center()
        window.setFrameOrigin(NSPoint(x: window.frame.minX + CGFloat(offset * 30),
                                      y: window.frame.minY - CGFloat(offset * 30)))
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        ring()
        ringTimer = Timer.scheduledTimer(withTimeInterval: repeatEvery, repeats: true) { [weak self] _ in
            self?.ring()
        }
    }

    func ring() {
        if speaker?.isRunning == true { return }
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-v", voices.randomElement() ?? "Zarvox", "\(event.title ?? "Your meeting") has started"]
        try? say.run()
        speaker = say
    }

    func finish(snooze: Bool) {
        ringTimer?.invalidate()
        speaker?.terminate()
        window.delegate = nil
        window.close()
        onClose?(self, snooze)
    }

    @objc func snoozeTapped() { finish(snooze: true) }
    @objc func dismiss() { finish(snooze: false) }
    @objc func cancelOperation(_ sender: Any?) { finish(snooze: false) }
    func windowWillClose(_ notification: Notification) { finish(snooze: false) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = EKEventStore()
    var alerted = Set<String>()
    var open: [CallWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.requestFullAccessToEvents { granted, error in
            DispatchQueue.main.async {
                guard granted else {
                    NSLog("calendar access denied: \(String(describing: error))")
                    NSApp.terminate(nil)
                    return
                }
                self.start()
            }
        }
    }

    func start() {
        if CommandLine.arguments.contains("--list") {
            listToday()
            NSApp.terminate(nil)
            return
        }
        if CommandLine.arguments.contains("--test"), let next = upcoming().first {
            alerted.insert(alertKey(next))
            present(next)
        }
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }

    func events(from start: Date, to end: Date) -> [EKEvent] {
        let calendars = store.calendars(for: .event).filter { watchedCalendars.contains($0.title) }
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    func candidates(from start: Date, to end: Date) -> [EKEvent] {
        events(from: start, to: end).filter { skipReason($0) == nil }
    }

    func listToday() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        for event in events(from: startOfDay, to: startOfDay.addingTimeInterval(24 * 3600)) {
            let verdict = skipReason(event).map { "skip: \($0)" } ?? "ALERT"
            let (status, _) = statusLabel(myStatus(for: event))
            print("\(time.string(from: event.startDate))  \(verdict)  \(event.title ?? "(no title)")  <\(status)>  \(videoLink(for: event) ?? "no video link")")
        }
    }

    func skipReason(_ event: EKEvent) -> String? {
        if event.isAllDay { return "all day" }
        if myStatus(for: event) == .declined { return "declined" }
        if onlyVideoMeetings && videoLink(for: event) == nil { return "no video link" }
        return nil
    }

    func upcoming() -> [EKEvent] {
        let now = Date()
        return candidates(from: now, to: now.addingTimeInterval(24 * 3600)).filter { $0.startDate > now }
    }

    func tick() {
        let now = Date()
        for event in candidates(from: now.addingTimeInterval(-lateStartGrace), to: now.addingTimeInterval(60)) {
            let started = event.startDate <= now
            let recent = now.timeIntervalSince(event.startDate) <= lateStartGrace
            let key = alertKey(event)
            if started && recent && !alerted.contains(key) {
                alerted.insert(key)
                present(event)
            }
        }
    }

    func present(_ event: EKEvent) {
        let call = CallWindow(event: event, offset: open.count)
        call.onClose = { [weak self] call, snooze in
            self?.open.removeAll { $0 === call }
            if snooze {
                Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { _ in self?.present(call.event) }
            }
        }
        open.append(call)
        call.show()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
