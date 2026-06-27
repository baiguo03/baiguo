import Foundation

struct Option: Codable {
    let key: String
    let text: String
}

struct Question: Codable {
    let prompt: String
    let options: [Option]
    let answer: Set<String>
    let explanation: String
    let kind: String
}

enum QuestionParser {
    static func parse(_ rawText: String) -> [Question] {
        let summaryAnswers = extractAnswerSummaryAnswers(rawText)
        let freeformAnswers = extractFreeformSummaryAnswers(rawText)
        let normalized = stripAnswerSummary(rawText)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let blocks = splitQuestionBlocks(normalized)
        var objectiveIndex = 0
        var freeformIndex = 0
        var questions: [Question] = []
        for block in blocks {
            let fallbackAnswer = objectiveIndex < summaryAnswers.count ? summaryAnswers[objectiveIndex] : nil
            let fallbackFreeform = freeformIndex < freeformAnswers.count ? freeformAnswers[freeformIndex] : nil
            guard let question = parseBlock(block, fallbackAnswer: fallbackAnswer, fallbackFreeformAnswer: fallbackFreeform) else {
                continue
            }
            if isOpenQuestionKind(question.kind) {
                freeformIndex += 1
            } else {
                objectiveIndex += 1
            }
            questions.append(question)
        }
        return questions
    }

    private static func stripAnswerSummary(_ text: String) -> String {
        let markers = [
            "\u{5355}\u{9009}\u{9898}\u{7b54}\u{6848}",
            "\u{5355}\u{9879}\u{9009}\u{62e9}\u{9898}\u{7b54}\u{6848}",
            "\u{591a}\u{9009}\u{9898}\u{7b54}\u{6848}",
            "\u{5224}\u{65ad}\u{9898}\u{7b54}\u{6848}",
            "\u{540d}\u{8bcd}\u{89e3}\u{91ca}\u{7b54}\u{6848}",
            "\u{7b80}\u{7b54}\u{9898}\u{7b54}\u{6848}",
            "\u{6848}\u{4f8b}\u{5206}\u{6790}\u{9898}\u{7b54}\u{6848}",
            "\u{53c2}\u{8003}\u{7b54}\u{6848}",
            "\u{7b54}\u{6848}\u{6c47}\u{603b}"
        ]
        var kept: [String] = []
        var skippingAnswers = false
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let markerRanges = markers.compactMap { line.range(of: $0) }
            if let firstMarker = markerRanges.min(by: { $0.lowerBound < $1.lowerBound }) {
                let prefix = line[..<firstMarker.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                if !prefix.isEmpty, !isSectionHeading(String(prefix)) {
                    kept.append(String(prefix))
                }
                skippingAnswers = true
                continue
            }
            if skippingAnswers {
                if isSectionHeading(line) {
                    skippingAnswers = false
                }
                continue
            }
            kept.append(line)
        }
        return kept.joined(separator: "\n")
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
            if isSectionHeading(line) {
                continue
            }
            let currentIsCase = current.first.map { isCaseQuestionStart($0) } ?? false
            if isQuestionStart(line), !current.isEmpty, !(currentIsCase && !isCaseQuestionStart(line)) {
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
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var prepared = text
        if let regex = try? NSRegularExpression(pattern: pattern) {
            prepared = regex.stringByReplacingMatches(in: prepared, range: range, withTemplate: "\n$2")
        }
        let stuckQuestionPattern = "([^\\s\\d])(?=(\\d{1,3}[\\.\\x{3001}\\x{ff0e}]\\s*)[^\\n]{0,180}\\s*A\\s*[\\.\\x{ff0e}\\x{3001}:\\x{ff1a}])"
        if let regex = try? NSRegularExpression(pattern: stuckQuestionPattern) {
            let stuckRange = NSRange(prepared.startIndex..<prepared.endIndex, in: prepared)
            prepared = regex.stringByReplacingMatches(in: prepared, range: stuckRange, withTemplate: "$1\n")
        }
        let inlineJudgementPattern = "([^\\s\\d])(?=(\\d{1,3}[\\.\\x{3001}\\x{ff0e}]\\s*)[^\\n]{0,120}[\\x{ff08}\\(]\\s*[\\x{ff09}\\)])"
        if let regex = try? NSRegularExpression(pattern: inlineJudgementPattern) {
            let judgementRange = NSRange(prepared.startIndex..<prepared.endIndex, in: prepared)
            prepared = regex.stringByReplacingMatches(in: prepared, range: judgementRange, withTemplate: "$1\n")
        }
        let spacedJudgementPattern = "(\\s+)(\\d{1,3}[\\.\\x{3001}\\x{ff0e}]\\s*)(?=[^\\n]{0,120}[\\x{ff08}\\(]\\s*[\\x{ff09}\\)])"
        if let regex = try? NSRegularExpression(pattern: spacedJudgementPattern) {
            let judgementRange = NSRange(prepared.startIndex..<prepared.endIndex, in: prepared)
            prepared = regex.stringByReplacingMatches(in: prepared, range: judgementRange, withTemplate: "\n$2")
        }
        let openPattern = "(\\s+)(\\d{1,3}[\\.\\x{3001}\\x{ff0e}]\\s*)(?=[^\\n]{0,120}(\u{586b}\u{7a7a}|\u{7b80}\u{7b54}|\u{914d}\u{4f0d}|____|\u{7b54}\u{6848}[\\x{ff1a}:]))"
        if let regex = try? NSRegularExpression(pattern: openPattern) {
            let openRange = NSRange(prepared.startIndex..<prepared.endIndex, in: prepared)
            prepared = regex.stringByReplacingMatches(in: prepared, range: openRange, withTemplate: "\n$2")
        }
        return prepared
    }

    private static func isQuestionStart(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if isCaseQuestionStart(trimmed) {
            return true
        }
        guard let first = trimmed.first, first.isNumber else { return false }
        return trimmed.contains(".") || trimmed.contains("\u{3001}") || trimmed.contains("\u{ff0e}")
    }

    private static func isCaseQuestionStart(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.hasPrefix("\u{6848}\u{4f8b}") || trimmed.hasPrefix("\u{75c5}\u{4f8b}")) &&
            trimmed.contains(where: { $0.isNumber })
    }

