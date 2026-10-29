import Foundation

struct RequestGeneration: Sendable {
    private(set) var current: UUID?

    var isActive: Bool {
        current != nil
    }

    mutating func begin() -> UUID {
        let generation = UUID()
        current = generation
        return generation
    }

    func isCurrent(_ generation: UUID) -> Bool {
        current == generation && !Task.isCancelled
    }

    @discardableResult
    mutating func end(_ generation: UUID) -> Bool {
        guard current == generation else { return false }
        current = nil
        return true
    }

    mutating func invalidate() {
        current = nil
    }
}
