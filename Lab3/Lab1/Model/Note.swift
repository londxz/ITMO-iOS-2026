//
//  Note.swift
//  lab1
//
//  Created by Родион Холодов on 01.10.2026.
//

import SwiftData
import Foundation

@Model
final class Note {
    
    var title: String
    var text: String
    var createdAt: Date
    
    init(
        title: String,
        text: String
    ) {
        self.title = title
        self.text = text
        self.createdAt = .now
    }
}
