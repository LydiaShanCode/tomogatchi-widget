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
private struct SpriteFrame: Decodable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let neckX: CGFloat
    let neckY: CGFloat
}
private struct SpriteSheet: Decodable {
    let image: String
    let width: CGFloat
    let height: CGFloat
    let frames: [SpriteFrame]
}
private struct SpriteAtlas: Decodable {
    let pixelScale: CGFloat
    let animations: [String: SpriteSheet]
    static let supplied: SpriteAtlas? = {
        guard let url = Bundle.main.url(forResource: "animations", withExtension: "json", subdirectory: "Character"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SpriteAtlas.self, from: data)
    }()
}
struct CharacterView: View {
    var mood: Mood
    var frame: Int = 1
    var food: Food? = nil
    var animation: BodyAnimation? = nil
    private var head: String {
        switch mood { case .fed, .gift: "connor-fed"; case .hungry: "connor-hungry"; case .tired: "connor-starving" }
    }
    private var bodyAnimation: BodyAnimation { animation ?? .resolve(mood: mood) }
    private static let images: [String: UIImage] = {
        var images: [String: UIImage] = [:]
        for name in ["connor-fed", "connor-hungry", "connor-starving", "idle-sheet", "hungry-sheet", "dancing-sheet"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Character"),
               let image = UIImage(contentsOfFile: url.path) { images[name] = image }
        }
        return images
    }()
    private func asset(_ name: String) -> UIImage? { Self.images[name] }
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width / 1.45, geometry.size.height)
            ZStack {
                // Draw one atlas cell at a shared pixel scale. Original sheets
                // remain intact; each frame attaches to the same neck point.
                if let atlas = SpriteAtlas.supplied,
                   let sheet = atlas.animations[bodyAnimation.rawValue],
                   let bodyImage = asset(sheet.image), !sheet.frames.isEmpty {
                    let index = max(0, frame - 1) % sheet.frames.count
                    let cell = sheet.frames[index]
                    let unit = size * atlas.pixelScale
                    Image(uiImage: bodyImage).resizable().interpolation(.none)
                        .frame(width: sheet.width * unit, height: sheet.height * unit)
                        .offset(x: (sheet.width / 2 - cell.x - cell.width / 2) * unit,
                                y: (sheet.height / 2 - cell.y - cell.height / 2) * unit)
                        .frame(width: cell.width * unit, height: cell.height * unit)
                        .clipped()
                        .position(
                            x: geometry.size.width / 2 + (cell.width / 2 - cell.neckX) * unit,
                            y: geometry.size.height / 2 + size * 0.02 + (cell.height / 2 - cell.neckY) * unit
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
        .accessibilityIdentifier("connorCharacter")
        .accessibilityValue(bodyAnimation.rawValue)
        .accessibilityLabel("Connor, \(mood.rawValue.lowercased())\(food.map { ", gift: \($0.name)" } ?? "")")
    }
}
