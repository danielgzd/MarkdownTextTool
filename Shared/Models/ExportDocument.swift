import SwiftUI
import UniformTypeIdentifiers

/// The file exporter selects .pdf or .html to give the output its correct extension.
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf, .html] }
    static var writableContentTypes: [UTType] { [.pdf, .html] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
