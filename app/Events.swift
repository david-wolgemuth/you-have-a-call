import AppKit
import EventKit

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

func skipReason(_ event: EKEvent) -> String? {
    if event.isAllDay { return "all day" }
    if myStatus(for: event) == .declined { return "declined" }
    if onlyVideoMeetings && videoLink(for: event) == nil { return "no video link" }
    return nil
}
