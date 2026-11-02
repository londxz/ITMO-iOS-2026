import SwiftUI

struct BookmarksView: View {
    @StateObject private var viewModel: BookmarksViewModel
    private let imageCache: any ImageCache

    init(
        viewModel: @autoclosure @escaping () -> BookmarksViewModel,
        imageCache: any ImageCache
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.imageCache = imageCache
    }

    var body: some View {
        content
            .navigationTitle("Закладки")
            .searchable(text: Binding(
                get: { viewModel.state.searchText },
                set: { viewModel.send(.searchTextChanged($0)) }
            ), prompt: "Поиск в закладках")
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
        if viewModel.state.isEmpty {
            switch viewModel.state.loadState {
            case .idle, .loading:
                LoadingView()
            case .failed(let error):
                ErrorView(error: error) { viewModel.send(.retry) }
            case .loaded:
                EmptyStateView(
                    title: "Сохранённых статей пока нет",
                    message: "Сохраните статью, чтобы прочитать её без сети",
                    systemImage: "bookmark"
                )
            }
        } else if viewModel.state.hasNoSearchResults {
            EmptyStateView(title: "Ничего не найдено", message: "Попробуйте другой запрос", systemImage: "magnifyingglass")
        } else {
            bookmarksList
        }
    }

    private var bookmarksList: some View {
        List {
            if case .failed(let error) = viewModel.state.loadState {
                ErrorView(error: error) { viewModel.send(.retry) }
                    .listRowSeparator(.hidden)
            }
            ForEach(viewModel.state.filteredBookmarks) { post in
                Button {
                    viewModel.send(.didSelectPost(id: post.id))
                } label: {
                    BookmarkCardView(post: post, imageCache: imageCache)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("bookmark-\(post.id)")
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.send(.delete(id: post.id))
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                    .disabled(viewModel.state.deletingID != nil)
                }
            }
        }
        .listStyle(.plain)
    }
}
