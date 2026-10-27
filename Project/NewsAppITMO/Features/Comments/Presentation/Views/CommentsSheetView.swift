import SwiftUI

struct CommentsSheetView: View {
    @StateObject private var viewModel: CommentsViewModel
    @Environment(\.dismiss) private var dismiss
    private let imageCache: any ImageCache

    init(
        viewModel: @autoclosure @escaping () -> CommentsViewModel,
        imageCache: any ImageCache
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.imageCache = imageCache
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                content
            }
            .refreshable {
                await viewModel.send(.refresh)?.value
            }
            .navigationTitle("Комментарии (\(viewModel.state.totalCount))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { viewModel.send(.onAppear) }
        .onDisappear { viewModel.send(.onDisappear) }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.state.isEmpty {
            Group {
                switch viewModel.state.loadState {
                case .idle, .loading:
                    LoadingView()
                case .failed(let error):
                    ErrorView(error: error) { viewModel.send(.retry) }
                case .loaded:
                    EmptyStateView(
                        title: "Комментариев пока нет",
                        message: "Потяните вниз, чтобы обновить",
                        systemImage: "bubble.left.and.bubble.right"
                    )
                }
            }
            .containerRelativeFrame(.vertical)
            .frame(maxWidth: .infinity)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                if case .failed(let error) = viewModel.state.loadState {
                    ErrorView(error: error) { viewModel.send(.retry) }
                }

                ForEach(viewModel.state.threadItems) { item in
                    CommentRowView(item: item, imageCache: imageCache)
                    Divider()
                }
            }
            .padding(.horizontal)
        }
    }
}
