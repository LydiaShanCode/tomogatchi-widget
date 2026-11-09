import Foundation

enum ConsoleLandscape: String, Codable, CaseIterable, Identifiable {
    case hill, goldenHills, desert, mountains
    var id: String { rawValue }
    var title: String {
        switch self { case .hill: "Green hill"; case .goldenHills: "Golden hills"; case .desert: "Desert"; case .mountains: "Mountains" }
    }
    var imageName: String {
        switch self { case .hill: "nature-hill"; case .goldenHills: "nature-golden-hills"; case .desert: "nature-desert"; case .mountains: "nature-mountains" }
    }
}

enum ConsoleAction: String { case eat, dance }

/// Coordinates refer to the unchanged source PNG. Viewport cropping removes
/// only transparent export margins, then fits the casing to a square widget.
enum ConsoleGeometry {
    static let sourceWidth: CGFloat = 1254
    static let sourceHeight: CGFloat = 1254
    static let crop = CGRect(x: 270, y: 225, width: 715, height: 818)
    static let screen = CGRect(x: 350, y: 319, width: 529, height: 522)
    static let eatButton = CGRect(x: 433, y: 895, width: 159, height: 75)
    static let starButton = CGRect(x: 641, y: 895, width: 159, height: 75)
    static let whiteOverlayOpacity: Double = 0.40
    static func rect(_ source: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: (source.minX - crop.minX) / crop.width * size.width,
               y: (source.minY - crop.minY) / crop.height * size.height,
               width: source.width / crop.width * size.width,
               height: source.height / crop.height * size.height)
    }
}
