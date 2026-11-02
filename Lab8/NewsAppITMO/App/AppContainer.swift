//
//  AppContainer.swift
//  NewsAppITMO
//
//  Created by Родион Холодов on 07.10.2026.
//

import SwiftUI

@MainActor
final class AppContainer {
    let httpClient: any HTTPClient
    let imageCache: any ImageCache
    let bookmarksStorage: any BookmarksStorage

    init(
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        imageCache: any ImageCache = ImageCacheImpl(),
        bookmarksStorage: any BookmarksStorage = FileBookmarksStorage()
    ) {
        self.httpClient = httpClient
        self.imageCache = imageCache
        self.bookmarksStorage = bookmarksStorage
    }
}
