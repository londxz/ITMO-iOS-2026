//
//  CachedAsyncImage.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 27.10.2026.
//

import SwiftUI

struct CachedAsyncImage<Content: View>: View {
    private let url: URL?
    private let imageCache: any ImageCache
    private let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty
    @State private var loadTask: Task<Void, Never>?

    init(
        url: URL?,
        imageCache: any ImageCache,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.imageCache = imageCache
        self.content = content
    }

    var body: some View {
        content(phase)
            .onAppear(perform: startLoading)
            .onChange(of: url) {
                startLoading()
            }
            .onDisappear(perform: cancelLoading)
    }

    private func startLoading() {
        cancelLoading()
        phase = .empty

        guard let url else { return }

        let imageCache = imageCache
        loadTask = Task { @MainActor in
            do {
                let data = try await imageCache.data(for: url)
                try Task.checkCancellation()

                guard let image = UIImage(data: data) else {
                    throw NetworkError.invalidResponse
                }

                phase = .success(Image(uiImage: image))
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled,
                      error as? NetworkError != .cancelled
                else { return }

                phase = .failure(error)
            }
        }
    }

    private func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
    }
}
