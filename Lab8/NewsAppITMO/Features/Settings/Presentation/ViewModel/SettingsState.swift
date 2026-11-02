struct SettingsState: Equatable, Sendable {
    var selectedTheme: AppTheme = .system
    var isClearingImageCache = false
    var message: String?

    var appName = ""
    var appVersion = ""
    var buildNumber = ""
}
