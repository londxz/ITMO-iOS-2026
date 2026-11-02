//
//  EmptyStateView.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 08.10.2026.
//

import SwiftUI

struct EmptyStateView: View {
    let title: String
    var message: String = ""
    var systemImage: String = "tray"

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
    }
}
