//
//  NewsCoverImageView.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 08.10.2026.
//

import SwiftUI

struct NewsCoverImageView: View {
    let url: URL?
    let imageCache: any ImageCache

    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                CachedAsyncImage(url: url, imageCache: imageCache) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        if url == nil {
                            placeholder
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .clipped()
    }

    private var placeholder: some View {
        Image(systemName: "newspaper")
            .font(.title2)
            .foregroundStyle(.secondary)
    }
}
