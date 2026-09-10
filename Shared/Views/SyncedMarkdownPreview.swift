import MarkdownUI
import MarkdownCore
import SwiftUI

struct SyncedMarkdownPreview: View {
    let content: MarkdownContent
    let baseURL: URL?
    let fontSize: Double
    let scrollProgress: Double

    var body: some View {
        PlatformSyncedScrollView(scrollProgress: scrollProgress) {
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

#if os(iOS)
private struct PlatformSyncedScrollView<Content: View>: UIViewRepresentable {
    let scrollProgress: Double
    let content: Content

    init(scrollProgress: Double, @ViewBuilder content: () -> Content) {
        self.scrollProgress = scrollProgress
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        let host = UIHostingController(rootView: content)
        context.coordinator.host = host
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            host.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.host?.rootView = content
        DispatchQueue.main.async {
            let maximum = max(scrollView.contentSize.height - scrollView.bounds.height, 0)
            let y = maximum * min(max(scrollProgress, 0), 1)
            if abs(scrollView.contentOffset.y - y) > 2 {
                scrollView.setContentOffset(CGPoint(x: 0, y: y), animated: false)
            }
        }
    }

    final class Coordinator {
        var host: UIHostingController<Content>?
    }
}
#else
private struct PlatformSyncedScrollView<Content: View>: NSViewRepresentable {
    let scrollProgress: Double
    let content: Content

    init(scrollProgress: Double, @ViewBuilder content: () -> Content) {
        self.scrollProgress = scrollProgress
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let documentView = FlippedDocumentView(rootView: content)
        scrollView.documentView = documentView
        context.coordinator.documentView = documentView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.documentView?.rootView = content
        DispatchQueue.main.async {
            guard let documentView = context.coordinator.documentView else { return }
            let width = max(scrollView.contentSize.width, 1)
            documentView.updateFrame(width: width, minimumHeight: scrollView.contentSize.height)
            let maximum = max(documentView.frame.height - scrollView.contentSize.height, 0)
            let y = maximum * min(max(scrollProgress, 0), 1)
            if abs(scrollView.contentView.bounds.minY - y) > 2 {
                scrollView.contentView.setBoundsOrigin(NSPoint(x: 0, y: y))
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }
    }

    final class Coordinator {
        var documentView: FlippedDocumentView<Content>?
    }
}

private final class FlippedDocumentView<Content: View>: NSView {
    private let host: NSHostingView<Content>
    override var isFlipped: Bool { true }

    var rootView: Content {
        get { host.rootView }
        set { host.rootView = newValue }
    }

    init(rootView: Content) {
        self.host = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        host.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.topAnchor.constraint(equalTo: topAnchor),
            host.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateFrame(width: CGFloat, minimumHeight: CGFloat) {
        host.frame = CGRect(x: 0, y: 0, width: width, height: minimumHeight)
        let fitting = host.fittingSize
        frame = CGRect(x: 0, y: 0, width: width, height: max(fitting.height, minimumHeight))
    }
}
#endif

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