    private static func isSectionHeading(_ line: String) -> Bool {
        let compact = line
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\t", with: "")
        if isAnswerHeading(compact) {
            return false
        }
        let keywords = [
            "\u{5355}\u{9879}\u{9009}\u{62e9}\u{9898}",
            "\u{5355}\u{9009}\u{9898}",
            "\u{591a}\u{9879}\u{9009}\u{62e9}\u{9898}",
            "\u{591a}\u{9009}\u{9898}",
            "\u{5224}\u{65ad}\u{9898}",
            "\u{586b}\u{7a7a}\u{9898}",
            "\u{7b80}\u{7b54}\u{9898}",
            "\u{540d}\u{8bcd}\u{89e3}\u{91ca}",
            "\u{914d}\u{4f0d}\u{9898}",
            "\u{6848}\u{4f8b}\u{5206}\u{6790}\u{9898}"
        ]
        guard keywords.contains(where: { compact.contains($0) }) else { return false }
        return compact.count <= 22 ||
            compact.contains("\u{5171}") ||
            compact.contains("\u{6bcf}\u{9898}") ||
            compact.contains("\u{5206}") ||
            compact.contains("\u{ff08}") ||
            compact.contains("(")
    }

    private static func isAnswerHeading(_ line: String) -> Bool {
        let compact = line
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\t", with: "")
        return [
            "\u{5355}\u{9009}\u{9898}\u{7b54}\u{6848}",
            "\u{5355}\u{9879}\u{9009}\u{62e9}\u{9898}\u{7b54}\u{6848}",
            "\u{591a}\u{9009}\u{9898}\u{7b54}\u{6848}",
            "\u{5224}\u{65ad}\u{9898}\u{7b54}\u{6848}",
            "\u{540d}\u{8bcd}\u{89e3}\u{91ca}\u{7b54}\u{6848}",
            "\u{7b80}\u{7b54}\u{9898}\u{7b54}\u{6848}",
            "\u{6848}\u{4f8b}\u{5206}\u{6790}\u{9898}\u{7b54}\u{6848}",
            "\u{53c2}\u{8003}\u{7b54}\u{6848}",
            "\u{7b54}\u{6848}\u{6c47}\u{603b}"
        ].contains { compact.contains($0) }
    }

    private static func isObjectiveAnswerHeading(_ line: String) -> Bool {
        let compact = line
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\t", with: "")
        return [
            "\u{5355}\u{9009}\u{9898}\u{7b54}\u{6848}",
            "\u{5355}\u{9879}\u{9009}\u{62e9}\u{9898}\u{7b54}\u{6848}",
            "\u{591a}\u{9009}\u{9898}\u{7b54}\u{6848}",
            "\u{5224}\u{65ad}\u{9898}\u{7b54}\u{6848}",
            "\u{7b54}\u{6848}\u{6c47}\u{603b}"
        ].contains { compact.contains($0) }
    }

