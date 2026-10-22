//
//  AppContainer.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import SwiftUI

@MainActor
final class AppContainer {
    let httpClient: HTTPClient
    
    init(httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.httpClient = httpClient
    }

    static func makeForLaunch() -> AppContainer {
        #if DEBUG
        let process = ProcessInfo.processInfo
        if process.arguments.contains("-ui-testing") {
            guard let name = process.environment["UITEST_SCENARIO"],
                  let scenario = MockHTTPClient.Scenario(rawValue: name) else {
                preconditionFailure("UI tests require a valid UITEST_SCENARIO")
            }
            return AppContainer(httpClient: MockHTTPClient(scenario: scenario))
        }
        #endif
        return AppContainer()
    }
}
