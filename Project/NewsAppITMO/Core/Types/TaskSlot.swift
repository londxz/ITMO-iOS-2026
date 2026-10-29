struct TaskSlot: Sendable {
    private var task: Task<Void, Never>?

    var isRunning: Bool {
        task != nil
    }

    @discardableResult
    mutating func replace(with newTask: Task<Void, Never>) -> Task<Void, Never> {
        task?.cancel()
        task = newTask
        return newTask
    }

    mutating func cancel() {
        task?.cancel()
        task = nil
    }

    mutating func clear() {
        task = nil
    }
}
