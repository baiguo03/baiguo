import Foundation

struct Option {
    let key: String
    let text: String
}

struct Question {
    let prompt: String
    let options: [Option]
    let answer: Set<String>
    let explanation: String
    let kind: String
}

enum QuestionParser {
    static func parse(_ rawText: String) -> [Question] {
        let summaryAnswers = extractAnswerSummaryAnswers(rawText)
        let normalized = stripAnswerSummary(rawText)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let blocks = splitQuestionBlocks(normalized)
        return blocks.enumerated().compactMap { index, block in
            parseBlock(block, fallbackAnswer: summaryAnswers[index + 1])
        }
    }

    private static func stripAnswerSummary(_ text: String) -> String {
        let markers = [
            "\u{5355}\u{9009}\u{9898}\u{7b54}\u{6848}",
            "\u{591a}\u{9009}\u{9898}\u{7b54}\u{6848}",
            "\u{5224}\u{65ad}\u{9898}\u{7b54}\u{6848}",
            "\u{53c2}\u{8003}\u{7b54}\u{6848}",
            "\u{7b54}\u{6848}\u{6c47}\u{603b}"
        ]
        guard let first = markers.compactMap({ text.range(of: $0) }).map(\.lowerBound).min() else {
            return text
        }
        return String(text[..<first])
    }

    private static func splitQuestionBlocks(_ text: String) -> [String] {
        let prepared = insertBreaksBeforeInlineQuestionStarts(text)
        let lines = prepared
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return [] }

