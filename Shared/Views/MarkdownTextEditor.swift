import SwiftUI

#if os(iOS)
import UIKit

struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    @Binding var scrollProgress: Double
    let fontSize: Double
    let typeface: EditorTypeface

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.alwaysBounceVertical = true
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        textView.font = uiFont()
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        if textView.text != text {
            textView.text = text
        }
        textView.font = uiFont()
        if textView.selectedRange != selection, selection.location <= (text as NSString).length {
            textView.selectedRange = selection
        }
    }

    private func uiFont() -> UIFont {
        switch typeface {
        case .monospaced:
            return .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        case .rounded:
            return .systemFont(ofSize: fontSize, weight: .regular).withDesign(.rounded)
        case .system:
            return .systemFont(ofSize: fontSize)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextEditor

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.selection = textView.selectedRange
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selection = textView.selectedRange
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let maximum = max(scrollView.contentSize.height - scrollView.bounds.height, 1)
            parent.scrollProgress = min(max(scrollView.contentOffset.y / maximum, 0), 1)
        }
    }
}

private extension UIFont {
    func withDesign(_ design: UIFontDescriptor.SystemDesign) -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(design) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
#else
import AppKit

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    @Binding var scrollProgress: Double
    let fontSize: Double
    let typeface: EditorTypeface

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.contentView.postsBoundsChangedNotifications = true

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.font = nsFont()
        textView.string = text

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak coordinator = context.coordinator] _ in
            coordinator?.updateScrollProgress()
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.font = nsFont()
        if textView.selectedRange() != selection, selection.location <= (text as NSString).length {
            textView.setSelectedRange(selection)
        }
    }

    private func nsFont() -> NSFont {
        switch typeface {
        case .monospaced:
            return .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        case .rounded:
            return NSFont.systemFont(ofSize: fontSize, weight: .regular)
        case .system:
            return .systemFont(ofSize: fontSize)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextEditor
        weak var textView: NSTextView?
        var boundsObserver: NSObjectProtocol?

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
        }

        deinit {
            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.selection = textView.selectedRange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.selection = textView.selectedRange()
        }

        func updateScrollProgress() {
            guard let textView, let scrollView = textView.enclosingScrollView else { return }
            let visible = scrollView.documentVisibleRect
            let totalHeight = max(textView.bounds.height - visible.height, 1)
            parent.scrollProgress = min(max(visible.minY / totalHeight, 0), 1)
        }
    }
}
#endif
