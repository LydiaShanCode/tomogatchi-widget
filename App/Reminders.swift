import Foundation
import UserNotifications

enum Reminders {
    static func requestPermission() async throws {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        if !granted { throw NSError(domain: "Notifications", code: 1, userInfo: [NSLocalizedDescriptionKey: "Enable notifications in iOS Settings to receive reminders."]) }
    }
    static func schedule(_ preferences: Preferences) async throws {
        let center = UNUserNotificationCenter.current()
        let existing = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: existing.filter { $0.identifier.hasPrefix("meal.") }.map(\.identifier))
        guard preferences.remindersEnabled else { return }
        // At most four daily reminders; quiet-hour meals are suppressed, not postponed.
        for meal in preferences.schedules where meal.enabled && !preferences.isQuiet(hour: meal.hour) {
            let content = UNMutableNotificationContent()
            content.title = "FEED CONNOR"
            content.body = "Time for \(meal.id.lowercased()). Confirm your meal in the app."
            content.sound = .default
            var date = DateComponents()
            date.hour = meal.hour; date.minute = meal.minute
            date.timeZone = TimeZone(identifier: preferences.timeZone)
            let request = UNNotificationRequest(identifier: "meal.\(meal.id)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true))
            try await center.add(request)
        }
    }
}
