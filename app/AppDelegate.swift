import AppKit
import EventKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store = EKEventStore()
    var alerted = Set<String>()
    var open: [CallWindow] = []
    var statusItem: NSStatusItem!

    var pausedUntil: Date? {
        get { (UserDefaults.standard.object(forKey: "pausedUntil") as? Date).flatMap { $0 > Date() ? $0 : nil } }
        set { UserDefaults.standard.set(newValue, forKey: "pausedUntil"); updateIcon() }
    }

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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }

    func updateIcon() {
        let paused = pausedUntil != nil
        let image = NSImage(systemSymbolName: paused ? "phone.down.fill" : "phone.fill",
                            accessibilityDescription: paused ? "You Have a Call (paused)" : "You Have a Call")
        image?.isTemplate = true
        statusItem?.button?.image = image
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let time = DateFormatter()
        if let pausedUntil {
            time.dateFormat = Calendar.current.isDateInToday(pausedUntil) ? "h:mm a" : "EEE h:mm a"
            menu.addItem(withTitle: "Paused until \(time.string(from: pausedUntil))", action: nil, keyEquivalent: "")
        }
        if let next = upcoming().first {
            time.dateFormat = Calendar.current.isDateInToday(next.startDate) ? "h:mm a" : "EEE h:mm a"
            menu.addItem(withTitle: "Next: \(next.title ?? "(no title)") at \(time.string(from: next.startDate))",
                         action: nil, keyEquivalent: "")
        } else {
            menu.addItem(withTitle: "No meetings in the next 24 hours", action: nil, keyEquivalent: "")
        }
        menu.addItem(.separator())
        if pausedUntil != nil {
            menu.addItem(item("Resume", #selector(resume)))
        }
        menu.addItem(item("Pause for 1 hour", #selector(pauseHour)))
        menu.addItem(item("Pause until tomorrow", #selector(pauseUntilTomorrow)))
        menu.addItem(.separator())
        menu.addItem(item("Test alert now", #selector(testAlert)))
        menu.addItem(item("Quit You Have a Call", #selector(quit)))
    }

    func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc func resume() { pausedUntil = nil }
    @objc func pauseHour() { pausedUntil = Date().addingTimeInterval(3600) }
    @objc func pauseUntilTomorrow() {
        pausedUntil = Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 3600)
    }
    @objc func quit() { NSApp.terminate(nil) }

    @objc func testAlert() {
        guard let next = upcoming().first else { return }
        present(next)
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

    func upcoming() -> [EKEvent] {
        let now = Date()
        return candidates(from: now, to: now.addingTimeInterval(24 * 3600)).filter { $0.startDate > now }
    }

    func tick() {
        updateIcon()
        // Meetings that start while paused are not marked alerted, so one still inside the grace window alerts on resume.
        guard pausedUntil == nil else { return }
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
