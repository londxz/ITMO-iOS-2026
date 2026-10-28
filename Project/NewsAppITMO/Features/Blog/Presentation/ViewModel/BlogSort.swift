enum BlogSort: String, CaseIterable, Hashable, Sendable {
    case fresh
    case topWeek
    case topMonth

    var title: String {
        switch self {
        case .fresh: "Свежие"
        case .topWeek: "Топ недели"
        case .topMonth: "Топ месяца"
        }
    }
}
