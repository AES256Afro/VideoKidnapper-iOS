import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    /// Initialize from a hex string like "#FF8800" or "FF8800".
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/// Convert a SwiftUI Color back to a "#RRGGBB" string for the Codable model.
func hexString(for color: Color) -> String {
    #if canImport(UIKit)
    let platform = UIColor(color)
    #elseif canImport(AppKit)
    let platform = NSColor(color) ?? NSColor.white
    #endif
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    platform.getRed(&r, green: &g, blue: &b, alpha: &a)
    return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
}
