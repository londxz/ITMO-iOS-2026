//
//  FirstView.swift
//  lab1
//
//  Created by Родион Холодов on 17.09.2026.
//

import SwiftUI
import SwiftData

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Note.createdAt)
    private var notes: [Note]

    @State private var viewModel = NoteListViewModel()

    @ObservedObject private var settings = AppSettings.shared

    private var sortedNotes: [Note] {
        if settings.sortNewestFirst {
            return notes.sorted {
                $0.createdAt > $1.createdAt
            }
        } else {
            return notes.sorted {
                $0.createdAt < $1.createdAt
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Новая заметка") {
                    TextField(
                        "Заголовок",
                        text: $viewModel.newNoteTitle
                    )

                    TextField(
                        "Текст",
                        text: $viewModel.newNoteText,
                        axis: .vertical
                    )
                    .lineLimit(3...6)

                    Button("Добавить заметку") {
                        viewModel.addNote(
                            context: modelContext
                        )
                    }
                }

                Section("Мои заметки") {
                    if sortedNotes.isEmpty {
                        Text("Заметок пока нет")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedNotes) { note in
                            NavigationLink {
                                NoteView(note: note)
                            } label: {
                                VStack(
                                    alignment: .leading,
                                    spacing: 5
                                ) {
                                    Text(note.title)
                                        .font(.headline)

                                    Text(note.text)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)

                                    Text(
                                        note.createdAt,
                                        style: .date
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                viewModel.deleteNote(
                                    sortedNotes[index],
                                    context: modelContext
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Мои заметки")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }
}

#Preview {
    NoteListView()
}
