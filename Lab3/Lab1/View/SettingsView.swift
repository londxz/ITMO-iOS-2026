//
//  SettingsView.swift
//  lab1
//
//  Created by Родион Холодов on 01.10.2026.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Сортировка") {
                Toggle(
                    "Сначала новые",
                    isOn: $settings.sortNewestFirst
                )
            }
        }
        .navigationTitle("Настройки")
    }
}

#Preview {
    SettingsView()
}
