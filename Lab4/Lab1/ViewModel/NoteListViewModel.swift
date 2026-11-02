//
//  NoteListViewModel.swift
//  lab1
//
//  Created by Родион Холодов on 01.10.2026.
//

import SwiftData
import Observation
import Foundation

@Observable
final class NoteListViewModel {
    var newNoteTitle = ""
    var newNoteText = ""

    func addNote(context: ModelContext) {
        let title = newNoteTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else { return }

        let note = Note(
            title: title,
            text: newNoteText
        )

        context.insert(note)

        newNoteTitle = ""
        newNoteText = ""
    }

    func deleteNote(
        _ note: Note,
        context: ModelContext
    ) {
        context.delete(note)
    }
}
