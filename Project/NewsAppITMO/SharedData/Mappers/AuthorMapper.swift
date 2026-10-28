//
//  AuthorMapper.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import Foundation

enum AuthorMapper {
    static func toDomain(_ dto: AuthorProfileDTO) -> AuthorModel {
        AuthorModel(
            id: "\(dto.id)",
            username: dto.username,
            name: dto.name,
            avatarURL: nonEmpty(dto.profileImage).flatMap(URL.init(string:)),
            bio: nonEmpty(dto.summary),
            location: nonEmpty(dto.location),
            websiteURL: websiteURL(website: dto.websiteUrl, githubUsername: dto.githubUsername),
            joinedAt: nonEmpty(dto.joinedAt).flatMap(joinedDate)
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }
        return value
    }

    private static func websiteURL(website: String?, githubUsername: String?) -> URL? {
        if let website = nonEmpty(website) {
            return URL(string: website.contains("://") ? website : "https://\(website)")
        }
        if let githubUsername = nonEmpty(githubUsername) {
            return URL(string: "https://github.com/\(githubUsername)")
        }
        return nil
    }

    private static func joinedDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "MMM d, yyyy"
        let normalized = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if let date = formatter.date(from: normalized) {
            return date
        }
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value) {
            return date
        }
        return try? Date.ISO8601FormatStyle().parse(value)
    }
}