        var blocks: [String] = []
        var current: [String] = []
        for line in lines {
            if isQuestionStart(line), !current.isEmpty {
                blocks.append(current.joined(separator: " "))
                current.removeAll()
            }
            current.append(line)
        }
        if !current.isEmpty {
            blocks.append(current.joined(separator: " "))
        }
        return blocks.isEmpty ? [text] : blocks
    }

    private static func insertBreaksBeforeInlineQuestionStarts(_ text: String) -> String {
        let optionMarker = "\\s*A\\s*[\\.\\x{ff0e}\\x{3001}:\\x{ff1a}]"
        let pattern = "(\\s+)(\\d{1,3}[\\.\\x{3001}\\x{ff0e}]\\s*)(?=[^\\n]{0,180}\(optionMarker))"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "\n$2")
    }

    private static func isQuestionStart(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, first.isNumber else { return false }
        return trimmed.contains(".") || trimmed.contains("\u{3001}") || trimmed.contains("\u{ff0e}")
    }

    private static func parseBlock(_ block: String, fallbackAnswer: Set<String>? = nil) -> Question? {
        let compact = collapseWhitespace(block)
        guard !compact.isEmpty else { return nil }

        let answer = extractAnswer(from: compact)
        let resolvedBlockAnswer = answer.isEmpty ? (fallbackAnswer ?? []) : answer
        let explanation = extractExplanation(from: compact)
        let body = removeSuffixLabels(from: compact)
        let optionMatches = optionMarkerMatches(in: body)

        if optionMatches.isEmpty {
            return Question(
                prompt: cleanPrompt(body),
                options: [
                    Option(key: "A", text: "\u{6b63}\u{786e}"),
                    Option(key: "B", text: "\u{9519}\u{8bef}")
                ],
                answer: resolvedBlockAnswer.isEmpty ? Set(["A"]) : resolvedBlockAnswer,
                explanation: explanation,
                kind: "\u{5224}\u{65ad}\u{9898}"
            )
        }

        guard let first = optionMatches.first else { return nil }
        let prompt = cleanPrompt(String(body[..<first.range.lowerBound]))
        var options: [Option] = []
        for index in optionMatches.indices {
            let match = optionMatches[index]
            let nextStart = index + 1 < optionMatches.count ? optionMatches[index + 1].range.lowerBound : body.endIndex
            let text = body[match.range.upperBound..<nextStart].trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                options.append(Option(key: match.key, text: text))
            }
        }

        guard !prompt.isEmpty, !options.isEmpty else { return nil }
        let resolvedAnswer = resolvedBlockAnswer.isEmpty ? Set([options[0].key]) : resolvedBlockAnswer
        let kind = resolvedAnswer.count > 1 ? "\u{591a}\u{9009}\u{9898}" : "\u{5355}\u{9009}\u{9898}"
        return Question(prompt: prompt, options: options, answer: resolvedAnswer, explanation: explanation, kind: kind)
    }

    private static func collapseWhitespace(_ value: String) -> String {
        value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanPrompt(_ value: String) -> String {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = text.first, first.isNumber {
            text.removeFirst()
        }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: ".\u{3001}\u{ff0e} "))
        return text
    }

    private static func extractAnswer(from value: String) -> Set<String> {
        let labels = ["\u{6b63}\u{786e}\u{7b54}\u{6848}\u{ff1a}", "\u{6b63}\u{786e}\u{7b54}\u{6848}:", "\u{7b54}\u{6848}\u{ff1a}", "\u{7b54}\u{6848}:"]
        guard let labelRange = firstRange(of: labels, in: value) else { return [] }
        let explanationLabels = ["\u{89e3}\u{6790}\u{ff1a}", "\u{89e3}\u{6790}:"]
        let suffix = String(value[labelRange.upperBound...])
        let answerText: String
        if let explanationRange = firstRange(of: explanationLabels, in: suffix) {
            answerText = String(suffix[..<explanationRange.lowerBound])
        } else {
            answerText = suffix
        }
        return normalizeAnswerKeys(answerText)
    }

    private static func extractAnswerSummaryAnswers(_ text: String) -> [Int: Set<String>] {
        let markers = [
            "\u{5355}\u{9009}\u{9898}\u{7b54}\u{6848}",
            "\u{591a}\u{9009}\u{9898}\u{7b54}\u{6848}",
            "\u{5224}\u{65ad}\u{9898}\u{7b54}\u{6848}",
            "\u{53c2}\u{8003}\u{7b54}\u{6848}",
            "\u{7b54}\u{6848}\u{6c47}\u{603b}"
        ]
        guard let first = markers.compactMap({ text.range(of: $0) }).min(by: { $0.lowerBound < $1.lowerBound }) else {
            return [:]
        }
        let summary = String(text[first.lowerBound...])
        let pattern = "(\\d{1,3})\\s*[\\.\\x{3001}\\x{ff0e}:\\x{ff1a}]?\\s*([A-Fa-f]+|\u{6b63}\u{786e}|\u{9519}\u{8bef}|\u{5bf9}|\u{9519}|\u{221a}|\u{2713}|\u{00d7}|\u{2717})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }
        let range = NSRange(summary.startIndex..<summary.endIndex, in: summary)
        var answers: [Int: Set<String>] = [:]
        for match in regex.matches(in: summary, range: range) {
            guard
                let numberRange = Range(match.range(at: 1), in: summary),
                let answerRange = Range(match.range(at: 2), in: summary),
                let number = Int(summary[numberRange])
            else { continue }
            let keys = normalizeAnswerKeys(String(summary[answerRange]))
            if !keys.isEmpty {
                answers[number] = keys
            }
        }
        return answers
    }

    private static func normalizeAnswerKeys(_ value: String) -> Set<String> {
        let uppercased = value.uppercased()
        var keys = Set<String>()
        for char in uppercased where ["A", "B", "C", "D", "E", "F"].contains(String(char)) {
            keys.insert(String(char))
        }
        if keys.isEmpty {
            if value.contains("\u{6b63}") || value.contains("\u{5bf9}") || value.contains("\u{221a}") || value.contains("\u{2713}") {
                keys.insert("A")
            } else if value.contains("\u{8bef}") || value.contains("\u{9519}") || value.contains("\u{00d7}") || value.contains("\u{2717}") {
                keys.insert("B")
            }
        }
        return keys
    }

    private static func extractExplanation(from value: String) -> String {
        let labels = ["\u{89e3}\u{6790}\u{ff1a}", "\u{89e3}\u{6790}:"]
        guard let labelRange = firstRange(of: labels, in: value) else {
            return "\u{6682}\u{65e0}\u{89e3}\u{6790}"
        }
        return value[labelRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removeSuffixLabels(from value: String) -> String {
        let labels = ["\u{6b63}\u{786e}\u{7b54}\u{6848}\u{ff1a}", "\u{6b63}\u{786e}\u{7b54}\u{6848}:", "\u{7b54}\u{6848}\u{ff1a}", "\u{7b54}\u{6848}:", "\u{89e3}\u{6790}\u{ff1a}", "\u{89e3}\u{6790}:"]
        guard let first = labels.compactMap({ value.range(of: $0) }).map(\.lowerBound).min() else {
            return value
        }
        return String(value[..<first]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstRange(of labels: [String], in value: String) -> Range<String.Index>? {
        labels.compactMap { value.range(of: $0) }.min { $0.lowerBound < $1.lowerBound }
    }

    private static func optionMarkerMatches(in value: String) -> [(key: String, range: Range<String.Index>)] {
        let pattern = "([A-F])\\s*[\\.\\x{ff0e}\\x{3001}:\\x{ff1a}]\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.matches(in: value, range: nsRange).compactMap { result in
            guard
                result.numberOfRanges >= 2,
                let markerRange = Range(result.range(at: 0), in: value),
                let keyRange = Range(result.range(at: 1), in: value)
            else { return nil }
            return (String(value[keyRange]).uppercased(), markerRange)
        }
    }
}
