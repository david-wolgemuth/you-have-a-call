import AppKit
import EventKit

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
        speaker = speak("You have a call from \(event.title ?? "your meeting")")
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
