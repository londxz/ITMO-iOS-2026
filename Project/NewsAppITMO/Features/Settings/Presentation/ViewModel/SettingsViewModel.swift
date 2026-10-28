import Foundation
import Combine
import OSLog

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var state = SettingsState()

    private let imageCache: any ImageCache
    private let userDefaults: UserDefaults
    private let logger = Logger(subsystem: "NewsAppITMO", category: "SettingsViewModel")

    private var clearCacheTask: Task<Void, Never>?

    init(
        imageCache: any ImageCache,
        userDefaults: UserDefaults = .standard,
        bundle: Bundle = .main
    ) {
        self.imageCache = imageCache
        self.userDefaults = userDefaults

        let info = bundle.infoDictionary ?? [:]
        state.appName = info["CFBundleDisplayName"] as? String
            ?? info["CFBundleName"] as? String
            ?? ""
        state.appVersion = info["CFBundleShortVersionString"] as? String ?? ""
        state.buildNumber = info["CFBundleVersion"] as? String ?? ""
    }

    @discardableResult
    func send(_ action: SettingsAction) -> Task<Void, Never>? {
        switch action {
        case .onAppear:
            let rawValue = userDefaults.string(forKey: SettingsStorageKey.appTheme) ?? ""
            state.selectedTheme = AppTheme(rawValue: rawValue) ?? .system
            return nil
        case .onDisappear:
            cancelClearing()
            return nil
        case .selectTheme(let theme):
            state.selectedTheme = theme
            userDefaults.set(theme.rawValue, forKey: SettingsStorageKey.appTheme)
            return nil
        case .clearImageCache:
            return startClearingImageCache()
        case .dismissMessage:
            state.message = nil
            return nil
        }
    }

    private func startClearingImageCache() -> Task<Void, Never>? {
        guard !state.isClearingImageCache else { return nil }

        state.isClearingImageCache = true
        let task = Task { [weak self] in
            guard let self else { return }
            await self.clearImageCache()
        }
        clearCacheTask = task
        return task
    }

    private func clearImageCache() async {
        do {
            try await imageCache.clearCache()
            guard !Task.isCancelled else { return }
            state.message = "Кэш изображений очищен"
        } catch {
            guard !Task.isCancelled else { return }
            logger.error("image cache clearing failed: \(String(describing: error), privacy: .public)")
            state.message = "Не удалось очистить кэш изображений. Попробуйте ещё раз"
        }
        state.isClearingImageCache = false
        clearCacheTask = nil
    }

    private func cancelClearing() {
        clearCacheTask?.cancel()
        clearCacheTask = nil
        state.isClearingImageCache = false
    }
}