    private static func isFreeformAnswerHeading(_ line: String) -> Bool {
        let compact = line
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\t", with: "")
        return [
            "\u{540d}\u{8bcd}\u{89e3}\u{91ca}\u{7b54}\u{6848}",
            "\u{7b80}\u{7b54}\u{9898}\u{7b54}\u{6848}",
            "\u{586b}\u{7a7a}\u{9898}\u{7b54}\u{6848}",
            "\u{914d}\u{4f0d}\u{9898}\u{7b54}\u{6848}",
            "\u{6848}\u{4f8b}\u{5206}\u{6790}\u{9898}\u{7b54}\u{6848}"
        ].contains { compact.contains($0) }
    }

    private static func objectiveAnswerHeadingSuffix(_ line: String) -> String {
        let markers = [
            "\u{5355}\u{9009}\u{9898}\u{7b54}\u{6848}",
            "\u{5355}\u{9879}\u{9009}\u{62e9}\u{9898}\u{7b54}\u{6848}",
            "\u{591a}\u{9009}\u{9898}\u{7b54}\u{6848}",
            "\u{5224}\u{65ad}\u{9898}\u{7b54}\u{6848}",
            "\u{7b54}\u{6848}\u{6c47}\u{603b}"
        ]
        let ranges = markers.compactMap { line.range(of: $0) }
        guard let first = ranges.min(by: { $0.lowerBound < $1.lowerBound }) else {
            return line
        }
        return String(line[first.lowerBound...])
    }

