enum SettingsAction: Sendable {
    case onAppear
    case onDisappear
    case selectTheme(AppTheme)
    case clearImageCache
    case dismissMessage
}
