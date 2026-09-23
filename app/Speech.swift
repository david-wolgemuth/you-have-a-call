import Foundation

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

// `say` treats <...> as markup (dropping the rest of the sentence) and [[...]] as commands.
func spoken(_ text: String) -> String {
    text.replacingOccurrences(of: #"\[\[[^\]]*\]\]"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"<([^>]*)>"#, with: "$1", options: .regularExpression)
}

func speak(_ text: String) -> Process {
    let say = Process()
    say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    say.arguments = ["-v", voices.randomElement() ?? "Zarvox", spoken(text)]
    try? say.run()
    return say
}
