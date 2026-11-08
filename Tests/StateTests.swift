import XCTest

final class StateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    func state(hours: Double) -> PetSnapshot {
        var s = PetSnapshot(lastMealAt: now.addingTimeInterval(-hours * 3600))
        s.preferences.schedules = []
        return s
    }
    func testElapsedThresholds() {
        XCTAssertEqual(state(hours: 3).bodyMood(at: now), .fed)
        XCTAssertEqual(state(hours: 4).bodyMood(at: now), .hungry)
        XCTAssertEqual(state(hours: 7).bodyMood(at: now), .tired)
    }
    func testNoMealIsNotInvented() {
        let s = PetSnapshot()
        XCTAssertNil(s.lastMealAt)
        XCTAssertEqual(s.bodyMood(at: now), .hungry)
    }
    func testGiftOverridesDisplayButKeepsCurrentPose() {
        var s = state(hours: 8)
        s.gifts = [Gift(id: "one", food: .apple, status: "pending", createdAt: now)]
        XCTAssertEqual(s.displayMood(at: now), .gift)
        XCTAssertEqual(s.bodyMood(at: now), .tired)
    }
    func testVirtualFoodDoesNotLogRealMeal() {
        var s = state(hours: 8)
        let previous = s.lastMealAt
        s.virtualFedUntil = now.addingTimeInterval(1800)
        XCTAssertEqual(s.bodyMood(at: now), .fed)
        XCTAssertEqual(s.lastMealAt, previous)
        XCTAssertEqual(s.bodyMood(at: now.addingTimeInterval(1801)), .tired)
    }
    func testScheduleGraceAndConfirmedMeal() {
        var s = PetSnapshot()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        s.preferences.timeZone = "UTC"
        s.preferences.schedules = [MealSchedule(id: "Lunch", hour: 12, minute: 30)]
        s.lastMealAt = calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 12))!
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 13))!
        XCTAssertEqual(s.bodyMood(at: date), .hungry)
        s.lastMealAt = date
        XCTAssertEqual(s.bodyMood(at: date), .fed)
    }
    func testQuietHoursAndSerialization() throws {
        var s = state(hours: 2)
        XCTAssertTrue(s.preferences.isQuiet(hour: 23))
        XCTAssertTrue(s.preferences.isQuiet(hour: 6))
        XCTAssertFalse(s.preferences.isQuiet(hour: 12))
        s.preferences.quietEnd = s.preferences.quietStart
        XCTAssertFalse(s.preferences.isQuiet(hour: 23))
        let restored = try JSONDecoder().decode(PetSnapshot.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(restored.lastMealAt, s.lastMealAt)
    }
}
