import Combine
import CoreGraphics
import Foundation
import WebKit

/// Retain this object for the duration of an export (for example with @StateObject).
/// WebKit captures page-sized slices; CoreGraphics puts each slice on an A4 page.
/// Text line bounds are used to keep ordinary lines together at page boundaries.
@MainActor
final class PDFExporter: NSObject, ObservableObject, WKNavigationDelegate {
    enum ExportError: LocalizedError {
        case alreadyExporting
        case timedOut
        case invalidLayout
        case invalidPDF
        case tooManyPages
        case webProcessTerminated

        var errorDescription: String? {
            switch self {
            case .alreadyExporting: return "另一个 PDF 正在导出，请稍后再试。"
            case .timedOut: return "PDF 渲染超时。请检查图片链接或缩短文档后重试。"
            case .invalidLayout: return "无法计算文档的打印布局。"
            case .invalidPDF: return "无法生成 PDF 文件。"
            case .tooManyPages: return "文档超过 500 页，请拆分后导出。"
            case .webProcessTerminated: return "网页渲染进程已退出，请重试导出。"
            }
        }
    }

    private var webView: WKWebView?
    private var navigationCompletion: ((Result<Void, Error>) -> Void)?
    private var isExporting = false

    func render(html: String, baseURL: URL? = nil) async throws -> Data {
        guard !isExporting else { throw ExportError.alreadyExporting }
        isExporting = true
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        // Page-authored scripts are unnecessary for Markdown. Our isolated-world
        // layout queries still work when page JavaScript is disabled.
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 794, height: 900), configuration: configuration)
        view.navigationDelegate = self
        webView = view
        defer {
            navigationCompletion = nil
            view.navigationDelegate = nil
            view.stopLoading()
            webView = nil
            isExporting = false
        }

        let _: Void = try await bounded(timeout: 20) { completion in
            self.navigationCompletion = completion
            view.loadHTMLString(html, baseURL: baseURL)
        }
        navigationCompletion = nil
        try Task.checkCancellation()

        let layoutValue: Any = try await bounded(timeout: 10) { completion in
            view.callAsyncJavaScript(Self.layoutScript, arguments: [:], in: nil,
                                     in: .defaultClient, completionHandler: completion)
        }
        guard let layout = layoutValue as? [String: Any],
              let height = layout["height"] as? Double,
              let width = layout["width"] as? Double,
              width.isFinite, height.isFinite, width > 0, height > 0 else {
            throw ExportError.invalidLayout
        }
        let spans = (layout["lines"] as? [[Double]] ?? []).compactMap { values -> ClosedRange<Double>? in
            guard values.count == 2, values[0].isFinite, values[1].isFinite, values[1] > values[0] else { return nil }
            return values[0]...values[1]
        }

        let paper = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        let margin = 36.0
        let scale = (paper.width - 2 * margin) / width
        let pageHeight = (paper.height - 2 * margin) / scale
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData) else { throw ExportError.invalidPDF }
        var mediaBox = paper
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { throw ExportError.invalidPDF }

        var offset = 0.0
        var pageCount = 0
        while offset < height - 0.5 {
            try Task.checkCancellation()
            guard pageCount < 500 else { throw ExportError.tooManyPages }
            let proposedEnd = min(offset + pageHeight, height)
            var end = proposedEnd
            if proposedEnd < height {
                // Move the cut above any intersected text line or small image.
                // Oversized elements are sliced so that pagination always advances.
                for _ in 0..<20 {
                    let crossing = spans.filter {
                        $0.lowerBound < end - 0.25 && $0.upperBound > end + 0.25 &&
                        $0.upperBound - $0.lowerBound < pageHeight && $0.lowerBound > offset + 1
                    }
                    guard let earlier = crossing.map(\.lowerBound).min(), earlier < end else { break }
                    end = earlier
                }
            }
            if end <= offset + 1 { end = proposedEnd }
            let sliceHeight = end - offset
            let pdfConfiguration = WKPDFConfiguration()
            pdfConfiguration.rect = CGRect(x: 0, y: offset, width: width, height: sliceHeight)
            let slice: Data = try await bounded(timeout: 20) { completion in
                view.createPDF(configuration: pdfConfiguration, completionHandler: completion)
            }
            guard let provider = CGDataProvider(data: slice as CFData),
                  let document = CGPDFDocument(provider),
                  let page = document.page(at: 1) else { throw ExportError.invalidPDF }
            let bounds = page.getBoxRect(.mediaBox)
            guard bounds.width > 0, bounds.height > 0 else { throw ExportError.invalidPDF }
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(paper)
            context.saveGState()
            context.clip(to: paper.insetBy(dx: margin, dy: margin))
            context.translateBy(x: margin, y: paper.height - margin - sliceHeight * scale)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -bounds.minX, y: -bounds.minY)
            context.drawPDFPage(page)
            context.restoreGState()
            context.endPDFPage()
            offset = end
            pageCount += 1
        }
        context.closePDF()
        guard output.length > 0 else { throw ExportError.invalidPDF }
        return output as Data
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationCompletion?(.success(()))
        navigationCompletion = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationCompletion?(.failure(error))
        navigationCompletion = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationCompletion?(.failure(error))
        navigationCompletion = nil
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        navigationCompletion?(.failure(ExportError.webProcessTerminated))
        navigationCompletion = nil
    }

    /// Each WebKit callback races a timeout through a single-use continuation gate.
    private func bounded<Value>(timeout: UInt64,
                                start: (@escaping @Sendable (Result<Value, Error>) -> Void) -> Void) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            let gate = CompletionGate(continuation)
            gate.timeout = Task {
                do { try await Task.sleep(nanoseconds: timeout * 1_000_000_000) }
                catch { return }
                gate.resolve(.failure(ExportError.timedOut))
            }
            start { result in
                Task { @MainActor in gate.resolve(result) }
            }
        }
    }

    private static let layoutScript = #"""
    const style = document.createElement('style');
    style.textContent = `
      :root { color-scheme: light !important; }
      html, body { background: white !important; color: #18212b !important; }
      body { margin: 0 !important; padding: 16px !important; box-sizing: border-box; }
      img, svg { max-width: 100% !important; height: auto; }
      pre { white-space: pre-wrap !important; overflow-wrap: anywhere !important; }
      table { max-width: 100% !important; }
      * { animation: none !important; transition: none !important; }
    `;
    document.head.appendChild(style);
    const images = Array.from(document.images, image => image.complete
      ? Promise.resolve()
      : new Promise(resolve => {
          image.addEventListener('load', resolve, { once: true });
          image.addEventListener('error', resolve, { once: true });
        }));
    await Promise.race([
      Promise.all([document.fonts.ready, ...images]),
      new Promise(resolve => setTimeout(resolve, 4000))
    ]);
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    const lines = [];
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const node = walker.currentNode;
      if (!node.textContent.trim() || ['SCRIPT', 'STYLE'].includes(node.parentElement?.tagName)) continue;
      const range = document.createRange();
      range.selectNodeContents(node);
      for (const rect of range.getClientRects()) {
        if (rect.width > 0 && rect.height > 0) lines.push([rect.top + scrollY, rect.bottom + scrollY]);
      }
    }
    for (const element of document.querySelectorAll('img, svg, tr')) {
      const rect = element.getBoundingClientRect();
      if (rect.height > 0) lines.push([rect.top + scrollY, rect.bottom + scrollY]);
    }
    return {
      width: Math.max(document.documentElement.clientWidth, document.documentElement.scrollWidth),
      height: Math.max(document.body.scrollHeight, document.documentElement.scrollHeight),
      lines
    };
    """#
}

@MainActor
private final class CompletionGate<Value> {
    private var continuation: CheckedContinuation<Value, Error>?
    var timeout: Task<Void, Never>?

    init(_ continuation: CheckedContinuation<Value, Error>) {
        self.continuation = continuation
    }

    func resolve(_ result: Result<Value, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeout?.cancel()
        timeout = nil
        continuation.resume(with: result)
    }
}
