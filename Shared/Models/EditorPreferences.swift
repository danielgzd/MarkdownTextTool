import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self { case .system: return "跟随系统"; case .light: return "浅色"; case .dark: return "深色" }
    }
    var colorScheme: ColorScheme? {
        switch self { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }
}

enum AppAccent: String, CaseIterable, Identifiable {
    case teal, blue, purple
    var id: String { rawValue }
    var title: String {
        switch self { case .teal: return "青绿"; case .blue: return "海蓝"; case .purple: return "鸢紫" }
    }
    var color: Color {
        switch self { case .teal: return .teal; case .blue: return .blue; case .purple: return .purple }
    }
}

enum EditorTypeface: String, CaseIterable, Identifiable {
    case monospaced, system, rounded
    var id: String { rawValue }
    var title: String {
        switch self { case .monospaced: return "等宽字体"; case .system: return "系统字体"; case .rounded: return "圆角字体" }
    }
    var design: Font.Design {
        switch self { case .monospaced: return .monospaced; case .system: return .default; case .rounded: return .rounded }
    }
}

enum EditorMode: String, CaseIterable, Identifiable {
    case editor, split, preview
    var id: String { rawValue }
    var title: String {
        switch self { case .editor: return "编辑"; case .split: return "分栏"; case .preview: return "阅读" }
    }
    var symbol: String {
        switch self { case .editor: return "square.and.pencil"; case .split: return "rectangle.split.2x1"; case .preview: return "doc.richtext" }
    }
}

extension Color {
    static var editorCanvas: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
    static var workspaceChrome: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
}
