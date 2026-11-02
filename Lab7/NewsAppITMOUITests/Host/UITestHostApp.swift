import SwiftUI

/// Uses the production screens and repositories with test-only composition.
@main
struct UITestHostApp: App {
    @StateObject private var coordinator = AppCoordinator()
    private let container: AppContainer

    init() {
        guard let name = ProcessInfo.processInfo.environment["UITEST_SCENARIO"],
              let scenario = UITestScenario(rawValue: name) else {
            preconditionFailure("The UI test host requires a valid UITEST_SCENARIO")
        }
        container = AppContainer(httpClient: MockHTTPClient(scenario: scenario))
    }

    var body: some Scene {
        WindowGroup {
            AppRootTabView(coordinator: coordinator, container: container)
        }
    }
}
