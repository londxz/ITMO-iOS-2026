//
//  BlogView.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 28.10.2026.
//

import SwiftUI

struct BlogView: View {
    @StateObject private var viewModel: BlogViewModel
    private let imageCache: any ImageCache

    init(
        viewModel: @autoclosure @escaping () -> BlogViewModel,
        imageCache: any ImageCache
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.imageCache = imageCache
    }

    var body: some View {
        // один ScrollView на все состояния: если пересоздавать его при смене тега,
        // навигационная панель теряет большой заголовок
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    content
                } header: {
                    tagBar
                }
            }
        }
        .refreshable {
            await viewModel.send(.refresh)?.value
        }
        .navigationTitle("Блог")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
        .task { viewModel.send(.onAppear) }
        .onDisappear { viewModel.send(.onDisappear) }
    }

    private var tagBar: some View {
        VStack(spacing: 0) {
            TagFilterBarView(
                tags: viewModel.state.tags,
                selectedTag: viewModel.state.selectedTag,
                onSelect: { viewModel.send(.selectTag($0)) }
            )
            Divider()
        }
        .background(.bar)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state.initialLoad {
        case .idle, .loading:
            LoadingView()
                .containerRelativeFrame(.vertical) { height, _ in height * 0.7 }
        case .failed(let error):
            ErrorView(error: error) { viewModel.send(.refresh) }
                .containerRelativeFrame(.vertical) { height, _ in height * 0.7 }
        case .loaded where viewModel.state.isEmpty:
            EmptyStateView(
                title: "Статей пока нет",
                message: "Попробуйте другой тег или сортировку",
                systemImage: "doc.text.magnifyingglass"
            )
            .containerRelativeFrame(.vertical) { height, _ in height * 0.7 }
        case .loaded:
            feed
        }
    }

    @ViewBuilder
    private var feed: some View {
        ForEach(viewModel.state.posts) { post in
            BlogCardView(
                post: post,
                imageCache: imageCache,
                onSelectPost: {
                    viewModel.send(.didSelectPost(id: post.id))
                },
                onSelectAuthor: {
                    viewModel.send(
                        .didSelectAuthor(
                            id: post.author.id,
                            username: post.author.username
                        )
                    )
                }
            )
            .padding(.horizontal)
            .padding(.top, 16)
        }

        paginationFooter
    }

    private var sortMenu: some View {
        Menu {
            Picker(
                "Сортировка",
                selection: Binding(
                    get: { viewModel.state.selectedSort },
                    set: { viewModel.send(.selectSort($0)) }
                )
            ) {
                ForEach(BlogSort.allCases, id: \.self) { sort in
                    Text(sort.title).tag(sort)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.state.selectedSort.title)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
        }
        .accessibilityLabel("Сортировка: \(viewModel.state.selectedSort.title)")
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
            // новый id на каждой странице, чтобы onAppear срабатывал снова
            .id(viewModel.state.currentPage)
        }
    }
}
