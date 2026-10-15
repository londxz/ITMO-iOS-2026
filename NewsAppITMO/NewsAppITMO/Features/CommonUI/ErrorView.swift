//
//  ErrorView.swift
//  NewsAppITMO
//
//  Created by n.a.grebenkin on 08.10.2026.
//

import SwiftUI

struct ErrorView: View {
    let error: AppError
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            Button("Повторить", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }

    private var title: String {
        switch error {
        case .networkUnavailable: "Нет подключения"
        case .serverUnavailable: "Сервер недоступен"
        case .invalidData: "Ошибка данных"
        case .notFound: "Не найдено"
        case .unknown: "Что-то пошло не так"
        }
    }

    private var message: String {
        switch error {
        case .networkUnavailable: "Проверьте интернет и попробуйте ещё раз"
        case .serverUnavailable: "Попробуйте чуть позже"
        case .invalidData: "Не удалось прочитать ответ сервера"
        case .notFound: "Запрошенные данные не найдены"
        case .unknown: "Попробуйте ещё раз"
        }
    }

    private var systemImage: String {
        switch error {
        case .networkUnavailable: "wifi.slash"
        case .serverUnavailable: "exclamationmark.icloud"
        case .invalidData: "doc.badge.ellipsis"
        case .notFound: "magnifyingglass"
        case .unknown: "exclamationmark.triangle"
        }
    }
}
