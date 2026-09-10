import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
    @AppStorage("accent") private var accent = AppAccent.teal.rawValue
    @AppStorage("editorFont") private var editorFont = EditorTypeface.monospaced.rawValue
    @AppStorage("fontSize") private var fontSize = 16.0

    var body: some View {
        Form {
            Section(header: Text("外观")) {
                Picker("主题", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("强调色", selection: $accent) {
                    ForEach(AppAccent.allCases) { Text($0.title).tag($0.rawValue) }
                }
            }
            Section(header: Text("写作")) {
                Picker("编辑字体", selection: $editorFont) {
                    ForEach(EditorTypeface.allCases) { Text($0.title).tag($0.rawValue) }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("字号 · \(Int(fontSize)) pt")
                    Slider(value: $fontSize, in: 12...24, step: 1)
                        .accessibilityLabel("字号")
                }
                Text("愿每一个想法，都有落笔的地方。")
                    .font(.system(size: fontSize, design: (EditorTypeface(rawValue: editorFont) ?? .monospaced).design))
                    .padding(.vertical, 8)
            }
            Section {
                Text("文档通过系统自动保存。将文件保存在 iCloud Drive，即可在使用同一 Apple 账户的设备间同步。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("写作偏好")
        #if os(macOS)
        .padding(24)
        .frame(width: 430)
        #endif
    }
}
