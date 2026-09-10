# 完整开发提示词：全平台 Markdown 文本工具

适用对象：SwiftUI 开发者  
目标：构建一套原生跨平台 Markdown 编辑器，并实现 GitHub 自动打包发布。

## 1. 需求定义

- 平台：iOS 15+、iPadOS 15+、macOS 12+
- 编辑体验：纯文本编辑区、实时预览、分栏布局、全屏阅读布局
- Markdown：标题、列表、任务列表、引用、表格、代码块、图片链接、普通链接
- 代码高亮：内置 Swift 代码块基础高亮
- 文件：系统文档打开/保存，支持 `.md`、`.markdown`
- 云端文件：通过 Files / iCloud Drive 的系统文档能力访问
- 导出：HTML 和 PDF
- 主题：跟随系统亮/暗模式，并支持用户选择外观、强调色、字体和字号
- 自动化：GitHub Actions 运行冒烟测试，构建 macOS DMG、iOS 无签名归档，并在配置签名后生成 IPA

## 2. 技术选型

| 组件 | 选择 | 理由 |
| --- | --- | --- |
| UI | SwiftUI | 一套共享源码覆盖 iOS、iPadOS、macOS |
| 工程生成 | XcodeGen | 可审查的 YAML 工程配置，适合 CI |
| Markdown 预览 | MarkdownUI | 原生 SwiftUI 渲染，支持 GFM 表格和主题 |
| HTML 导出 | MarkdownCore | 本地轻量渲染器，生成独立 HTML |
| PDF 导出 | WKWebView + CoreGraphics | 复用 HTML 渲染结果并分页输出 PDF |
| 文件模型 | FileDocument + DocumentGroup | 三端统一接入系统文档流程 |
| 测试 | smoke tests | 只验证核心解析与双平台构建 |

## 3. 项目结构

```text
MarkdownTextTool/
├── MarkdownTextTool.xcodeproj
├── Package.swift
├── project.yml
├── Shared/
│   ├── App/
│   ├── Models/
│   ├── Utilities/
│   ├── ViewModels/
│   └── Views/
├── Sources/MarkdownCore/
├── Tests/MarkdownCoreTests/
├── Config/
├── scripts/
└── .github/workflows/
```

## 4. 核心实现

应用入口使用 `DocumentGroup(newDocument:)`，让系统负责新建、打开、保存和 iCloud Drive 文件接入。`MarkdownDocument` 声明 `net.daringfireball.markdown`，并在 iOS/macOS Info.plist 中导入 `.md`、`.markdown` 扩展。

主界面由 `EditorView` 负责，提供三种布局：

- 编辑：只显示 `TextEditor`
- 分栏：宽屏横向分栏，窄屏上下分栏
- 阅读：只显示实时预览

预览由 `PreviewView` 使用 MarkdownUI 渲染，并接入 `NativeSyntaxHighlighter`。导出由 `EditorView` 调用 `MarkdownRenderer.html` 生成 HTML，再交给 `PDFExporter` 生成 PDF。

## 5. 本地命令

生成工程：

```bash
bash scripts/generate-project.sh
```

冒烟测试：

```bash
bash scripts/smoke.sh
```

macOS DMG：

```bash
bash scripts/build-macos.sh
```

iOS 无签名归档：

```bash
bash scripts/build-ios-unsigned.sh
```

iOS 签名 IPA：

```bash
IOS_P12_BASE64=... \
IOS_P12_PASSWORD=... \
IOS_PROFILE_BASE64=... \
APPLE_TEAM_ID=... \
IOS_BUNDLE_ID=... \
IOS_EXPORT_METHOD=release-testing \
bash scripts/build-ios-signed.sh
```

## 6. GitHub Actions

工作流位于 `.github/workflows/build.yml`。默认流程：

- pull request：运行 smoke
- main push：运行 smoke 和构建
- tag push：运行 smoke、构建、创建 GitHub Release
- 签名变量启用后：额外导出签名 IPA

Release 资产：

- `MarkdownTextTool-macOS-unsigned.dmg`
- `MarkdownTextTool-iOS-signed.ipa`，仅在签名配置存在时生成

## 7. 发布准备

首次推送到 GitHub：

```bash
git init
git add .
git commit -m "Initial commit: MarkdownTextTool"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/MarkdownTextTool.git
git push -u origin main
```

创建 tag：

```bash
git tag -a v1.0.0 -m "First stable release"
git push origin v1.0.0
```

## 8. 已知限制

- macOS DMG 是 ad-hoc 签名的开发包，未做 Developer ID 签名和 notarization。
- 未配置 Apple 签名材料时，CI 不会生成可安装 iOS IPA。
- LaTeX 数学公式未默认启用，可后续接入 KaTeX 或 MathJax 的 HTML/PDF 渲染路径。
- `MarkdownCore` 的 HTML 导出覆盖常用 Markdown 语法；编辑器实时预览由 MarkdownUI 提供更完整的 GFM 渲染。
