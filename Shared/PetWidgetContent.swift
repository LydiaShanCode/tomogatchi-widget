import SwiftUI

/// The exact character-and-label layout used by both WidgetKit and the gallery.
struct PetWidgetContent: View {
    let state: PetSnapshot
    let date: Date
    var body: some View {
        VStack(spacing: 10) {
            CharacterView(mood: state.bodyMood(at: date), frame: 1, food: state.pendingGift?.food)
            Text(state.displayMood(at: date).rawValue)
                .font(Minimal.font(14)).foregroundStyle(.black).padding(.bottom, 2)
        }
        .padding(8)
        .background(.white)
        .accessibilityElement(children: .combine)
    }
}
enum WidgetPreviewData {
    static func snapshot(for mood: Mood, at date: Date = Date()) -> PetSnapshot {
        var state = PetSnapshot()
        state.preferences.schedules = []
        let hours: Double = mood == .tired ? 8 : mood == .hungry ? 5 : 0
        state.lastMealAt = date.addingTimeInterval(-hours * 3600)
        if mood == .gift {
            state.gifts = [Gift(id: "widget-preview", food: .bokChoy, status: "pending", createdAt: date)]
        }
        return state
    }
}
