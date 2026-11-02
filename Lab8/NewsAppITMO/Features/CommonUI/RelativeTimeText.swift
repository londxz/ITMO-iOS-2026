//
//  RelativeTimeText.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 08.10.2026.
//

import SwiftUI

struct RelativeTimeText: View {
    let date: Date

    var body: some View {
        Text(date, format: .relative(presentation: .named))
            .environment(\.locale, Locale(identifier: "ru_RU"))
    }
}
