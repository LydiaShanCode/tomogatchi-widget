import Foundation

/// App and extension must use the same signed App Group entitlement.
enum SharedStore {
    static var group: String { Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? "group.com.feedconnor.shared" }
    static var defaults: UserDefaults? { UserDefaults(suiteName: group) }
    static func read() -> PetSnapshot {
        guard let data = defaults?.data(forKey: "petSnapshot"), let state = try? JSONDecoder().decode(PetSnapshot.self, from: data) else { return PetSnapshot() }
        return state
    }
    static func write(_ state: PetSnapshot) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults?.set(data, forKey: "petSnapshot")
    }
    static var consoleLandscape: ConsoleLandscape {
        get { ConsoleLandscape(rawValue: defaults?.string(forKey: "consoleLandscape") ?? "") ?? .hill }
        set { defaults?.set(newValue.rawValue, forKey: "consoleLandscape") }
    }
    static func requestConsoleAction(_ action: ConsoleAction) {
        defaults?.set(action.rawValue, forKey: "consoleAction")
        defaults?.set(Date().timeIntervalSince1970, forKey: "consoleActionAt")
        NotificationCenter.default.post(name: consoleActionNotification, object: nil)
    }
    static let consoleActionNotification = Notification.Name("FeedConnorConsoleAction")
    static func takeConsoleAction() -> ConsoleAction? {
        guard let value = defaults?.string(forKey: "consoleAction") else { return nil }
        let time = defaults?.double(forKey: "consoleActionAt") ?? 0
        defaults?.removeObject(forKey: "consoleAction")
        defaults?.removeObject(forKey: "consoleActionAt")
        guard Date().timeIntervalSince1970 - time < 60 else { return nil }
        return ConsoleAction(rawValue: value)
    }
    static func clear() { defaults?.removeObject(forKey: "petSnapshot") }
}
