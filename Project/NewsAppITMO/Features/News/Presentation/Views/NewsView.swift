//
//  NewsView.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 08.10.2026.
//

import SwiftUI

struct NewsView: View {
    @StateObject private var viewModel: NewsViewModel

    init(viewModel: @autoclosure @escaping () -> NewsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        content
            .navigationTitle("Новости")
            .navigationBarTitleDisplayMode(.large)
            .task { viewModel.send(.onAppear) }
            .onDisappear { viewModel.send(.onDisappear) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state.initialLoad {
        case .idle, .loading:
            LoadingView()
        case .failed(let error):
            ErrorView(error: error) { viewModel.send(.refresh) }
        case .loaded:
            feed
        }
    }

    private var feed: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if viewModel.state.isEmpty {
                    EmptyStateView(
                        title: "Новостей пока нет",
                        message: "Потяните вниз, чтобы обновить",
                        systemImage: "newspaper"
                    )
                    .containerRelativeFrame(.vertical)
                }

                if let heroPost = viewModel.state.heroPost {
                    sectionHeader("Новость дня!")
                    Button {
                        viewModel.send(.didSelectPost(id: heroPost.id))
                    } label: {
                        NewsHeroCardView(post: heroPost)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }

                if !viewModel.state.posts.isEmpty {
                    sectionHeader("Свежие новости")
                    Divider()
                    ForEach(viewModel.state.posts) { post in
                        Button {
                            viewModel.send(.didSelectPost(id: post.id))
                        } label: {
                            NewsRowView(post: post)
                        }
                        .buttonStyle(.plain)
                        Divider()
                            .padding(.leading)
                    }
                    paginationFooter
                }
            }
        }
        .refreshable {
            await viewModel.send(.refresh)?.value
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title2.bold())
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)
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
