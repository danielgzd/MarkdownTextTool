import SwiftUI
import MarkdownUI
import MarkdownCore

struct PreviewView: View {
    let content: MarkdownContent
    let baseURL: URL?
    let fontSize: Double

    var body: some View {
        ScrollView {
            Markdown(content, baseURL: baseURL)
                .markdownTheme(.gitHub)
                .markdownTextStyle { FontSize(CGFloat(fontSize)) }
                .markdownCodeSyntaxHighlighter(NativeSyntaxHighlighter())
                .textSelection(.enabled)
                .frame(maxWidth: 760, alignment: .leading)
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color.editorCanvas)
        .environment(\.openURL, OpenURLAction { url in
            guard let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) else {
                return .discarded
            }
            return .systemAction
        })
        .accessibilityIdentifier("markdownPreview")
    }
}

private struct NativeSyntaxHighlighter: CodeSyntaxHighlighter {
    func highlightCode(_ code: String, language: String?) -> Text {
        SyntaxHighlighter.runs(code: code, language: language).reduce(Text("")) { result, run in
            let color: Color
            switch run.kind {
            case .plain: color = .primary
            case .keyword: color = .purple
            case .string: color = .teal
            case .comment: color = .secondary
            case .number: color = .orange
            case .type: color = .blue
            }
            return result + Text(run.text).foregroundColor(color)
        }
    }
}
