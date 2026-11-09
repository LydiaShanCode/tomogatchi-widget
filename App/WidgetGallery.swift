import SwiftUI

/// Native previews of the shared widget layout, not SpringBoard screenshots.
struct WidgetGallery: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mood: Mood
    @State private var medium: Bool
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
                    PetWidgetContent(state: WidgetPreviewData.snapshot(for: mood, at: date), date: date)
                        .frame(width: medium ? 320 : 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        // Preview boundary lives outside the widget layout.
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.black, lineWidth: 0.5))
                        .accessibilityIdentifier("widgetPreview")
                    Text("Sample preview. The Home Screen widget changes state as Connor gets hungry or receives a gift.")
                        .font(Minimal.font(12)).multilineTextAlignment(.center)
                    Text("To add it: hold your Home Screen, choose Edit → Add Widget, then search FEED CONNOR and select a size.")
                        .font(Minimal.font(12)).multilineTextAlignment(.center)
                }.padding(.horizontal, 16).padding(.vertical, 32)
            }
            .background(.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text("WIDGET PREVIEWS").font(Minimal.font()) }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .font(Minimal.font()).foregroundStyle(.black).tint(.black).preferredColorScheme(.light)
    }
}
