//
//  Lab1App.swift
//  Lab1
//
//  Created by Родион Холодов on 17.09.2026.
//

import SwiftUI
import SwiftData

@main
struct Lab1App: App {
    var body: some Scene {
        WindowGroup {
            NoteListView()
        }
        .modelContainer(
            for: Note.self
        )
    }
}
