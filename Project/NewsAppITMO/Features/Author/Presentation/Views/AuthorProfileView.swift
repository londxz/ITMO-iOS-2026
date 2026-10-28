import SwiftUI

struct AuthorProfileView: View {
    @StateObject private var viewModel: AuthorProfileViewModel
    private let imageCache: any ImageCache

    init(
        viewModel: @autoclosure @escaping () -> AuthorProfileViewModel,
        imageCache: any ImageCache
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.imageCache = imageCache
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                content
            }
        }
        .refreshable {
            await viewModel.send(.refresh)?.value
        }
        .navigationTitle("Автор")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.send(.onAppear) }
        .onDisappear { viewModel.send(.onDisappear) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state.initialLoad {
        case .idle, .loading:
            LoadingView()
                .containerRelativeFrame(.vertical) { height, _ in height * 0.8 }
        case .failed(let error):
            ErrorView(error: error) { viewModel.send(.refresh) }
                .containerRelativeFrame(.vertical) { height, _ in height * 0.8 }
        case .loaded:
            profile
        }
    }

    @ViewBuilder
    private var profile: some View {
        if let author = viewModel.state.author {
            AuthorBioHeaderView(author: author, imageCache: imageCache)
        }

        Divider()
            .padding(.horizontal)

        postsHeader

        if viewModel.state.posts.isEmpty {
            EmptyStateView(
                title: "Статей пока нет",
                message: "Автор ещё ничего не опубликовал",
                systemImage: "doc.text"
            )
            .padding(.vertical, 32)
        } else {
            ForEach(viewModel.state.posts) { post in
                Button {
                    viewModel.send(.didSelectPost(id: post.id))
                } label: {
                    AuthorPostRowView(post: post)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.bottom, 12)
            }

            paginationFooter
        }
    }

    private var postsHeader: some View {
        HStack {
            Text("Статьи автора")
                .font(.title3.bold())
            Spacer()
            Text(postsCount)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var postsCount: String {
        let count = viewModel.state.posts.count
        return viewModel.state.canLoadMore && count > 0 ? "\(count)+" : "\(count)"
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if viewModel.state.canLoadMore {
            Group {
                if case .failed = viewModel.state.paginationLoad {
                    Button("Не удалось загрузить. Повторить") {
                        viewModel.send(.loadMore)
                    }
                } else {
                    ProgressView()
                        .onAppear { viewModel.send(.loadMore) }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .id(viewModel.state.currentPage)
        }
    }
}
