//
//  AppSettings.swift
//  lab1
//
//  Created by Родион Холодов on 01.10.2026.
//

import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private let sortNewestFirstKey = "sortNewestFirst"

    @Published var sortNewestFirst: Bool {
        didSet {
            defaults.set(sortNewestFirst, forKey: sortNewestFirstKey)
        }
    }

    private init() {
        if defaults.object(forKey: sortNewestFirstKey) == nil {
            sortNewestFirst = true
        } else {
            sortNewestFirst = defaults.bool(
                forKey: sortNewestFirstKey
            )
        }
    }
}
