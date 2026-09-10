import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Declared in both app targets with the md and markdown filename extensions.
    static let markdownDocument = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.markdownDocument, .plainText] }
    static var writableContentTypes: [UTType] { [.markdownDocument] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try self.init(data: data)
    }

    /// Markdown is stored as UTF-8; an optional UTF-8 BOM is accepted on import.
    init(data: Data) throws {
        let payload = data.starts(with: [0xEF, 0xBB, 0xBF]) ? Data(data.dropFirst(3)) : data
        guard let text = String(data: payload, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
