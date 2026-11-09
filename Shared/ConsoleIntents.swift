import AppIntents

/// iOS 17-compatible actions: foreground the app to accept a gift or animate.
/// Both targets compile these intents, so handoff also works from a cold launch.
struct ConsoleEatIntent: AppIntent {
    static var title: LocalizedStringResource = "Open food gift"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult {
        SharedStore.requestConsoleAction(.eat)
        return .result()
    }
}
struct ConsoleDanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Make Connor dance"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult {
        SharedStore.requestConsoleAction(.dance)
        return .result()
    }
}
