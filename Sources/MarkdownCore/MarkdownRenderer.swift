import Foundation

public enum MarkdownRenderer {
    public enum RenderError: Error {
        case unterminatedFence
    }

    public static func html(markdown: String, title: String = "Markdown Document", fontSize: Double = 16) throws -> String {
        let body = try renderBlocks(markdown)
        return """
        <!doctype html>
        <html lang="zh-Hans">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escape(title))</title>
          <style>
            :root { color-scheme: light dark; }
            body {
              margin: 0 auto;
              max-width: 760px;
              padding: 32px 24px 56px;
              font: \(fontSize)px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
              color: #18212b;
              background: #ffffff;
            }
            h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.5em 0 .55em; }
            h1 { font-size: 2em; border-bottom: 1px solid #d8dee4; padding-bottom: .25em; }
            h2 { font-size: 1.55em; border-bottom: 1px solid #d8dee4; padding-bottom: .2em; }
            p, ul, ol, blockquote, pre, table { margin: 0 0 1em; }
            a { color: #0969da; }
            img { max-width: 100%; height: auto; }
            blockquote { color: #57606a; border-left: 4px solid #d0d7de; padding-left: 1em; }
            code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: .92em; }
            p code, li code, td code { background: rgba(175,184,193,.2); border-radius: 4px; padding: .16em .32em; }
            pre { background: #f6f8fa; border-radius: 8px; overflow-x: auto; padding: 16px; }
            pre code { background: transparent; padding: 0; }
            table { border-collapse: collapse; width: 100%; display: block; overflow-x: auto; }
            th, td { border: 1px solid #d0d7de; padding: 6px 10px; }
            th { background: #f6f8fa; font-weight: 600; }
            hr { border: 0; border-top: 1px solid #d8dee4; margin: 2em 0; }
            @media (prefers-color-scheme: dark) {
              body { background: #0d1117; color: #e6edf3; }
              h1, h2 { border-bottom-color: #30363d; }
              a { color: #58a6ff; }
              blockquote { color: #8b949e; border-left-color: #30363d; }
              pre, th { background: #161b22; }
              p code, li code, td code { background: rgba(110,118,129,.4); }
              th, td { border-color: #30363d; }
              hr { border-top-color: #30363d; }
            }
          </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private static func renderBlocks(_ markdown: String) throws -> String {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var result: [String] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                index += 1
                continue
            }
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                result.append("<hr>")
                index += 1
                continue
            }
            if let language = fencedLanguage(from: trimmed) {
                index += 1
                var code: [String] = []
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[index])
                    index += 1
                }
                guard index < lines.count else { throw RenderError.unterminatedFence }
                index += 1
                let className = language.isEmpty ? "" : " class=\"language-\(escapeAttribute(language))\""
                result.append("<pre><code\(className)>\(escape(code.joined(separator: "\n")))</code></pre>")
                continue
            }
            if let heading = heading(from: line) {
                result.append("<h\(heading.level)>\(renderInline(heading.text))</h\(heading.level)>")
                index += 1
                continue
            }
            if isTableHeader(at: index, lines: lines) {
                let headers = splitTableRow(lines[index]).map { "<th>\(renderInline($0))</th>" }.joined()
                let alignments = splitTableRow(lines[index + 1]).map(alignmentStyle)
                index += 2
                var rows: [String] = []
                while index < lines.count, lines[index].contains("|"), !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                    let cells = splitTableRow(lines[index])
                    let row = cells.enumerated().map { cellIndex, value -> String in
                        let style = cellIndex < alignments.count ? alignments[cellIndex] : ""
                        return "<td\(style)>\(renderInline(value))</td>"
                    }.joined()
                    rows.append("<tr>\(row)</tr>")
                    index += 1
                }
                result.append("<table><thead><tr>\(headers)</tr></thead><tbody>\(rows.joined())</tbody></table>")
                continue
            }
            if unorderedItem(line) != nil || orderedItem(line) != nil {
                let ordered = orderedItem(line) != nil
                let tag = ordered ? "ol" : "ul"
                var items: [String] = []
                while index < lines.count {
                    guard let item = ordered ? orderedItem(lines[index]) : unorderedItem(lines[index]) else { break }
                    items.append("<li>\(renderTask(renderInline(item)))</li>")
                    index += 1
                }
                result.append("<\(tag)>\(items.joined())</\(tag)>")
                continue
            }
            if trimmed.hasPrefix(">") {
                var quote: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    guard current.hasPrefix(">") else { break }
                    quote.append(String(current.dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                result.append("<blockquote>\(try renderBlocks(quote.joined(separator: "\n")))</blockquote>")
                continue
            }

            var paragraph = [trimmed]
            index += 1
            while index < lines.count {
                let next = lines[index].trimmingCharacters(in: .whitespaces)
                if next.isEmpty || heading(from: lines[index]) != nil || fencedLanguage(from: next) != nil ||
                    unorderedItem(lines[index]) != nil || orderedItem(lines[index]) != nil ||
                    next.hasPrefix(">") || isTableHeader(at: index, lines: lines) {
                    break
                }
                paragraph.append(next)
                index += 1
            }
            result.append("<p>\(renderInline(paragraph.joined(separator: " ")))</p>")
        }

        return result.joined(separator: "\n")
    }

    private static func fencedLanguage(from trimmedLine: String) -> String? {
        guard trimmedLine.hasPrefix("```") else { return nil }
        return String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func heading(from line: String) -> (level: Int, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let marks = trimmed.prefix { $0 == "#" }.count
        guard (1...6).contains(marks), trimmed.dropFirst(marks).first == " " else { return nil }
        return (marks, String(trimmed.dropFirst(marks + 1)))
    }

    private static func unorderedItem(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 2, ["- ", "* ", "+ "].contains(String(trimmed.prefix(2))) else { return nil }
        return String(trimmed.dropFirst(2))
    }

    private static func orderedItem(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let dot = trimmed.firstIndex(of: ".") else { return nil }
        let number = trimmed[..<dot]
        guard !number.isEmpty, number.allSatisfy(\.isNumber), trimmed[trimmed.index(after: dot)] == " " else { return nil }
        return String(trimmed[trimmed.index(dot, offsetBy: 2)...])
    }

    private static func isTableHeader(at index: Int, lines: [String]) -> Bool {
        guard index + 1 < lines.count, lines[index].contains("|") else { return false }
        return splitTableRow(lines[index + 1]).allSatisfy { cell in
            let value = cell.trimmingCharacters(in: .whitespaces)
            return value.contains("-") && value.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " }
        }
    }

    private static func splitTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.first == "|" { trimmed.removeFirst() }
        if trimmed.last == "|" { trimmed.removeLast() }
        return trimmed.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func alignmentStyle(_ cell: String) -> String {
        let value = cell.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix(":"), value.hasSuffix(":") { return " style=\"text-align:center\"" }
        if value.hasSuffix(":") { return " style=\"text-align:right\"" }
        return ""
    }

    private static func renderInline(_ text: String) -> String {
        var output = escape(text)
        output = replaceDelimited("`", in: output) { "<code>\($0)</code>" }
        output = replaceDelimited("**", in: output) { "<strong>\($0)</strong>" }
        output = replaceDelimited("*", in: output) { "<em>\($0)</em>" }
        output = renderImagesAndLinks(output)
        return output
    }

    private static func renderTask(_ html: String) -> String {
        if html.hasPrefix("[x] ") || html.hasPrefix("[X] ") {
            return "<input type=\"checkbox\" checked disabled> " + html.dropFirst(4)
        }
        if html.hasPrefix("[ ] ") {
            return "<input type=\"checkbox\" disabled> " + html.dropFirst(4)
        }
        return html
    }

    private static func renderImagesAndLinks(_ html: String) -> String {
        let withImages = html.replacingOccurrences(
            of: #"!\[([^\]]*)\]\(([^)]+)\)"#,
            with: #"<img src="$2" alt="$1">"#,
            options: .regularExpression
        )
        return withImages.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^)]+)\)"#,
            with: #"<a href="$2">$1</a>"#,
            options: .regularExpression
        )
    }

    private static func replaceDelimited(_ delimiter: String, in source: String, transform: (Substring) -> String) -> String {
        var output = ""
        var remainder = source[...]
        while let start = remainder.range(of: delimiter)?.lowerBound {
            output += remainder[..<start]
            let contentStart = remainder.index(start, offsetBy: delimiter.count)
            guard let end = remainder[contentStart...].range(of: delimiter)?.lowerBound else {
                output += remainder[start...]
                return output
            }
            output += transform(remainder[contentStart..<end])
            remainder = remainder[remainder.index(end, offsetBy: delimiter.count)...]
        }
        output += remainder
        return output
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeAttribute(_ text: String) -> String {
        escape(text).replacingOccurrences(of: "\"", with: "&quot;")
    }
}
