import SwiftUI
import UIKit

private enum ConsoleImages {
    static let images: [String: UIImage] = {
        var images: [String: UIImage] = [:]
        for name in ["mini-console"] + ConsoleLandscape.allCases.map(\.imageName) {
            if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "WidgetConsole"),
               let image = UIImage(contentsOfFile: url.path) { images[name] = image }
        }
        return images
    }()
}

/// Used by the actual small widget and the in-app gallery. Controls are supplied
/// by the host: App Intents for WidgetKit, native preview actions in the gallery.
struct MiniConsoleView<EatControl: View, StarControl: View>: View {
    let state: PetSnapshot
    let date: Date
    var landscape: ConsoleLandscape = .hill
    var frame = 1
    var animation: BodyAnimation? = nil
    @ViewBuilder var eatControl: () -> EatControl
    @ViewBuilder var starControl: () -> StarControl

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height) - 4
            let size = CGSize(width: side, height: side)
            let screen = ConsoleGeometry.rect(ConsoleGeometry.screen, in: size)
            let eat = ConsoleGeometry.rect(ConsoleGeometry.eatButton, in: size)
            let star = ConsoleGeometry.rect(ConsoleGeometry.starButton, in: size)
            ZStack(alignment: .topLeading) {
                if let shell = ConsoleImages.images["mini-console"] {
                    Image(uiImage: shell).resizable().interpolation(.none)
                        .frame(width: ConsoleGeometry.sourceWidth / ConsoleGeometry.crop.width * side,
                               height: ConsoleGeometry.sourceHeight / ConsoleGeometry.crop.height * side)
                        .offset(x: -ConsoleGeometry.crop.minX / ConsoleGeometry.crop.width * side,
                                y: -ConsoleGeometry.crop.minY / ConsoleGeometry.crop.height * side)
                        .frame(width: side, height: side, alignment: .topLeading).clipped()
                        .accessibilityHidden(true)
                }
                ZStack {
                    if let background = ConsoleImages.images[landscape.imageName] {
                        Image(uiImage: background).resizable().scaledToFill()
                            .frame(width: screen.width, height: screen.height).clipped()
                        // Overlay affects only the scenery, never the sprite/face.
                        Color.white.opacity(ConsoleGeometry.whiteOverlayOpacity)
                    } else {
                        Color(white: 0.9)
                        Text("Nature photo needed").font(Minimal.font(9))
                            .multilineTextAlignment(.center).padding(4)
                    }
                    CharacterView(mood: state.bodyMood(at: date), frame: frame,
                                  food: state.pendingGift?.food, animation: animation)
                        .frame(width: screen.width * 0.68, height: screen.height * 0.66)
                        .position(x: screen.width / 2, y: screen.height * 0.55)
                }
                .frame(width: screen.width, height: screen.height)
                .clipShape(RoundedRectangle(cornerRadius: side * 0.004))
                .offset(x: screen.minX, y: screen.minY)

                eatControl()
                    .frame(width: eat.width, height: eat.height)
                    .contentShape(Rectangle())
                    .offset(x: eat.minX, y: eat.minY)
                starControl()
                    .frame(width: star.width, height: star.height)
                    .contentShape(Rectangle())
                    .offset(x: star.minX, y: star.minY)
            }
            .frame(width: side, height: side)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("miniConsole")
        .accessibilityLabel("FEED CONNOR, \(state.displayMood(at: date).rawValue.lowercased()), \(landscape.title)")
    }
}
