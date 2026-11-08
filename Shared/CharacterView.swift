import SwiftUI
import UIKit

enum Minimal {
    // Arial Mono is not bundled. Use it only if installed; never redistribute it.
    static func font(_ size: CGFloat = 14) -> Font {
        if UIFont(name: "ArialMono", size: size) != nil { return .custom("ArialMono", size: size) }
        if UIFont(name: "ArialMT-Mono", size: size) != nil { return .custom("ArialMT-Mono", size: size) }
        return .system(size: size, weight: .regular, design: .monospaced)
    }
}
private struct SpriteLayout: Decodable {
    let width: CGFloat
    let height: CGFloat
    let neckX: CGFloat
    let neckY: CGFloat
    let visibleHeight: CGFloat
    static let supplied: [String: SpriteLayout] = {
        guard let url = Bundle.main.url(forResource: "layout", withExtension: "json", subdirectory: "Character"),
              let data = try? Data(contentsOf: url),
              let layouts = try? JSONDecoder().decode([String: SpriteLayout].self, from: data) else { return [:] }
        return layouts
    }()
}
struct CharacterView: View {
    var mood: Mood
    var frame: Int = 1
    var food: Food? = nil
    private var head: String {
        switch mood { case .fed, .gift: "connor-fed"; case .hungry: "connor-hungry"; case .tired: "connor-starving" }
    }
    private var bodyAsset: String {
        let prefix: String
        switch mood { case .fed, .gift: prefix = "idle"; case .hungry: prefix = "hungry"; case .tired: prefix = "low_energy" }
        return String(format: "%@_%02d", prefix, frame)
    }
    private func asset(_ name: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Character") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width / 1.45, geometry.size.height)
            ZStack {
                // Preserve the supplied PNGs and use their original pixel scale.
                // Per-frame neck anchors compensate for different source canvases.
                if let bodyImage = asset(bodyAsset), let layout = SpriteLayout.supplied[bodyAsset] {
                    let unit = size * 0.0062
                    Image(uiImage: bodyImage).resizable().interpolation(.none)
                        .frame(width: layout.width * unit, height: layout.height * unit)
                        // The two low-energy source files include sheet captions
                        // below the entire body. Hide only that annotation strip.
                        .frame(width: layout.width * unit, height: layout.visibleHeight * unit, alignment: .top)
                        .clipped()
                        .position(
                            x: geometry.size.width / 2 + (layout.width / 2 - layout.neckX) * unit,
                            y: geometry.size.height / 2 + size * 0.02 + (layout.visibleHeight / 2 - layout.neckY) * unit
                        )
                }
                if let headImage = asset(head) {
                    Image(uiImage: headImage).resizable().scaledToFit()
                        .frame(width: size * 0.61, height: size * 0.52)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - size * 0.22)
                } else {
                    // A missing-head marker, never a synthetic replacement face.
                    Rectangle().stroke(.black, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .frame(width: size * 0.61, height: size * 0.52)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - size * 0.22)
                }
                if let food {
                    Text(food.icon).font(.system(size: size * 0.16))
                        .position(x: geometry.size.width / 2 + size * 0.53, y: geometry.size.height / 2)
                }
            }
        }
        .accessibilityLabel("Connor, \(mood.rawValue.lowercased())\(food.map { ", gift: \($0.name)" } ?? "")")
    }
}
