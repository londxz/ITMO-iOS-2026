import Foundation

enum LiquidTagConverter {
    private static let idBasedAddresses: [String: String] = [
        "github": "https://github.com/",
        "youtube": "https://www.youtube.com/watch?v=",
        "twitter": "https://twitter.com/i/status/",
        "tweet": "https://twitter.com/i/status/",
        "vimeo": "https://vimeo.com/",
        "codesandbox": "https://codesandbox.io/s/",
        "stackblitz": "https://stackblitz.com/edit/",
        "instagram": "https://www.instagram.com/p/"
    ]

    private static let summaryTags: Set<String> = ["details", "spoiler", "collapsible", "accordion"]

    static func convert(_ markdown: String) -> String {
        guard markdown.contains("{%") else { return markdown }

        var fenceMarker: Character?
        var lines: [String] = []
        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.drop { $0 == " " || $0 == "\t" }
            if let marker = fenceMarker {
                if trimmed.hasPrefix(String(repeating: marker, count: 3)) {
                    fenceMarker = nil
                }
                lines.append(line)
            } else if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                fenceMarker = trimmed.first
                lines.append(line)
            } else {
                lines.append(convertOutsideInlineCode(line))
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func convertOutsideInlineCode(_ line: String) -> String {
        guard line.contains("{%") else { return line }
        return line
            .split(separator: "`", omittingEmptySubsequences: false)
            .enumerated()
            .map { index, part in
                index.isMultiple(of: 2) ? convertText(String(part)) : String(part)
            }
            .joined(separator: "`")
    }

    private static func convertText(_ text: String) -> String {
        guard text.contains("{%") else { return text }

        let callToAction = #/\{%\s*cta\s+(\S+?)\s*%\}(.*?)\{%\s*endcta\s*%\}/#.ignoresCase()
        let withCallsToAction = text.replacing(callToAction) { match in
            let address = String(match.output.1)
            let title = match.output.2.trimmingCharacters(in: .whitespaces)
            return link(to: address, title: title.isEmpty ? address : title)
        }

        let tag = #/\{%\s*(\w+)(.*?)%\}/#
        return withCallsToAction.replacing(tag) { match in
            replacement(for: match.output.1.lowercased(), arguments: String(match.output.2))
        }
    }

    private static func replacement(for tag: String, arguments: String) -> String {
        let summary = arguments.trimmingCharacters(in: .whitespaces)
        let words = arguments
            .split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
            .filter { !$0.isEmpty }

        if summaryTags.contains(tag) {
            return summary.isEmpty ? "" : "**\(summary)**"
        }
        guard let argument = words.first else { return "" }

        switch tag {
        case "user", "organization", "org":
            return link(to: "https://dev.to/\(argument)", title: "@\(argument)")
        case "tag":
            return link(to: "https://dev.to/t/\(argument)", title: "#\(argument)")
        default:
            if argument.hasPrefix("https://") || argument.hasPrefix("http://") {
                return link(to: argument, title: argument)
            }
            guard let base = idBasedAddresses[tag] else { return "" }
            return link(to: base + argument, title: base + argument)
        }
    }

    private static func link(to address: String, title: String) -> String {
        let escapedTitle = title
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        return "[\(escapedTitle)](<\(address)>)"
    }
}
