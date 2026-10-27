//
//  CommentMapper.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation
import libxml2

enum CommentMapper {
    static func toDomain(_ dto: CommentDTO) -> CommentModel {
        return CommentModel(
            id: dto.idCode,
            authorName: dto.user.name ?? "Неизвестный автор",
            authorAvatarURL: dto.user.profileImage90.flatMap(URL.init(string:)),
            text: plainText(from: dto.bodyHtml),
            createdAt: dto.createdAt,
            children: dto.children.map { toDomain($0) }
        )
    }

    private static func plainText(from html: String) -> String {
        // The system HTML parser decodes named and numeric entities without using
        // UIKit's main-thread-only attributed-string HTML importer.
        let options = HTML_PARSE_RECOVER.rawValue | HTML_PARSE_NOERROR.rawValue
            | HTML_PARSE_NOWARNING.rawValue | HTML_PARSE_NONET.rawValue
        let document = html.utf8CString.withUnsafeBufferPointer { buffer in
            htmlReadMemory(buffer.baseAddress, Int32(buffer.count - 1), nil, "UTF-8", Int32(options))
        }
        guard let document else { return html.trimmingCharacters(in: .whitespacesAndNewlines) }
        defer { xmlFreeDoc(document) }

        var text = ""
        appendText(from: xmlDocGetRootElement(document), to: &text)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func appendText(from firstNode: xmlNodePtr?, to text: inout String) {
        let blockTags: Set<String> = [
            "p", "div", "blockquote", "pre", "li", "ul", "ol",
            "h1", "h2", "h3", "h4", "h5", "h6", "tr", "hr"
        ]
        var current = firstNode
        while let node = current {
            defer { current = node.pointee.next }
            if node.pointee.type == XML_TEXT_NODE || node.pointee.type == XML_CDATA_SECTION_NODE {
                if let content = node.pointee.content {
                    text += String(cString: content)
                }
            } else if node.pointee.type == XML_ELEMENT_NODE {
                let tag = String(cString: node.pointee.name).lowercased()
                guard !["head", "script", "style"].contains(tag) else { continue }
                if tag == "br" {
                    text += "\n"
                } else {
                    let isBlock = blockTags.contains(tag)
                    if isBlock { appendLineBoundary(to: &text) }
                    appendText(from: node.pointee.children, to: &text)
                    if isBlock { appendLineBoundary(to: &text) }
                }
            }
        }
    }

    private static func appendLineBoundary(to text: inout String) {
        if !text.isEmpty && !text.hasSuffix("\n") {
            text += "\n"
        }
    }
}
