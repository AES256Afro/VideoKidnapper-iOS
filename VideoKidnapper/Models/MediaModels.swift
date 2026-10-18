import CoreGraphics
import Foundation

// MARK: - Editing model

/// A saved trim range, in seconds, relative to the source asset.
struct TrimRange: Identifiable, Codable, Equatable {
    var id = UUID()
    var start: Double
    var end: Double

    var duration: Double { max(0, end - start) }
}

struct CaptionStyle: Codable, Equatable {
    var fontSize: Double = 56
    var isBold: Bool = true
    var textColorHex: String = "#FFFFFF"
    var outlineColorHex: String = "#000000"
    var outlineWidth: Double = 5
    var shadowEnabled: Bool = true
}

struct Caption: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String = "New caption"
    var start: Double = 0
    var end: Double = 3
    /// Position in unit coordinates: (0,0) is bottom-left, (1,1) is top-right.
    var position: CGPoint = CGPoint(x: 0.5, y: 0.15)
    var style: CaptionStyle = CaptionStyle()
}

// MARK: - Export model

enum ExportFormat: String, CaseIterable, Identifiable, Codable {
    case mp4, gif

    var id: String { rawValue }
    var displayName: String { rawValue.uppercased() }
}

enum AspectPreset: String, CaseIterable, Identifiable, Codable {
    case original, landscape, portrait, square

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: return "Original"
        case .landscape: return "16:9 Landscape"
        case .portrait: return "9:16 Portrait"
        case .square: return "1:1 Square"
        }
    }

    /// Render size for export. `nil` keeps the source's oriented size.
    func renderSize(for naturalSize: CGSize) -> CGSize? {
        switch self {
        case .original: return nil
        case .landscape: return CGSize(width: 1920, height: 1080)
        case .portrait: return CGSize(width: 1080, height: 1920)
        case .square: return CGSize(width: 1080, height: 1080)
        }
    }
}
