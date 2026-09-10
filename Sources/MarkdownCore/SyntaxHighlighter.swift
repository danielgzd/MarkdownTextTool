import Foundation

public enum SyntaxTokenKind: Sendable {
    case plain
    case keyword
    case string
    case comment
    case number
    case type
}

public struct SyntaxRun: Sendable, Equatable {
    public let text: String
    public let kind: SyntaxTokenKind

    public init(text: String, kind: SyntaxTokenKind) {
        self.text = text
        self.kind = kind
    }
}

public enum SyntaxHighlighter {
    private static let swiftKeywords: Set<String> = [
        "actor", "as", "async", "await", "break", "case", "catch", "class", "continue",
        "default", "defer", "do", "else", "enum", "extension", "false", "for", "func",
        "guard", "if", "import", "in", "init", "let", "nil", "private", "public", "return",
        "self", "static", "struct", "switch", "throw", "throws", "true", "try", "var", "while"
    ]
    private static let swiftTypes: Set<String> = ["Bool", "Data", "Double", "Error", "Int", "String", "URL", "Void"]

    public static func runs(code: String, language: String? = nil) -> [SyntaxRun] {
        guard language?.lowercased().contains("swift") ?? false else {
            return [SyntaxRun(text: code, kind: .plain)]
        }

        var result: [SyntaxRun] = []
        var index = code.startIndex
        while index < code.endIndex {
            let character = code[index]
            if character == "/" && code.index(after: index) < code.endIndex && code[code.index(after: index)] == "/" {
                let end = code[index...].firstIndex(of: "\n") ?? code.endIndex
                append(String(code[index..<end]), .comment, to: &result)
                index = end
            } else if character == "\"" {
                let start = index
                index = code.index(after: index)
                while index < code.endIndex {
                    if code[index] == "\\" {
                        index = code.index(after: index)
                        if index < code.endIndex { index = code.index(after: index) }
                    } else if code[index] == "\"" {
                        index = code.index(after: index)
                        break
                    } else {
                        index = code.index(after: index)
                    }
                }
                append(String(code[start..<index]), .string, to: &result)
            } else if character.isNumber {
                let start = index
                repeat { index = code.index(after: index) } while index < code.endIndex && (code[index].isNumber || code[index] == ".")
                append(String(code[start..<index]), .number, to: &result)
            } else if character.isLetter || character == "_" {
                let start = index
                repeat { index = code.index(after: index) } while index < code.endIndex && (code[index].isLetter || code[index].isNumber || code[index] == "_")
                let word = String(code[start..<index])
                if swiftKeywords.contains(word) {
                    append(word, .keyword, to: &result)
                } else if swiftTypes.contains(word) || word.first?.isUppercase == true {
                    append(word, .type, to: &result)
                } else {
                    append(word, .plain, to: &result)
                }
            } else {
                append(String(character), .plain, to: &result)
                index = code.index(after: index)
            }
        }
        return result
    }

    private static func append(_ text: String, _ kind: SyntaxTokenKind, to result: inout [SyntaxRun]) {
        guard !text.isEmpty else { return }
        if let last = result.last, last.kind == kind {
            result[result.count - 1] = SyntaxRun(text: last.text + text, kind: kind)
        } else {
            result.append(SyntaxRun(text: text, kind: kind))
        }
    }
}
