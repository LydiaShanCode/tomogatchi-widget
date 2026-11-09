import Foundation

enum BodyAnimation: String, Codable, CaseIterable {
    case idle, hungry, dancing
    static let frameCount = 5
    var frameDuration: TimeInterval {
        switch self { case .idle: 0.18; case .hungry: 0.15; case .dancing: 0.12 }
    }
    static func resolve(mood: Mood, dancing: Bool = false) -> BodyAnimation {
        if dancing { return .dancing }
        switch mood { case .hungry, .tired: return .hungry; case .fed, .gift: return .idle }
    }
    /// Public frame numbering matches the sprite packs: 1...5, looping.
    func frame(at elapsed: TimeInterval) -> Int {
        Int(floor(max(0, elapsed) / frameDuration)).quotientAndRemainder(dividingBy: Self.frameCount).remainder + 1
    }
}
