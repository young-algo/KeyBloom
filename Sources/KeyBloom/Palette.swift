import SwiftUI

enum BloomPalette: String, CaseIterable, Identifiable {
    case rainbow
    case ocean
    case sunset
    case meadow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rainbow:
            return "Rainbow"
        case .ocean:
            return "Ocean"
        case .sunset:
            return "Sunset"
        case .meadow:
            return "Meadow"
        }
    }

    var subtitle: String {
        switch self {
        case .rainbow:
            return "Every key gets its own bright color"
        case .ocean:
            return "Blues, aquas, and soft violet"
        case .sunset:
            return "Peach, pink, amber, and plum"
        case .meadow:
            return "Greens, yellow, sky blue, and lilac"
        }
    }

    /// Stable key identity: neighboring key codes are spread around the palette.
    func hue(forKeyCode keyCode: UInt16) -> Double {
        let offset = (Double(keyCode) * 0.6180339887).truncatingRemainder(dividingBy: 1)
        return hue(offset: offset)
    }

    /// Pointer, chord, and scroll events have no key identity, so their colors vary.
    func hue(forEvent index: Int) -> Double {
        hue(offset: Double((index * 137) % 360) / 360.0)
    }

    func hue(offset: Double) -> Double {
        switch self {
        case .rainbow:
            return offset
        case .ocean:
            return (200.0 + offset * 90.0) / 360.0
        case .sunset:
            let warm = 340.0 / 360.0 + offset * (90.0 / 360.0)
            return warm.truncatingRemainder(dividingBy: 1.0)
        case .meadow:
            return (110.0 + offset * 100.0) / 360.0
        }
    }

    var backgroundHues: (Double, Double, Double) {
        switch self {
        case .rainbow:
            return (0.72, 0.84, 0.02)
        case .ocean:
            return (0.68, 0.76, 0.84)
        case .sunset:
            return (0.78, 0.86, 0.92)
        case .meadow:
            return (0.46, 0.54, 0.62)
        }
    }
}
