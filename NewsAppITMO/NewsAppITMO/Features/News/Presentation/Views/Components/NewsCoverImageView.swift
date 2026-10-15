//
//  NewsCoverImageView.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 08.10.2026.
//

import SwiftUI

struct NewsCoverImageView: View {
    let url: URL?

    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                AsyncImage(url: url) { phase in
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
