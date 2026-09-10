import Foundation
import MarkdownUI

@MainActor
final class EditorViewModel: ObservableObject {
    @Published private(set) var preview = MarkdownContent("")
    @Published private(set) var characterCount = 0
    @Published private(set) var lineCount = 1
    private var pendingPreview: Task<Void, Never>?

    func update(_ text: String, immediately: Bool = false) {
        pendingPreview?.cancel()
        pendingPreview = Task { [weak self] in
            if !immediately {
                do { try await Task.sleep(nanoseconds: 180_000_000) }
                catch { return }
            }
            guard !Task.isCancelled, let self = self else { return }
            self.preview = MarkdownContent(text)
            self.characterCount = text.count
            self.lineCount = text.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
        }
    }

    deinit { pendingPreview?.cancel() }

    static let example = """
    # 把想法写下来

    一页空白，是每一个好想法的起点。

    这是你的 **Markdown 工作台**。在左侧写作，右侧实时预览。

    ## 今天的清单

    - [x] 留下第一个想法
    - [ ] 写一段让自己满意的文字
    - [ ] 导出一份漂亮的文档

    > 不必等到想清楚才动笔。写作本身，就是思考。

    ## 让结构更清晰

    | 语法 | 用途 |
    | :--- | :--- |
    | **粗体** | 突出重点 |
    | *斜体* | 轻轻强调 |
    | `代码` | 保留细节 |

    ```swift
    struct Idea {
        let title: String
        var isReady = false
    }

    let firstIdea = Idea(title: "从这里开始")
    ```

    试试 [Markdown 指南](https://www.markdownguide.org)，或者直接开始写。
    """
}
