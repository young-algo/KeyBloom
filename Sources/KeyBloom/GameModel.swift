import CoreGraphics
import Foundation
import SwiftUI

enum BloomKind: Int, CaseIterable {
    case bubble
    case flower
    case star
    case comet
    case rings
    case pinwheel
    case confetti
}

struct BloomBurst: Identifiable {
    let id = UUID()
    let createdAt: Date
    let position: CGPoint
    let hue: Double
    let label: String
    let kind: BloomKind
    let seed: UInt64
    let intensity: CGFloat
    let lifetime: TimeInterval
}

final class GameModel: ObservableObject {
    @Published private(set) var bursts: [BloomBurst] = []
    @Published private(set) var pressCount = 0
    @Published var unlockStartedAt: Date?
    @Published private(set) var palette: BloomPalette = .rainbow
    @Published private(set) var showLabels = true
    @Published private(set) var calmMotion = true

    func reset(palette: BloomPalette, showLabels: Bool, calmMotion: Bool) {
        self.palette = palette
        self.showLabels = showLabels
        self.calmMotion = calmMotion
        bursts.removeAll(keepingCapacity: true)
        pressCount = 0
        unlockStartedAt = nil
    }

    func registerKey(keyCode: UInt16, label: String? = nil, isRepeat: Bool = false) {
        pressCount += 1
        pruneExpiredBursts()

        let base = KeyboardLayout.normalizedPosition(for: keyCode, pressIndex: pressCount)
        let jitterAmount: CGFloat = calmMotion ? 0.018 : 0.030
        let position = CGPoint(
            x: clamp(base.x + CGFloat.random(in: -jitterAmount...jitterAmount), lower: 0.06, upper: 0.94),
            y: clamp(base.y + CGFloat.random(in: -jitterAmount...jitterAmount), lower: 0.10, upper: 0.91)
        )

        let hue = palette.hue(for: pressCount, keyCode: keyCode)
        let selectedLabel = label ?? KeyboardLayout.label(for: keyCode)
        let kind: BloomKind

        if pressCount.isMultiple(of: 11) {
            kind = .confetti
        } else if keyCode == 49 {
            kind = .rings
        } else if keyCode == 36 {
            kind = .pinwheel
        } else if keyCode == 51 || keyCode == 117 {
            kind = .comet
        } else {
            let available: [BloomKind] = [.bubble, .flower, .star, .comet, .rings, .pinwheel]
            kind = available[(Int(keyCode) + pressCount) % available.count]
        }

        let repeatScale: CGFloat = isRepeat ? 0.78 : 1.0
        append(
            BloomBurst(
                createdAt: Date(),
                position: position,
                hue: hue,
                label: selectedLabel,
                kind: kind,
                seed: UInt64.random(in: UInt64.min...UInt64.max),
                intensity: CGFloat.random(in: 0.88...1.15) * repeatScale,
                lifetime: AppConfig.burstLifetime * (isRepeat ? 0.78 : 1.0)
            )
        )
    }

    func registerModifier(keyCode: UInt16) {
        guard let label = KeyboardLayout.modifierLabel(for: keyCode) else { return }
        registerKey(keyCode: keyCode, label: label)
    }

    func registerChord(keyCount: Int) {
        pressCount += 1
        pruneExpiredBursts()

        let x = CGFloat.random(in: 0.25...0.75)
        let y = CGFloat.random(in: 0.28...0.70)
        let hue = palette.hue(for: pressCount + keyCount * 5, keyCode: UInt16(keyCount))

        append(
            BloomBurst(
                createdAt: Date(),
                position: CGPoint(x: x, y: y),
                hue: hue,
                label: keyCount >= 5 ? "WOW" : "✦",
                kind: .confetti,
                seed: UInt64.random(in: UInt64.min...UInt64.max),
                intensity: min(1.85, 1.10 + CGFloat(keyCount) * 0.13),
                lifetime: AppConfig.burstLifetime * 1.25
            )
        )
    }

    func registerPointer(normalizedPosition: CGPoint) {
        pressCount += 1
        pruneExpiredBursts()

        let position = CGPoint(
            x: clamp(normalizedPosition.x, lower: 0.04, upper: 0.96),
            y: clamp(normalizedPosition.y, lower: 0.07, upper: 0.93)
        )

        append(
            BloomBurst(
                createdAt: Date(),
                position: position,
                hue: palette.hue(for: pressCount, keyCode: UInt16(pressCount % 127)),
                label: "●",
                kind: .rings,
                seed: UInt64.random(in: UInt64.min...UInt64.max),
                intensity: 0.95,
                lifetime: AppConfig.burstLifetime * 0.85
            )
        )
    }

    func registerScroll(direction: CGFloat) {
        pressCount += 1
        pruneExpiredBursts()

        let upward = direction >= 0
        append(
            BloomBurst(
                createdAt: Date(),
                position: CGPoint(
                    x: CGFloat.random(in: 0.25...0.75),
                    y: upward ? 0.72 : 0.30
                ),
                hue: palette.hue(for: pressCount, keyCode: upward ? 126 : 125),
                label: upward ? "↑" : "↓",
                kind: .comet,
                seed: UInt64.random(in: UInt64.min...UInt64.max),
                intensity: 1.05,
                lifetime: AppConfig.burstLifetime
            )
        )
    }

    private func append(_ burst: BloomBurst) {
        bursts.append(burst)
        if bursts.count > AppConfig.maximumBursts {
            bursts.removeFirst(bursts.count - AppConfig.maximumBursts)
        }
    }

    private func pruneExpiredBursts(now: Date = Date()) {
        bursts.removeAll { now.timeIntervalSince($0.createdAt) > ($0.lifetime + 0.5) }
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
