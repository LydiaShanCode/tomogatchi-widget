import Foundation

enum Mood: String, Codable, CaseIterable {
    case fed = "FED", hungry = "HUNGRY", tired = "TIRED", gift = "GIFT"
}
enum Role: String, Codable { case parent, child }
enum Food: String, Codable, CaseIterable, Identifiable {
    case apple, bread, steak, bokChoy
    var id: String { rawValue }
    var name: String { self == .bokChoy ? "Bok choy" : rawValue.capitalized }
    var icon: String {
        switch self { case .apple: "🍎"; case .bread: "🍞"; case .steak: "🥩"; case .bokChoy: "🥬" }
    }
}
struct MealSchedule: Codable, Identifiable, Equatable {
    var id: String
    var hour: Int
    var minute: Int
    var enabled: Bool = true
    static let defaults = [MealSchedule(id: "Breakfast", hour: 8, minute: 0), MealSchedule(id: "Lunch", hour: 12, minute: 30), MealSchedule(id: "Dinner", hour: 19, minute: 0), MealSchedule(id: "Snack", hour: 16, minute: 0, enabled: false)]
}
struct Preferences: Codable, Equatable {
    var schedules = MealSchedule.defaults
    var hungryAfterHours: Double = 4
    var tiredAfterHours: Double = 7
    var remindersEnabled = false
    var quietStart = 22
    var quietEnd = 7
    var timeZone = TimeZone.current.identifier
    func isQuiet(hour: Int) -> Bool {
        if quietStart == quietEnd { return false }
        return quietStart < quietEnd ? (quietStart..<quietEnd).contains(hour) : hour >= quietStart || hour < quietEnd
    }
}
struct Gift: Codable, Identifiable {
    var id: String
    var food: Food
    var status: String
    var createdAt: Date
    var consumedAt: Date?
}
struct Meal: Codable, Identifiable {
    var id: String
    var kind: String
    var at: Date
}
struct PetSnapshot: Codable {
    var pairID: String? = nil
    var lastMealAt: Date? = nil
    var virtualFedUntil: Date? = nil
    var preferences = Preferences()
    var gifts: [Gift] = []
    var updatedAt = Date()
    var pendingGift: Gift? { gifts.filter { $0.status == "pending" }.sorted { $0.createdAt < $1.createdAt }.first }
    func bodyMood(at date: Date = Date()) -> Mood {
        if let until = virtualFedUntil, date < until { return .fed }
        // With no confirmed meal, do not invent a meal event.
        guard let last = lastMealAt else { return .hungry }
        let elapsed = max(0, date.timeIntervalSince(last) / 3600)
        if elapsed >= preferences.tiredAfterHours { return .tired }
        if elapsed >= preferences.hungryAfterHours { return .hungry }
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: preferences.timeZone) ?? .current
        // An overdue scheduled meal also makes Connor hungry, unless a meal was
        // confirmed after that schedule. Quiet hours suppress reminders, not hunger.
        for schedule in preferences.schedules where schedule.enabled {
            if let scheduled = calendar.date(bySettingHour: schedule.hour, minute: schedule.minute, second: 0, of: date),
               scheduled <= date, last < scheduled, date.timeIntervalSince(scheduled) >= 1800 {
                return .hungry
            }
        }
        return .fed
    }
    func displayMood(at date: Date = Date()) -> Mood { pendingGift == nil ? bodyMood(at: date) : .gift }
}
