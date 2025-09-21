import XCTest
@testable import SuperProductivityCore

final class SuperProductivityCoreTests: XCTestCase {
    func testQuickAddParsesTokens() {
        let parser = QuickAddParser()
        let result = parser.parse("Write report tmrw 3pm 45m high #work @ops")
        XCTAssertEqual(result.title.lowercased(), "write report")
        XCTAssertEqual(result.durationMinutes, 45)
        XCTAssertEqual(result.priority, .high)
        XCTAssertEqual(result.tags, ["work"])
        XCTAssertEqual(result.project, "ops")
        XCTAssertNotNil(result.scheduledStart)
    }

    func testAutoPlanSchedulesTasks() async throws {
        let workHours = WorkHours(start: DateComponents(hour: 9, minute: 0), end: DateComponents(hour: 17, minute: 0), schedulingDays: Set(Weekday.allCases))
        let planner = AutoPlanner(workHours: workHours)
        let now = Date()
        let tasks = [
            Task(title: "A", estimateMinutes: 60),
            Task(title: "B", estimateMinutes: 30)
        ]
        let result = planner.plan(tasks: tasks, busy: [], on: now)
        XCTAssertEqual(result.allocations.count, 2)
    }
}
