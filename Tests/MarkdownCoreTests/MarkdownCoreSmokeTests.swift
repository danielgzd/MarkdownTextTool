import XCTest
@testable import MarkdownCore

final class MarkdownCoreSmokeTests: XCTestCase {
    func testHTMLSmokeRendersCommonMarkdown() throws {
        let html = try MarkdownRenderer.html(markdown: """
        # Title

        - [x] Done
        - [ ] Next

        | A | B |
        | :- | -: |
        | **one** | `two` |

        ```swift
        let value = "ok"
        ```
        """)

        XCTAssertTrue(html.contains("<h1>Title</h1>"))
        XCTAssertTrue(html.contains("<input type=\"checkbox\" checked disabled>"))
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<strong>one</strong>"))
        XCTAssertTrue(html.contains("language-swift"))
    }

    func testHTMLSmokeEscapesUnsafeContent() throws {
        let html = try MarkdownRenderer.html(markdown: #"Hello <script>alert("x")</script> & goodbye"#)

        XCTAssertFalse(html.contains("<script>alert"))
        XCTAssertTrue(html.contains("&lt;script&gt;alert(\"x\")&lt;/script&gt; &amp; goodbye"))
    }

    func testSwiftSyntaxSmoke() {
        let runs = SyntaxHighlighter.runs(code: #"let value = "ok" // done"#, language: "swift")

        XCTAssertTrue(runs.contains(SyntaxRun(text: "let", kind: .keyword)))
        XCTAssertTrue(runs.contains(SyntaxRun(text: #""ok""#, kind: .string)))
        XCTAssertTrue(runs.contains(SyntaxRun(text: "// done", kind: .comment)))
    }
}
