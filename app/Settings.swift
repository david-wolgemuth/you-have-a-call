import Foundation

let watchedCalendars: Set<String> = ["david.wolgemuth@turquoise.health"]
let onlyVideoMeetings = true
let repeatEvery: TimeInterval = 8
// We still alert when the app starts (or wakes) up to this long after a meeting began.
let lateStartGrace: TimeInterval = 5 * 60

let videoLinkPatterns = [
    #"https://meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}"#,
    #"https://[\w.-]*zoom\.us/j/\d+(\?pwd=[\w.-]+)?"#,
]
