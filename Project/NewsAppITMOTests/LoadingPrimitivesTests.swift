import XCTest
@testable import NewsAppITMO

final class LoadingPrimitivesTests: XCTestCase {
    func testNewGenerationSupersedesPreviousOne() {
        var generation = RequestGeneration()
        let first = generation.begin()
        let second = generation.begin()

        XCTAssertFalse(generation.isCurrent(first))
        XCTAssertTrue(generation.isCurrent(second))
        XCTAssertFalse(generation.end(first))
        XCTAssertTrue(generation.isActive)
        XCTAssertTrue(generation.end(second))
        XCTAssertFalse(generation.isActive)
    }

    func testInvalidatedGenerationIsNoLongerCurrent() {
        var generation = RequestGeneration()
        let current = generation.begin()
        generation.invalidate()

        XCTAssertFalse(generation.isCurrent(current))
        XCTAssertFalse(generation.isActive)
        XCTAssertFalse(generation.end(current))
    }

    func testGenerationIsNotCurrentInsideCancelledTask() async {
        var generation = RequestGeneration()
        let current = generation.begin()
        let snapshot = generation
        let task = Task {
            while !Task.isCancelled {
                await Task.yield()
            }
            return snapshot.isCurrent(current)
        }

        task.cancel()
        let isCurrentInsideCancelledTask = await task.value

        XCTAssertFalse(isCurrentInsideCancelledTask)
        XCTAssertTrue(snapshot.isCurrent(current))
    }

    func testReplacingTaskCancelsPreviousOne() {
        var slot = TaskSlot()
        let first = slot.replace(with: Task {
            try? await Task.sleep(for: .seconds(10))
        })
        let second = slot.replace(with: Task {
            try? await Task.sleep(for: .seconds(10))
        })

        XCTAssertTrue(first.isCancelled)
        XCTAssertFalse(second.isCancelled)
        XCTAssertTrue(slot.isRunning)

        slot.cancel()
        XCTAssertTrue(second.isCancelled)
        XCTAssertFalse(slot.isRunning)
    }

    func testClearingSlotForgetsFinishedTaskWithoutCancellingIt() {
        var slot = TaskSlot()
        let task = slot.replace(with: Task {})
        slot.clear()

        XCTAssertFalse(slot.isRunning)
        XCTAssertFalse(task.isCancelled)
    }
}
