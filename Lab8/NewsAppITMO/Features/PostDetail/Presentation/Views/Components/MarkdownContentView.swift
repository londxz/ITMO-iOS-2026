import MarkdownUI
import SwiftUI

struct MarkdownContentView: View {
    let markdown: String
    let baseURL: URL?
    private let content: MarkdownContent

    init(markdown: String, baseURL: URL?) {
        self.markdown = markdown
        self.baseURL = baseURL
        content = MarkdownContent(LiquidTagConverter.convert(markdown))
    }

    var body: some View {
        Group {
            if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Текст статьи пока недоступен")
                    .foregroundStyle(.secondary)
            } else if content.renderMarkdown().isEmpty {
                Text(markdown)
            } else {
                Markdown(content, baseURL: baseURL)
                    .markdownTheme(
                        .gitHub.text {
                            ForegroundColor(.primary)
                            BackgroundColor(nil)
                            FontSize(16)
                        }
                    )
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
