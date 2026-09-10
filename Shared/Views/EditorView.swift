import SwiftUI
import UniformTypeIdentifiers
import MarkdownCore

struct EditorView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?
    @StateObject private var model = EditorViewModel()
    @StateObject private var pdfExporter = PDFExporter()
    @State private var mode: EditorMode = .split
    @State private var showSettings = false
    @State private var showExporter = false
    @State private var exportedDocument: ExportDocument?
    @State private var exportedType: UTType = .html
    @State private var exporting = false
    @State private var exportTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @AppStorage("fontSize") private var fontSize = 16.0
    @AppStorage("editorFont") private var editorFont = EditorTypeface.monospaced.rawValue
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
    @FocusState private var editorFocused: Bool

    private var documentName: String { fileURL?.deletingPathExtension().lastPathComponent ?? "未命名" }

    var body: some View {
        VStack(spacing: 0) {
            workspaceHeader
            Divider()
            GeometryReader { geometry in
                workspace(width: geometry.size.width)
            }
            Divider()
            statusBar
        }
        .background(Color.workspaceChrome)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Menu {
                    Button { export(.html) } label: { Label("导出 HTML", systemImage: "chevron.left.forwardslash.chevron.right") }
                    Button { export(.pdf) } label: { Label("导出 PDF", systemImage: "doc.richtext") }
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .disabled(exporting)
                .help("导出当前文档")
                Button { showSettings = true } label: {
                    Label("写作偏好", systemImage: "slider.horizontal.3")
                }
                .help("字体与外观")
            }
        }
        .sheet(isPresented: $showSettings) {
            #if os(iOS)
            NavigationView {
                SettingsView()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showSettings = false } } }
            }
            .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
            #else
            VStack(spacing: 0) {
                SettingsView()
                Button("完成") { showSettings = false }
                    .keyboardShortcut(.defaultAction)
                    .padding(.bottom, 20)
            }
            #endif
        }
        .fileExporter(isPresented: $showExporter, document: exportedDocument,
                      contentType: exportedType, defaultFilename: documentName) { result in
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
            exportedDocument = nil
        }
        .alert("无法完成操作", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onAppear { model.update(document.text, immediately: true) }
        .onChange(of: document.text) { model.update($0) }
        .onDisappear { exportTask?.cancel() }
    }

    private var workspaceHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.plaintext")
                .font(.system(size: 19, weight: .medium))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(fileURL?.lastPathComponent ?? "未命名.md")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text("MARKDOWN TEXT TOOL")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.4)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 4)
            Picker("工作区布局", selection: $mode) {
                ForEach(EditorMode.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            .accessibilityIdentifier("layoutPicker")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    @ViewBuilder private func workspace(width: CGFloat) -> some View {
        switch mode {
        case .editor: editorPane
        case .preview: previewPane
        case .split:
            if width >= 700 {
                #if os(macOS)
                HSplitView {
                    editorPane.frame(minWidth: 280)
                    previewPane.frame(minWidth: 280)
                }
                #else
                HStack(spacing: 0) {
                    editorPane.frame(maxWidth: .infinity)
                    Divider()
                    previewPane.frame(maxWidth: .infinity)
                }
                #endif
            } else {
                VStack(spacing: 0) {
                    editorPane.frame(maxHeight: .infinity)
                    Divider()
                    previewPane.frame(maxHeight: .infinity)
                }
            }
        }
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            paneHeading("编辑", detail: "MARKDOWN", symbol: "square.and.pencil")
            ZStack(alignment: .topLeading) {
                TextEditor(text: $document.text)
                    .font(.system(size: fontSize, design: (EditorTypeface(rawValue: editorFont) ?? .monospaced).design))
                    .lineSpacing(6)
                    .padding(16)
                    .focused($editorFocused)
                    .accessibilityLabel("Markdown 编辑区")
                    .accessibilityIdentifier("markdownEditor")
                if document.text.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("从一个想法开始。")
                            .font(.system(size: 24, weight: .medium, design: .serif))
                        Text("在这里写下文字，预览会随之呈现。")
                            .font(.callout)
                        Text("# 标题    **重点**    - 清单")
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .foregroundColor(.secondary)
                    .padding(26)
                    .allowsHitTesting(false)
                }
            }
            if document.text.isEmpty {
                HStack {
                    Button {
                        document.text = EditorViewModel.example
                        editorFocused = true
                    } label: { Label("试写一份示例", systemImage: "sparkles") }
                    .buttonStyle(.borderless)
                    .padding(18)
                    Spacer()
                }
            }
        }
        .background(Color.editorCanvas)
    }

    private var previewPane: some View {
        VStack(spacing: 0) {
            paneHeading("预览", detail: "LIVE", symbol: "doc.richtext")
            if document.text.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundColor(.accentColor)
                    Text("文字在这里成形")
                        .font(.system(size: 17, weight: .medium, design: .serif))
                    Text("标题、清单、代码，每一处都清晰有序。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.editorCanvas)
            } else {
                PreviewView(content: model.preview,
                            baseURL: fileURL?.deletingLastPathComponent(), fontSize: fontSize)
            }
        }
    }

    private func paneHeading(_ title: String, detail: String, symbol: String) -> some View {
        HStack {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .medium))
            Spacer()
            if detail == "LIVE" { Circle().fill(Color.accentColor).frame(width: 5, height: 5) }
            Text(detail).font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.workspaceChrome.opacity(0.6))
    }

    private var statusBar: some View {
        HStack(spacing: 16) {
            Text("\(model.characterCount) 字符")
            Text("\(model.lineCount) 行")
            Spacer()
            if exporting {
                ProgressView().controlSize(.small)
                Text("正在导出…")
            } else {
                Text("UTF-8")
                Image(systemName: "doc.badge.gearshape")
                    .help("由系统管理文档保存")
            }
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(.secondary)
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
    }

    private func export(_ type: UTType) {
        guard !exporting else { return }
        exporting = true
        let source = document.text
        let title = documentName
        let size = fontSize
        let baseURL = fileURL?.deletingLastPathComponent()
        exportTask = Task { @MainActor in
            defer { exporting = false }
            do {
                let html = try MarkdownRenderer.html(markdown: source, title: title, fontSize: size)
                let data: Data
                if type == .pdf { data = try await pdfExporter.render(html: html, baseURL: baseURL) }
                else { data = Data(html.utf8) }
                try Task.checkCancellation()
                exportedType = type
                exportedDocument = ExportDocument(data: data)
                showExporter = true
            } catch is CancellationError {
                // Closing a document cancels its pending export.
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