    private static func parseBlock(_ block: String, fallbackAnswer: Set<String>? = nil, fallbackFreeformAnswer: String? = nil) -> Question? {
        let compact = collapseWhitespace(block)
        guard !compact.isEmpty else { return nil }

        let answer = extractAnswer(from: compact)
        let resolvedBlockAnswer = answer.isEmpty ? (fallbackAnswer ?? []) : answer
        let explanation = extractExplanation(from: compact)
        let body = removeSuffixLabels(from: compact)
        let optionMatches = optionMarkerMatches(in: body)

        if optionMatches.isEmpty {
            let prompt = cleanPrompt(body)
            let candidateAnswer = answer.isEmpty ? (fallbackAnswer ?? []) : answer
            let isTrueFalse = isTrueFalseQuestion(prompt, answer: candidateAnswer)
            let inlineAnswer = extractFreeformAnswer(from: compact)
            let openAnswer = inlineAnswer.isEmpty ? (fallbackFreeformAnswer ?? "") : inlineAnswer
            if !isTrueFalse {
                return Question(
                    prompt: prompt,
                    options: [
                        Option(key: "A", text: openAnswer.isEmpty ? "\u{67e5}\u{770b}\u{89e3}\u{6790}" : openAnswer)
                    ],
                    answer: Set(["A"]),
                    explanation: explanation == "\u{6682}\u{65e0}\u{89e3}\u{6790}" && !openAnswer.isEmpty ? openAnswer : explanation,
                    kind: inferOpenQuestionKind(prompt)
                )
            }
            return Question(
                prompt: prompt,
                options: [
                    Option(key: "A", text: "\u{6b63}\u{786e}"),
                    Option(key: "B", text: "\u{9519}\u{8bef}")
                ],
                answer: candidateAnswer.isEmpty ? Set(["A"]) : candidateAnswer,
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

    private static func isOpenQuestionKind(_ kind: String) -> Bool {
        kind == "\u{586b}\u{7a7a}\u{9898}" ||
            kind == "\u{7b80}\u{7b54}\u{9898}" ||
            kind == "\u{914d}\u{4f0d}\u{9898}"
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

    private static func extractAnswerSummaryAnswers(_ text: String) -> [Set<String>] {
        var summaryLines: [String] = []
        var collecting = false
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if isObjectiveAnswerHeading(line) {
                summaryLines.append(objectiveAnswerHeadingSuffix(line))
                collecting = true
                continue
            }
            if isAnswerHeading(line) {
                collecting = false
                continue
            }
            if collecting {
                if isSectionHeading(line) {
                    collecting = false
                } else {
                    summaryLines.append(line)
                }
            }
        }
        let summary = summaryLines.joined(separator: " ")
        let pattern = "(\\d{1,3})\\s*[\\.\\x{3001}\\x{ff0e}:\\x{ff1a}]?\\s*([A-Fa-f]+|\u{6b63}\u{786e}|\u{9519}\u{8bef}|\u{5bf9}|\u{9519}|\u{221a}|\u{2713}|\u{00d7}|\u{2717})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(summary.startIndex..<summary.endIndex, in: summary)
        var answers: [Set<String>] = []
        for match in regex.matches(in: summary, range: range) {
            guard
                let answerRange = Range(match.range(at: 2), in: summary)
            else { continue }
            let keys = normalizeAnswerKeys(String(summary[answerRange]))
            if !keys.isEmpty {
                answers.append(keys)
            }
        }
        return answers
    }

    private static func extractFreeformSummaryAnswers(_ text: String) -> [String] {
        var answers: [String] = []
        var current: [String] = []
        var collecting = false

        func flush() {
            let value = cleanFreeformSummaryAnswer(current.joined(separator: " "))
            if !value.isEmpty {
                answers.append(value)
            }
            current.removeAll()
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if isFreeformAnswerHeading(line) {
                flush()
                collecting = true
                continue
            }
            if isObjectiveAnswerHeading(line) {
                flush()
                collecting = false
                continue
            }
            guard collecting else { continue }
            if isSectionHeading(line) {
                flush()
                collecting = false
                continue
            }
            let currentIsCase = current.first.map { isCaseQuestionStart($0) } ?? false
            if isQuestionStart(line), !current.isEmpty, !(currentIsCase && !isCaseQuestionStart(line)) {
                flush()
            }
            current.append(line)
        }
        flush()
        return answers
    }

    private static func cleanFreeformSummaryAnswer(_ value: String) -> String {
        var text = collapseWhitespace(value)
        while let first = text.first, first.isNumber {
            text.removeFirst()
        }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: ".\u{3001}\u{ff0e} "))
        if text.hasPrefix("\u{6848}\u{4f8b}") || text.hasPrefix("\u{75c5}\u{4f8b}") {
            let labels = ["\u{7b54}\u{6848}", "\u{89e3}\u{6790}"]
            if let range = labels.compactMap({ text.range(of: $0) }).min(by: { $0.lowerBound < $1.lowerBound }) {
                text = String(text[range.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "\u{ff1a}: "))
            }
        }
        return text
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

    private static func extractFreeformAnswer(from value: String) -> String {
        let labels = ["\u{6b63}\u{786e}\u{7b54}\u{6848}\u{ff1a}", "\u{6b63}\u{786e}\u{7b54}\u{6848}:", "\u{7b54}\u{6848}\u{ff1a}", "\u{7b54}\u{6848}:"]
        guard let labelRange = firstRange(of: labels, in: value) else { return "" }
        let explanationLabels = ["\u{89e3}\u{6790}\u{ff1a}", "\u{89e3}\u{6790}:"]
        let suffix = String(value[labelRange.upperBound...])
        if let explanationRange = firstRange(of: explanationLabels, in: suffix) {
            return String(suffix[..<explanationRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return suffix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func inferOpenQuestionKind(_ prompt: String) -> String {
        if prompt.contains("\u{914d}\u{4f0d}") || prompt.contains("\u{5339}\u{914d}") {
            return "\u{914d}\u{4f0d}\u{9898}"
        }
        if prompt.contains("\u{7b80}\u{7b54}") || prompt.contains("\u{7b80}\u{8ff0}") || prompt.contains("\u{8bf7}\u{8ff0}") {
            return "\u{7b80}\u{7b54}\u{9898}"
        }
        if prompt.contains("\u{586b}\u{7a7a}") || prompt.contains("____") || prompt.contains("\u{ff08}\u{ff09}") {
            return "\u{586b}\u{7a7a}\u{9898}"
        }
        return "\u{7b80}\u{7b54}\u{9898}"
    }

    private static func isTrueFalseQuestion(_ prompt: String, answer: Set<String>) -> Bool {
        if answer == Set(["A"]) || answer == Set(["B"]) {
            return prompt.contains("\u{6b63}\u{786e}") ||
                prompt.contains("\u{9519}\u{8bef}") ||
                prompt.contains("\u{5224}\u{65ad}") ||
                prompt.contains("\u{662f}\u{5426}") ||
                prompt.contains("\u{ff08}\u{ff09}") ||
                prompt.contains("\u{ff08} \u{ff09}") ||
                prompt.contains("( )") ||
                prompt.contains("()")
        }
        return false
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
