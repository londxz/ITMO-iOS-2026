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
            Label(error.title, systemImage: error.systemImage)
        } description: {
            Text(error.message)
        } actions: {
            Button("Повторить", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}

extension AppError {
    var title: String {
        switch self {
        case .networkUnavailable: "Нет подключения"
        case .accessDenied: "Нет доступа"
        case .notFound: "Не найдено"
        case .requestRejected: "Запрос отклонён"
        case .serverUnavailable: "Сервер недоступен"
        case .invalidData: "Ошибка данных"
        case .unknown: "Что-то пошло не так"
        }
    }

    var message: String {
        switch self {
        case .networkUnavailable: "Проверьте интернет и попробуйте ещё раз"
        case .accessDenied: "Сервер не разрешил получить эти данные"
        case .notFound: "Запрошенные данные не найдены"
        case .requestRejected: "Сервер не смог обработать запрос. Попробуйте позже"
        case .serverUnavailable: "Попробуйте чуть позже"
        case .invalidData: "Не удалось прочитать ответ сервера"
        case .unknown: "Попробуйте ещё раз"
        }
    }

    var systemImage: String {
        switch self {
        case .networkUnavailable: "wifi.slash"
        case .accessDenied: "lock"
        case .notFound: "magnifyingglass"
        case .requestRejected: "exclamationmark.bubble"
        case .serverUnavailable: "exclamationmark.icloud"
        case .invalidData: "doc.badge.ellipsis"
        case .unknown: "exclamationmark.triangle"
        }
    }
}
