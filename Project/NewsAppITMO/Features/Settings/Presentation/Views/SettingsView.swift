import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(viewModel: @autoclosure @escaping () -> SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        Form {
            appearanceSection
            storageSection
            aboutSection
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.large)
        .alert(
            viewModel.state.message ?? "",
            isPresented: Binding(
                get: { viewModel.state.message != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.send(.dismissMessage)
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        }
        .task { viewModel.send(.onAppear) }
        .onDisappear { viewModel.send(.onDisappear) }
    }

    private var appearanceSection: some View {
        Section("Оформление") {
            Picker(
                "Тема",
                selection: Binding(
                    get: { viewModel.state.selectedTheme },
                    set: { viewModel.send(.selectTheme($0)) }
                )
            ) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    private var storageSection: some View {
        Section {
            Button {
                viewModel.send(.clearImageCache)
            } label: {
                HStack {
                    Label("Очистить кэш изображений", systemImage: "trash")
                    Spacer()
                    if viewModel.state.isClearingImageCache {
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.state.isClearingImageCache)
        } header: {
            Text("Хранилище")
        } footer: {
            Text("Удалятся только сохранённые обложки и аватары. Закладки останутся.")
        }
    }

    private var aboutSection: some View {
        Section("О приложении") {
            LabeledContent("Название", value: viewModel.state.appName)
            LabeledContent("Версия", value: viewModel.state.appVersion)
            LabeledContent("Сборка", value: viewModel.state.buildNumber)
            LabeledContent("Данные", value: "DEV.to")
            LabeledContent("Команда", value: "ITMO iOS 2026")
        }
    }
}
