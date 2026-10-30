import SwiftUI

struct PostDetailView: View {
    @StateObject private var viewModel: PostDetailViewModel
    private let imageCache: any ImageCache

    init(
        viewModel: @autoclosure @escaping () -> PostDetailViewModel,
        imageCache: any ImageCache
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.imageCache = imageCache
    }

    var body: some View {
        content
            .navigationTitle("Публикация")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .onAppear { viewModel.send(.onAppear) }
            .onDisappear { viewModel.send(.onDisappear) }
            .alert("Закладки", isPresented: Binding(
                get: { viewModel.state.message != nil },
                set: { if !$0 { viewModel.send(.dismissMessage) } }
            )) {
                Button("OK") { viewModel.send(.dismissMessage) }
            } message: {
                Text(viewModel.state.message ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        if let post = viewModel.state.post {
            article(post)
        } else {
            switch viewModel.state.loadState {
            case .idle, .loading:
                LoadingView()
            case .failed(let error):
                ErrorView(error: error) { viewModel.send(.retry) }
            case .loaded:
                EmptyStateView(title: "Статья недоступна", systemImage: "doc.text")
            }
        }
    }

    private func article(_ post: PostModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cover(post.coverImageURL)

                VStack(alignment: .leading, spacing: 20) {
                    if !post.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(Array(Set(post.tags)).sorted(), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.quaternary, in: Capsule())
                                }
                            }
                        }
                    }

                    Text(post.title)
                        .font(.largeTitle.bold())
                        .textSelection(.enabled)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("post-detail-title")

                    Text("\(post.readingTimeMinutes) мин чтения")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    AuthorHeaderView(
                        author: post.author,
                        publishedAt: post.publishedAt,
                        imageCache: imageCache,
                        action: { viewModel.send(.didSelectAuthor) }
                    )
                    .accessibilityIdentifier("post-detail-author")

                    metrics(post)
                    Divider()
                    MarkdownContentView(markdown: post.bodyMarkdown ?? "", baseURL: post.webURL)
                    Divider()
                    metrics(post)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .refreshable { await viewModel.refresh() }
        .refreshErrorAlert(viewModel.state.refreshError) { viewModel.send(.dismissRefreshError) }
    }

    private func cover(_ url: URL?) -> some View {
        Color.secondary.opacity(0.1)
            .overlay {
                CachedAsyncImage(url: url, imageCache: imageCache) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 220)
            .clipped()
            .accessibilityHidden(true)
    }

    private func metrics(_ post: PostModel) -> some View {
        MetricsBarView(
            reactionsCount: post.reactionsCount,
            commentsCount: post.commentsCount,
            onCommentsTap: { viewModel.send(.didSelectComments) }
        )
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if let post = viewModel.state.post {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    viewModel.send(.toggleBookmark)
                } label: {
                    if viewModel.state.bookmarkUpdate == .loading {
                        ProgressView()
                    } else {
                        Image(systemName: viewModel.state.isBookmarked ? "bookmark.fill" : "bookmark")
                    }
                }
                .disabled(viewModel.state.bookmarkUpdate == .loading)
                .accessibilityLabel(viewModel.state.isBookmarked ? "Удалить из закладок" : "Сохранить в закладки")
                .accessibilityIdentifier("post-detail-bookmark")

                if let webURL = post.webURL {
                    ShareLink(item: webURL, subject: Text(post.title), message: Text(post.title)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Поделиться")
                }
            }
        }
    }
}
