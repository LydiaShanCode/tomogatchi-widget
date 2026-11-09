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
private struct HeadLayout: Decodable {
    let rotationDegrees: Double
    let chinX: CGFloat
    let chinY: CGFloat
    let sourceWidth: CGFloat
    let sourceHeight: CGFloat
    let visibleWidth: CGFloat
    let targetWidth: CGFloat
    let overlap: CGFloat
    var sourceScale: CGFloat { targetWidth / visibleWidth }
}
private struct CompositionCanvas: Decodable {
    let halfWidth: CGFloat
    let top: CGFloat
    let bottom: CGFloat
}
private struct HeadLayouts: Decodable {
    let canvas: CompositionCanvas
    let heads: [String: HeadLayout]
    static let supplied: HeadLayouts? = {
        guard let url = Bundle.main.url(forResource: "heads", withExtension: "json", subdirectory: "Character"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(HeadLayouts.self, from: data)
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
            let canvas = HeadLayouts.supplied?.canvas
            let halfWidth = canvas?.halfWidth ?? 220
            let top = canvas?.top ?? -360
            let bottom = canvas?.bottom ?? 260
            // Fit the complete upright character, with room beside it for food.
            // One shared canvas keeps the neck position/scale fixed for all poses.
            let unit = min(geometry.size.width / (halfWidth * 2 + 110),
                           geometry.size.height / (bottom - top))
            let neckX = geometry.size.width / 2
            let neckY = geometry.size.height / 2 - (top + bottom) / 2 * unit
            ZStack {
                // Draw one atlas cell at a shared pixel scale. Original sheets
                // remain intact; each frame attaches to the same neck point.
                if let atlas = SpriteAtlas.supplied,
                   let sheet = atlas.animations[bodyAnimation.rawValue],
                   let bodyImage = asset(sheet.image), !sheet.frames.isEmpty {
                    let index = max(0, frame - 1) % sheet.frames.count
                    let cell = sheet.frames[index]
                    Image(uiImage: bodyImage).resizable().interpolation(.none)
                        .frame(width: sheet.width * unit, height: sheet.height * unit)
                        .offset(x: (sheet.width / 2 - cell.x - cell.width / 2) * unit,
                                y: (sheet.height / 2 - cell.y - cell.height / 2) * unit)
                        .frame(width: cell.width * unit, height: cell.height * unit)
                        .clipped()
                        .position(
                            x: neckX + (cell.width / 2 - cell.neckX) * unit,
                            y: neckY + (cell.height / 2 - cell.neckY) * unit
                        )
                }
                if let headImage = asset(head), let layout = HeadLayouts.supplied?.heads[head] {
                    let photoScale = layout.sourceScale * unit
                    Image(uiImage: headImage).resizable()
                        .frame(width: layout.sourceWidth * photoScale, height: layout.sourceHeight * photoScale)
                        // Rotate around the chin, then place that exact point at
                        // the neck. Transform only the view; never rewrite faces.
                        .rotationEffect(.degrees(layout.rotationDegrees), anchor: UnitPoint(
                            x: layout.chinX / layout.sourceWidth,
                            y: layout.chinY / layout.sourceHeight
                        ))
                        .position(
                            x: neckX + (layout.sourceWidth / 2 - layout.chinX) * photoScale,
                            y: neckY + layout.overlap * unit + (layout.sourceHeight / 2 - layout.chinY) * photoScale
                        )
                } else {
                    Rectangle().stroke(.black, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .frame(width: size * 0.4, height: size * 0.45)
                        .position(x: neckX, y: neckY - size * 0.2)
                }
                if let food {
                    Text(food.icon).font(.system(size: size * 0.16))
                        .position(x: neckX + (halfWidth + 24) * unit, y: neckY + 35 * unit)
                }
            }
        }
        .accessibilityIdentifier("connorCharacter")
        .accessibilityValue(bodyAnimation.rawValue)
        .accessibilityLabel("Connor, \(mood.rawValue.lowercased())\(food.map { ", gift: \($0.name)" } ?? "")")
    }
}
