import Foundation

enum DictationFormatter {
    static func format(_ transcript: String, enabled: Bool = true, finalize: Bool = true) -> String {
        guard enabled else { return transcript.trimmingCharacters(in: .whitespacesAndNewlines) }

        let words = transcript
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        var output = ""
        var index = 0

        func appendWord(_ word: String) {
            let cleaned = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }
            if !output.isEmpty && !output.hasSuffix("\n") && !output.hasSuffix(" ") { output += " " }
            let startsSentence = output.isEmpty || output.hasSuffix("\n") || output.hasSuffix(". ") || output.hasSuffix("? ") || output.hasSuffix("! ")
            if startsSentence {
                output += cleaned.prefix(1).uppercased() + cleaned.dropFirst()
            } else {
                output += cleaned
            }
        }

        while index < words.count {
            let word = words[index]
            let normalized = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            let next = index + 1 < words.count ? words[index + 1].lowercased().trimmingCharacters(in: .punctuationCharacters) : ""
            let third = index + 2 < words.count ? words[index + 2].lowercased().trimmingCharacters(in: .punctuationCharacters) : ""

            if normalized == "delete" && next == "last" && third == "word" {
                output = output.replacingOccurrences(of: #"\s*\S+\s*$"#, with: "", options: .regularExpression)
                index += 3
                continue
            }
            if normalized == "new" && (next == "line" || next == "paragraph") {
                output = output.trimmingCharacters(in: .whitespaces)
                if let last = output.last, last.isLetter || last.isNumber { output += "." }
                output += next == "paragraph" ? "\n\n" : "\n"
                index += 2
                continue
            }
            if normalized == "add" && next == "action" && third == "items" {
                appendWord("Action")
                appendWord("items:")
                index += 3
                continue
            }
            if normalized == "bullet" && next == "point" {
                if !output.isEmpty && !output.hasSuffix("\n") { output += "\n" }
                output += "• "
                index += 2
                continue
            }
            if normalized == "question" && next == "mark" {
                output = output.trimmingCharacters(in: .whitespaces) + "?"
                index += 2
                continue
            }
            if normalized == "exclamation" && next == "mark" {
                output = output.trimmingCharacters(in: .whitespaces) + "!"
                index += 2
                continue
            }
            let marks = ["period": ".", "full stop": ".", "comma": ",", "colon": ":", "semicolon": ";"]
            if normalized == "full" && next == "stop" {
                output = output.trimmingCharacters(in: .whitespaces) + "."
                index += 2
                continue
            }
            if let mark = marks[normalized] {
                output = output.trimmingCharacters(in: .whitespaces) + mark
                index += 1
                continue
            }
            if let hour = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12][normalized], next == "am" || next == "pm" {
                appendWord("\(hour)")
                appendWord(next.uppercased())
                index += 2
                continue
            }
            appendWord(normalized == "am" || normalized == "pm" ? normalized.uppercased() : word)
            index += 1
        }

        output = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalize, let last = output.last, last.isLetter || last.isNumber { output += "." }
        return output
    }
}
