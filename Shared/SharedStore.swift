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
    static func clear() { defaults?.removeObject(forKey: "petSnapshot") }
}
