//
//  NewsCoordinatorView.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import SwiftUI

struct NewsCoordinatorView: View {
    @ObservedObject var coordinator: NewsCoordinator
    let screenFactory: ScreenFactory
    let repository: any NewsRepository

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            NewsView(viewModel: NewsViewModel(repository: repository, router: coordinator))
                .navigationDestination(for: NewsFlowRoute.self) { route in
                    // собираем экраны через фабрику, чтобы не связывать их
                    switch route {
                    case .postDetail(let id):
                        screenFactory.makePostDetailView(id: id)
                    case .authorProfile(let id, let username):
                        screenFactory.makeAuthorProfileView(id: id, username: username)
                    }
                }
        }
    }
}
