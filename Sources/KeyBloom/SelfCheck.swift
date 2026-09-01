import CoreGraphics
import Foundation

enum KeyBloomSelfCheck {
    static func run() throws {
        let quarter = BloomEnvelope.standard(progress: 0.25, calm: false)
        let halfway = BloomEnvelope.standard(progress: 0.50, calm: false)
        let late = BloomEnvelope.standard(progress: 0.85, calm: false)
        try require(abs(quarter.opacity - 1) < 0.0001, "envelope fades before its hold ends")
        try require(abs(halfway.opacity - 1) < 0.0001, "envelope is not fully visible at midlife")
        try require(late.opacity < 1, "envelope does not fade late in life")

        for palette in BloomPalette.allCases {
            try require(
                palette.hue(forKeyCode: 0) == palette.hue(forKeyCode: 0),
                "\(palette.title) does not keep a stable key color"
            )
        }

        let expectedKinds: [(UInt16, BloomKind)] = [
            (18, .star), (12, .bubble), (0, .flower), (6, .pinwheel),
            (49, .rings), (51, .comet)
        ]
        for (keyCode, kind) in expectedKinds {
            try require(
                GameModel.kind(for: keyCode, pressCount: 1) == kind,
                "key \(keyCode) did not map to \(kind.title)"
            )
        }
        try require(
            GameModel.kind(for: 0, pressCount: 11) == .confetti,
            "the every-eleventh-press confetti surprise is missing"
        )

        let repeatModel = GameModel()
        repeatModel.reset(palette: .rainbow, showLabels: true, calmMotion: false)
        repeatModel.registerKey(keyCode: 0)
        let originalLifetime = repeatModel.bursts[0].lifetime
        repeatModel.registerKey(keyCode: 0, isRepeat: true)
        try require(repeatModel.bursts.count == 1, "a repeat spawned a second burst")
        try require(repeatModel.bursts[0].lastPulseAt != nil, "a repeat did not pulse its bloom")
        try require(repeatModel.bursts[0].lifetime > originalLifetime, "a repeat did not extend bloom life")

        let positionedModel = GameModel()
        positionedModel.reset(palette: .rainbow, showLabels: true, calmMotion: true)
        positionedModel.registerKey(keyCode: 18, at: CGPoint(x: 0.5, y: 0.5))
        guard let positionedBurst = positionedModel.bursts.last else {
            throw Failure(message: "a positioned preview key did not spawn")
        }
        try require(
            abs(positionedBurst.position.x - 0.5) <= 0.02
                && abs(positionedBurst.position.y - 0.5) <= 0.02,
            "a positioned preview key ignored its requested focal point"
        )

        let scrollModel = GameModel()
        scrollModel.reset(palette: .rainbow, showLabels: true, calmMotion: false)
        scrollModel.registerScroll(direction: -1)
        try require(scrollModel.bursts.last?.label == "↓", "scroll-down label is incorrect")
        try require(
            abs((scrollModel.bursts.last?.heading ?? 0) - .pi / 2) < 0.0001,
            "scroll-down comet does not travel down"
        )

        let dragModel = GameModel()
        dragModel.reset(palette: .rainbow, showLabels: true, calmMotion: false)
        dragModel.registerDrag(normalizedPosition: CGPoint(x: 0.3, y: 0.7))
        try require(dragModel.bursts.last?.kind == .bubble, "drag trail is not a bubble")
        try require(dragModel.bursts.last?.label == "", "drag trail has a label")
        try require(
            abs((dragModel.bursts.last?.intensity ?? 0) - 0.45) < 0.0001,
            "drag trail intensity changed"
        )

        let budgetModel = GameModel()
        budgetModel.reset(palette: .rainbow, showLabels: true, calmMotion: false)
        for keyCode in UInt16(0)..<UInt16(12) {
            budgetModel.registerKey(keyCode: keyCode)
        }
        try require(
            budgetModel.bursts.count == AppConfig.maximumSpawnsPerHalfSecond,
            "global half-second spawn budget is not enforced"
        )
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw Failure(message: message) }
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}
