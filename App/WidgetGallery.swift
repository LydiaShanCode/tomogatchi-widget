import SwiftUI
import WidgetKit

/// Native previews of the shared widget layout, not SpringBoard screenshots.
struct WidgetGallery: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mood: Mood
    @State private var medium: Bool
    @State private var landscape = SharedStore.consoleLandscape
    @State private var dancing = false
    @State private var giftInfo = false
    private let date = Date()
    init(mood: Mood = .fed, medium: Bool = false) {
        _mood = State(initialValue: mood)
        _medium = State(initialValue: medium)
    }
    private var selection: String { "\(mood.rawValue) · \(medium ? "MEDIUM" : "SMALL")" }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Text("Two sizes. Four automatic states.")
                    Picker("Widget size", selection: $medium) {
                        Text("Small").tag(false)
                        Text("Medium").tag(true)
                    }.pickerStyle(.segmented)
                    Picker("Preview state", selection: $mood) {
                        ForEach(Mood.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.menu)
                    Text(selection).accessibilityIdentifier("widgetSelection")
                    if medium {
                        PetWidgetContent(state: WidgetPreviewData.snapshot(for: mood, at: date), date: date)
                            .frame(width: 320, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.black, lineWidth: 0.5))
                            .accessibilityIdentifier("widgetPreview")
                    } else {
                        Picker("Nature background", selection: $landscape) {
                            ForEach(ConsoleLandscape.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.menu)
                        TimelineView(.animation(minimumInterval: 0.12, paused: !dancing)) { context in
                            MiniConsoleView(
                                state: WidgetPreviewData.snapshot(for: mood, at: date), date: date,
                                landscape: landscape,
                                frame: dancing ? BodyAnimation.dancing.frame(at: context.date.timeIntervalSince1970) : 1,
                                animation: dancing ? .dancing : nil
                            ) {
                                Button { giftInfo = true } label: { Color.clear }
                                    .buttonStyle(.plain).accessibilityLabel("Eat gift")
                            } starControl: {
                                Button { dancing = true } label: { Color.clear }
                                    .buttonStyle(.plain).accessibilityLabel("Preview dance")
                            }
                        }
                        .frame(width: 150, height: 150)
                        .accessibilityIdentifier("widgetPreview")
                    }
                    Text("Sample preview. The Home Screen widget changes state as Connor gets hungry or receives a gift.")
                        .font(Minimal.font(12)).multilineTextAlignment(.center)
                    Text("To add it: hold your Home Screen, choose Edit → Add Widget, then search FEED CONNOR and select a size.")
                        .font(Minimal.font(12)).multilineTextAlignment(.center)
                }.padding(.horizontal, 16).padding(.vertical, 32)
            }
            .background(.white)
            .onChange(of: landscape) { _, value in
                SharedStore.consoleLandscape = value
                WidgetCenter.shared.reloadAllTimelines()
            }
            .task(id: dancing) {
                guard dancing else { return }
                do { try await Task.sleep(for: .seconds(3)); dancing = false } catch { }
            }
            .onDisappear { dancing = false }
            .alert("EAT", isPresented: $giftInfo) {
                Button("Done", role: .cancel) { }
            } message: {
                Text("On the Home Screen, EAT opens the app so Connor can choose Eat or Later for a pending gift.")
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text("WIDGET PREVIEWS").font(Minimal.font()) }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .font(Minimal.font()).foregroundStyle(.black).tint(.black).preferredColorScheme(.light)
    }
}
