import MarkdownUI
import SwiftUI

struct MarkdownContentView: View {
    let markdown: String
    let baseURL: URL?
    private let content: MarkdownContent

    init(markdown: String, baseURL: URL?) {
        self.markdown = markdown
        self.baseURL = baseURL
        content = MarkdownContent(markdown)
    }

    var body: some View {
        Group {
            if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Текст статьи пока недоступен")
                    .foregroundStyle(.secondary)
            } else if content.renderMarkdown().isEmpty {
                Text(markdown)
            } else {
                // MarkdownUI's nonthrowing CommonMark parser treats unsupported
                // syntax (including DEV.to Liquid tags) as source text.
                Markdown(content, baseURL: baseURL)
                    .markdownTheme(.gitHub)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
