import WidgetKit
import SwiftUI
import AppIntents

@available(iOS 18.0, *)
struct OpenGiftIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Connor’s gift"
    static var description = IntentDescription("Open FEED CONNOR to choose Eat or Later.")
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "feedconnor://gift")!))
    }
}
struct PetEntry: TimelineEntry {
    var date: Date
    var state: PetSnapshot
}
struct PetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetEntry { PetEntry(date: Date(), state: sample(.fed)) }
    func getSnapshot(in context: Context, completion: @escaping (PetEntry) -> Void) {
        completion(PetEntry(date: Date(), state: context.isPreview ? sample(.fed) : SharedStore.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
        let state = SharedStore.read()
        let now = Date()
        // Static body frame. Recompute schedules and elapsed hunger for six hours.
        let entries = (0..<25).map { PetEntry(date: now.addingTimeInterval(Double($0) * 900), state: state) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(21600))))
    }
}
struct PetWidgetView: View {
    var entry: PetEntry
    var body: some View {
        PetWidgetContent(state: entry.state, date: entry.date)
        .containerBackground(.white, for: .widget)
        .widgetURL(URL(string: entry.state.pendingGift == nil ? "feedconnor://home" : "feedconnor://gift"))
        .accessibilityElement(children: .combine)
    }
}
@main
struct ConnorWidget: Widget {
    let kind = "ConnorWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PetProvider()) { entry in
            // OpenURLIntent is iOS 18+. On iOS 17 the view's widgetURL
            // opens the same native Eat/Later screen without this newer API.
            if #available(iOS 18.0, *) {
                if entry.state.pendingGift != nil {
                    Button(intent: OpenGiftIntent()) { PetWidgetView(entry: entry) }
                        .buttonStyle(.plain)
                        .containerBackground(.white, for: .widget)
                } else { PetWidgetView(entry: entry) }
            } else { PetWidgetView(entry: entry) }
        }
        .configurationDisplayName("FEED CONNOR")
        .description("Connor and one word. Tap a gift to eat it or leave it for later.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
func sample(_ mood: Mood) -> PetSnapshot {
    WidgetPreviewData.snapshot(for: mood)
}
#Preview("FED", as: .systemSmall) { ConnorWidget() } timeline: { PetEntry(date: Date(), state: sample(.fed)) }
#Preview("HUNGRY", as: .systemSmall) { ConnorWidget() } timeline: { PetEntry(date: Date(), state: sample(.hungry)) }
#Preview("TIRED", as: .systemSmall) { ConnorWidget() } timeline: { PetEntry(date: Date(), state: sample(.tired)) }
#Preview("GIFT", as: .systemSmall) { ConnorWidget() } timeline: { PetEntry(date: Date(), state: sample(.gift)) }

#Preview("FED medium", as: .systemMedium) { ConnorWidget() } timeline: { PetEntry(date: Date(), state: sample(.fed)) }
#Preview("HUNGRY medium", as: .systemMedium) { ConnorWidget() } timeline: { PetEntry(date: Date(), state: sample(.hungry)) }
#Preview("TIRED medium", as: .systemMedium) { ConnorWidget() } timeline: { PetEntry(date: Date(), state: sample(.tired)) }
#Preview("GIFT medium", as: .systemMedium) { ConnorWidget() } timeline: { PetEntry(date: Date(), state: sample(.gift)) }
