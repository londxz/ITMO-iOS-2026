//
//  MetricsBarView.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 27.10.2026.
//

import SwiftUI

struct MetricsBarView: View {
    let reactionsCount: Int
    let commentsCount: Int
    var onReactionsTap: (() -> Void)?
    var onCommentsTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 20) {
            metric(
                title: "\(max(0, reactionsCount)) реакций",
                systemImage: "heart.fill",
                tint: .red,
                action: onReactionsTap
            )

            Divider()
                .frame(height: 18)

            metric(
                title: "\(max(0, commentsCount)) комментариев",
                systemImage: "bubble.right.fill",
                tint: .secondary,
                action: onCommentsTap
            )
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func metric(
        title: String,
        systemImage: String,
        tint: Color,
        action: (() -> Void)?
    ) -> some View {
        if let action {
            Button(action: action) {
                metricLabel(
                    title: title,
                    systemImage: systemImage,
                    tint: tint
                )
            }
            .buttonStyle(.plain)
        } else {
            metricLabel(
                title: title,
                systemImage: systemImage,
                tint: tint
            )
        }
    }

    private func metricLabel(
        title: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(title)
                .foregroundStyle(.primary)
        }
        .contentShape(Rectangle())
    }
}
