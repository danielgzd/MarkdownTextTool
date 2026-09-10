# MarkdownTextTool

MarkdownTextTool 是一套原生 SwiftUI Markdown 文本工具，面向 iOS 15+、iPadOS 15+ 和 macOS 12+。项目使用 XcodeGen 维护多平台工程，预览层使用 MarkdownUI，本地核心能力放在 `MarkdownCore` Swift package 中。

## 功能

- 纯文本 Markdown 编辑区
- 编辑、分栏、阅读三种布局
- 实时 Markdown 预览，支持标题、列表、引用、表格、代码块、图片和链接
- Swift 代码块基础语法高亮
- 系统文档打开/保存，支持 `.md` 和 `.markdown`
- 通过系统 Files / iCloud Drive 文档能力打开云端文件
- HTML 和 PDF 导出
- 亮色、暗色、系统外观，以及字体大小和编辑字体偏好
- GitHub Actions 冒烟测试、macOS DMG 构建、iOS/iPadOS 无签名 IPA 和可选签名 IPA

## 本地开发

本机需要 Xcode、Swift Package Manager 和 XcodeGen。若未安装 XcodeGen，可使用 Homebrew：

```bash
brew install xcodegen
```

生成 Xcode 工程：

```bash
bash scripts/generate-project.sh
```

如果命令行工具没有指向完整 Xcode，可临时指定：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/generate-project.sh
```

## 冒烟验证

按当前需求，测试只做冒烟测试：

```bash
bash scripts/smoke.sh
```

该脚本会执行：

- `swift test --scratch-path build/swift-package`
- macOS Debug 构建
- iOS Simulator Debug 构建

## 打包

macOS 开发 DMG：

```bash
bash scripts/build-macos.sh
```

输出文件：

```text
build/MarkdownTextTool-macOS-unsigned.dmg
```

iOS/iPadOS 无签名 IPA 和归档：

```bash
bash scripts/build-ios-unsigned.sh
```

输出文件：

```text
build/MarkdownTextTool-iOS-iPadOS-unsigned.ipa
build/MarkdownTextTool-iOS-unsigned.xcarchive.zip
```

该 IPA 和归档用于 CI 构建验证。无证书 IPA 不能直接安装到物理 iPhone/iPad；真机安装仍需要 Apple 签名。

## iOS 签名 IPA

CI 中推送 tag 后可选生成签名 IPA。需要设置仓库变量：

```text
IOS_SIGNING_ENABLED=true
IOS_EXPORT_METHOD=release-testing
```

需要设置仓库 secrets：

```text
IOS_P12_BASE64
IOS_P12_PASSWORD
IOS_PROFILE_BASE64
APPLE_TEAM_ID
IOS_BUNDLE_ID
```

`IOS_EXPORT_METHOD` 可使用 `release-testing` 或 `app-store-connect`。前者需要 Ad Hoc profile，后者需要 App Store distribution profile。

## GitHub Actions

`.github/workflows/build.yml` 会在 pull request、任意分支 push、tag push 和手动触发时运行。每次 push 都会构建 iOS/iPadOS 无签名 IPA 并上传到 Actions artifact。tag 以 `v` 开头时会创建 GitHub Release，并上传 macOS DMG 和无签名 iOS/iPadOS IPA；如果 iOS 签名配置存在，还会上传签名 IPA。

## 说明

PDF 导出通过 `WKWebView` 渲染 HTML 后生成 A4 PDF。HTML 导出由 `MarkdownCore` 生成独立文档，预览仍由 MarkdownUI 负责。LaTeX 数学公式尚未启用，适合作为后续扩展。
