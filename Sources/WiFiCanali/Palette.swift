import AppKit
import SwiftUI
import WiFiCanaliCore

extension Color {
    /// Colore con una variante per il tema chiaro e una per lo scuro.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
                green: CGFloat((hex >> 8) & 0xff) / 255,
                blue: CGFloat(hex & 0xff) / 255,
                alpha: 1
            )
        })
    }
}

enum Palette {
    static let neighbor = Color(light: 0x2a78d6, dark: 0x3987e5)
    static let own = Color(light: 0xeb6834, dark: 0xd95926)
    static let good = Color(light: 0x0ca30c, dark: 0x0ca30c)
    static let warning = Color(light: 0xfab219, dark: 0xfab219)
    static let critical = Color(light: 0xd03b3b, dark: 0xd03b3b)
    static let muted = Color(light: 0x898781, dark: 0x898781)
    static let card = Color(nsColor: .controlBackgroundColor)
}

extension CongestionLevel {
    var color: Color {
        switch self {
        case .free, .low: return Palette.good
        case .medium: return Palette.warning
        case .high: return Palette.critical
        }
    }

    var symbol: String {
        switch self {
        case .free: return "checkmark.circle.fill"
        case .low: return "checkmark.circle"
        case .medium: return "exclamationmark.circle.fill"
        case .high: return "xmark.octagon.fill"
        }
    }
}

extension WiFiNetwork {
    var bssidText: String { bssid ?? "" }
}
