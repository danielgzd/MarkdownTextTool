import SwiftUI
import UniformTypeIdentifiers

struct FolderWorkspaceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var folderURL: URL?
    @State private var files: [URL] = []
    @State private var selectedFile: URL?
    @State private var document = MarkdownDocument()
    @State private var showFolderImporter = false
    @State private var showNewFilePrompt = false
    @State private var newFileName = "Untitled.md"
    @State private var saveTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(minWidth: 230, idealWidth: 260, maxWidth: 320)
            Divider()
            if selectedFile == nil {
                emptyState
            } else {
                EditorView(document: $document, fileURL: selectedFile, showsFolderButton: false)
            }
        }
        .frame(minWidth: 860, minHeight: 560)
        .fileImporter(isPresented: $showFolderImporter, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            handleFolderImport(result)
        }
        .alert("新建 Markdown 文件", isPresented: $showNewFilePrompt) {
            TextField("文件名", text: $newFileName)
            Button("创建") { createFile() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("文件会创建在当前文件夹根目录。")
        }
        .alert("无法完成操作", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: document.text) { _ in
            guard !isLoading else { return }
            scheduleSave()
        }
        .onDisappear {
            saveTask?.cancel()
            saveNow()
            folderURL?.stopAccessingSecurityScopedResource()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Label("文件夹", systemImage: "folder")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { showFolderImporter = true } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .help("打开文件夹")
                Button { showNewFilePrompt = true } label: {
                    Image(systemName: "doc.badge.plus")
                }
                .disabled(folderURL == nil)
                .help("新建 Markdown 文件")
            }
            .padding(14)
            Divider()
            if let folderURL {
                Text(folderURL.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                List(files, id: \.self, selection: $selectedFile) { file in
                    Button {
                        load(file)
                    } label: {
                        Label(file.lastPathComponent, systemImage: "doc.plaintext")
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .tag(file)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 34, weight: .light))
                        .foregroundColor(.accentColor)
                    Button { showFolderImporter = true } label: {
                        Label("打开文件夹", systemImage: "folder.badge.plus")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.workspaceChrome)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 38, weight: .light))
                .foregroundColor(.accentColor)
            Text(folderURL == nil ? "打开一个文件夹" : "选择一个 Markdown 文件")
                .font(.headline)
            Text("文件夹模式会自动保存当前选中的 Markdown 文件。")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.editorCanvas)
    }

    private func handleFolderImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            folderURL?.stopAccessingSecurityScopedResource()
            _ = url.startAccessingSecurityScopedResource()
            folderURL = url
            reloadFiles()
            if let first = files.first {
                load(first)
            } else {
                selectedFile = nil
                document = MarkdownDocument()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadFiles() {
        guard let folderURL else { return }
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey]
        let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        files = (enumerator?.compactMap { item -> URL? in
            guard let url = item as? URL else { return nil }
            guard ["md", "markdown"].contains(url.pathExtension.lowercased()) else { return nil }
            return url
        } ?? []).sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private func load(_ file: URL) {
        saveNow()
        do {
            isLoading = true
            defer { isLoading = false }
            let data = try Data(contentsOf: file)
            document = try MarkdownDocument(data: data)
            selectedFile = file
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleSave() {
        guard selectedFile != nil else { return }
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 500_000_000) }
            catch { return }
            saveNow()
        }
    }

    private func saveNow() {
        guard let selectedFile else { return }
        do {
            try Data(document.text.utf8).write(to: selectedFile, options: .atomic)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createFile() {
        guard let folderURL else { return }
        let cleanName = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        let fileName = cleanName.contains(".") ? cleanName : cleanName + ".md"
        let target = folderURL.appendingPathComponent(fileName)
        do {
            guard !FileManager.default.fileExists(atPath: target.path) else {
                errorMessage = "文件已存在。"
                return
            }
            try Data("# \(target.deletingPathExtension().lastPathComponent)\n".utf8).write(to: target)
            reloadFiles()
            load(target)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
