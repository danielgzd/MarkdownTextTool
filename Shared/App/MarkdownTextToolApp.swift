import SwiftUI

@main
struct MarkdownTextToolApp: App {
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
    @AppStorage("accent") private var accent = AppAccent.teal.rawValue

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            EditorView(document: file.$document, fileURL: file.fileURL)
                .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
                .tint((AppAccent(rawValue: accent) ?? .teal).color)
                #if os(macOS)
                .frame(minWidth: 720, minHeight: 500)
                #endif
        }
        #if os(macOS)
        Settings {
            SettingsView()
                .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
        }
        #endif
    }
}
