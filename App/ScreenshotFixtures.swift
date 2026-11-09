import Foundation

/// Debug-only launch fixtures render the real app views without service credentials.
/// Release/TestFlight builds ignore these arguments and always use Firebase.
enum ScreenshotFixtures {
    static var scenario: String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else { return nil }
        let value = arguments[index + 1]
        let widgets = ["small", "medium"].flatMap { size in
            ["fed", "hungry", "tired", "gift"].map { "widget-\(size)-\($0)" }
        }
        return (["fed", "hungry", "tired", "gift", "parent"] + widgets).contains(value) ? value : nil
        #else
        return nil
        #endif
    }
    static var widgetMood: Mood? {
        guard let scenario, scenario.hasPrefix("widget-"), let value = scenario.split(separator: "-").last else { return nil }
        return Mood(rawValue: value.uppercased())
    }
    static var widgetMedium: Bool { scenario?.hasPrefix("widget-medium-") == true }
    static var active: Bool { scenario != nil }
    @MainActor static func makeModel() -> PetModel {
        let model = PetModel()
        guard let scenario else { return model }
        var state = PetSnapshot(pairID: "screenshot-fixture")
        state.preferences.schedules = []
        let hours: Double = scenario == "tired" ? 8 : scenario == "hungry" || scenario == "parent" ? 5 : 1
        state.lastMealAt = Date().addingTimeInterval(-hours * 3600)
        if scenario == "gift" || scenario == "parent" {
            state.gifts = [Gift(id: "screenshot-gift", food: .apple, status: "pending", createdAt: Date())]
        }
        model.snapshot = state
        model.role = scenario == "parent" ? .parent : .child
        model.ready = true
        return model
    }
}
