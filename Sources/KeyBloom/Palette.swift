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

    func hue(for index: Int, keyCode: UInt16) -> Double {
        let offset = Double((index * 17 + Int(keyCode) * 7) % 1000) / 1000.0

        switch self {
        case .rainbow:
            return offset
        case .ocean:
            return 0.48 + (offset * 0.22)
        case .sunset:
            // Wrap a warm range around the hue boundary.
            let warm = 0.91 + (offset * 0.20)
            return warm.truncatingRemainder(dividingBy: 1.0)
        case .meadow:
            return 0.18 + (offset * 0.30)
        }
    }

    var backgroundHues: (Double, Double, Double) {
        switch self {
        case .rainbow:
            return (0.64, 0.77, 0.93)
        case .ocean:
            return (0.55, 0.61, 0.70)
        case .sunset:
            return (0.91, 0.02, 0.10)
        case .meadow:
            return (0.31, 0.43, 0.57)
        }
    }
}
