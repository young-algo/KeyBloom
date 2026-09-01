import CoreGraphics
import Foundation

enum KeyboardLayout {
    private static let rows: [[UInt16]] = [
        // ` 1 2 3 4 5 6 7 8 9 0 - = delete
        [50, 18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24, 51],
        // tab Q W E R T Y U I O P [ ] \\
        [48, 12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30, 42],
        // caps A S D F G H J K L ; ' return
        [57, 0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39, 36],
        // shift Z X C V B N M , . / shift
        [56, 6, 7, 8, 9, 11, 45, 46, 43, 47, 44, 60]
    ]

    private static let rowInsets: [CGFloat] = [0.025, 0.045, 0.075, 0.11]
    private static let rowY: [CGFloat] = [0.20, 0.37, 0.54, 0.71]

    private static let bottomRowPositions: [UInt16: CGPoint] = [
        59: CGPoint(x: 0.07, y: 0.87),   // control
        58: CGPoint(x: 0.16, y: 0.87),   // option
        55: CGPoint(x: 0.27, y: 0.87),   // command
        49: CGPoint(x: 0.50, y: 0.87),   // space
        54: CGPoint(x: 0.73, y: 0.87),   // right command
        61: CGPoint(x: 0.84, y: 0.87),   // right option
        62: CGPoint(x: 0.93, y: 0.87)    // right control
    ]

    static func normalizedPosition(for keyCode: UInt16, pressIndex: Int) -> CGPoint {
        for (rowIndex, row) in rows.enumerated() {
            guard let columnIndex = row.firstIndex(of: keyCode) else { continue }

            let inset = rowInsets[rowIndex]
            let usableWidth = 1.0 - (inset * 2.0)
            let x = inset + usableWidth * (CGFloat(columnIndex) + 0.5) / CGFloat(row.count)
            return CGPoint(x: x, y: rowY[rowIndex])
        }

        if let position = bottomRowPositions[keyCode] {
            return position
        }

        switch keyCode {
        case 123:
            return CGPoint(x: 0.82, y: 0.87)
        case 124:
            return CGPoint(x: 0.94, y: 0.87)
        case 125:
            return CGPoint(x: 0.88, y: 0.91)
        case 126:
            return CGPoint(x: 0.88, y: 0.82)
        default:
            // Function keys, media keys, and unusual layouts still get stable-looking placement.
            let xBucket = CGFloat((Int(keyCode) * 37 + pressIndex * 11) % 82) / 100.0 + 0.09
            let yBucket = CGFloat((Int(keyCode) * 19 + pressIndex * 7) % 64) / 100.0 + 0.18
            return CGPoint(x: min(max(xBucket, 0.08), 0.92), y: min(max(yBucket, 0.16), 0.88))
        }
    }

    static func label(for keyCode: UInt16) -> String {
        labels[keyCode] ?? "✦"
    }

    static func modifierLabel(for keyCode: UInt16) -> String? {
        switch keyCode {
        case 54, 55:
            return "⌘"
        case 56, 60:
            return "⇧"
        case 58, 61:
            return "⌥"
        case 59, 62:
            return "⌃"
        case 57:
            return "⇪"
        case 63:
            return "fn"
        default:
            return nil
        }
    }

    private static let labels: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G",
        6: "Z", 7: "X", 8: "C", 9: "V", 11: "B",
        12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        24: "+", 25: "9", 26: "7", 27: "−", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "↵", 37: "L", 38: "J", 39: "’", 40: "K", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        48: "⇥", 49: "●", 50: "`", 51: "⌫", 53: "★",
        54: "⌘", 55: "⌘", 56: "⇧", 57: "⇪", 58: "⌥", 59: "⌃",
        60: "⇧", 61: "⌥", 62: "⌃", 63: "fn",
        114: "?", 115: "↖", 116: "⇞", 117: "⌦", 119: "↘",
        121: "⇟", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]

    static func row(for keyCode: UInt16) -> Int? {
        rows.firstIndex { $0.contains(keyCode) }
    }
}
