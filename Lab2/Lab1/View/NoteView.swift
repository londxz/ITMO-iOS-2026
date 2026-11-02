//
//  NoteView.swift
//  lab1
//
//  Created by Родион Холодов on 01.10.2026.
//

import SwiftUI

struct NoteView: View {
    
    @Bindable var note: Note
    
    var body: some View {
        
        Form {
            
            Section("Заметка") {
                
                TextField(
                    "Заголовок",
                    text: $note.title
                )
                
                TextField(
                    "Текст",
                    text: $note.text,
                    axis: .vertical
                )
                .lineLimit(5...15)
            }
            
            Section("Дата создания") {
                
                Text(
                    note.createdAt,
                    style: .date
                )
            }
        }
        .navigationTitle("Заметка")
    }
}
