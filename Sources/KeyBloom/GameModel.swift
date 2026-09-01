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

    var title: String { String(describing: self).capitalized }
}

struct BloomBurst: Identifiable {
    let id: UUID
    let createdAt: Date
    let position: CGPoint
    let hue: Double
    let label: String
    let kind: BloomKind
    let seed: UInt64
    let intensity: CGFloat
    var lifetime: TimeInterval
    var lastPulseAt: Date?
    let heading: CGFloat?

    init(
        id: UUID = UUID(),
        createdAt: Date,
        position: CGPoint,
        hue: Double,
        label: String,
        kind: BloomKind,
        seed: UInt64,
        intensity: CGFloat,
        lifetime: TimeInterval,
        lastPulseAt: Date? = nil,
        heading: CGFloat? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.position = position
        self.hue = hue
        self.label = label
        self.kind = kind
        self.seed = seed
        self.intensity = intensity
        self.lifetime = lifetime
        self.lastPulseAt = lastPulseAt
        self.heading = heading
    }
}

final class GameModel: ObservableObject {
    @Published private(set) var bursts: [BloomBurst] = []
    @Published private(set) var pressCount = 0
    @Published var unlockStartedAt: Date?
    @Published private(set) var palette: BloomPalette = .rainbow
    @Published private(set) var showLabels = true
    @Published private(set) var calmMotion = true

    private var latestBurstByKey: [UInt16: UUID] = [:]
    private var recentSpawns: [TimeInterval] = []
    private var lastDragSpawn: TimeInterval = 0

    func reset(palette: BloomPalette, showLabels: Bool, calmMotion: Bool) {
        self.palette = palette
        self.showLabels = showLabels
        self.calmMotion = calmMotion
        bursts.removeAll(keepingCapacity: true)
        latestBurstByKey.removeAll(keepingCapacity: true)
        recentSpawns.removeAll(keepingCapacity: true)
        lastDragSpawn = 0
        pressCount = 0
        unlockStartedAt = nil
    }

    func registerKey(keyCode: UInt16, label: String? = nil, isRepeat: Bool = false) {
        pruneExpiredBursts()
        if isRepeat, pulseExistingBurst(forKey: keyCode) { return }
        guard spawnBudgetAllows() else {
            pulseLastBurst()
            return
        }

        pressCount += 1
        let base = KeyboardLayout.normalizedPosition(for: keyCode, pressIndex: pressCount)
        let jitter: CGFloat = calmMotion ? 0.018 : 0.030
        let position = CGPoint(
            x: clamp(base.x + CGFloat.random(in: -jitter...jitter), lower: 0.06, upper: 0.94),
            y: clamp(base.y + CGFloat.random(in: -jitter...jitter), lower: 0.10, upper: 0.91)
        )
        let kind = Self.kind(for: keyCode, pressCount: pressCount)
        let burst = BloomBurst(
            createdAt: Date(),
            position: position,
            hue: palette.hue(forKeyCode: keyCode),
            label: label ?? KeyboardLayout.label(for: keyCode),
            kind: kind,
            seed: UInt64.random(in: UInt64.min...UInt64.max),
            intensity: CGFloat.random(in: 0.88...1.15),
            lifetime: adjustedLifetime(for: kind),
            heading: nil
        )
        append(burst)
        latestBurstByKey[keyCode] = burst.id
    }

    func registerModifier(keyCode: UInt16) {
        guard let label = KeyboardLayout.modifierLabel(for: keyCode) else { return }
        registerKey(keyCode: keyCode, label: label)
    }

    func registerChord(keyCount: Int) {
        pruneExpiredBursts()
        guard spawnBudgetAllows() else {
            pulseLastBurst()
            return
        }
        pressCount += 1
        append(BloomBurst(
            createdAt: Date(),
            position: CGPoint(x: CGFloat.random(in: 0.25...0.75), y: CGFloat.random(in: 0.28...0.70)),
            hue: palette.hue(forEvent: pressCount + keyCount * 5),
            label: keyCount >= 5 ? "WOW" : "✦",
            kind: .confetti,
            seed: UInt64.random(in: UInt64.min...UInt64.max),
            intensity: min(1.85, 1.10 + CGFloat(keyCount) * 0.13),
            lifetime: adjustedLifetime(for: .confetti),
            heading: nil
        ))
    }

    func registerPointer(normalizedPosition: CGPoint) {
        pruneExpiredBursts()
        guard spawnBudgetAllows() else {
            pulseLastBurst()
            return
        }
        pressCount += 1
        append(BloomBurst(
            createdAt: Date(),
            position: clampedPosition(normalizedPosition),
            hue: palette.hue(forEvent: pressCount),
            label: "●",
            kind: .rings,
            seed: UInt64.random(in: UInt64.min...UInt64.max),
            intensity: 0.95,
            lifetime: adjustedLifetime(for: .rings) * 0.85,
            heading: nil
        ))
    }

    func registerScroll(direction: CGFloat) {
        pruneExpiredBursts()
        guard spawnBudgetAllows() else {
            pulseLastBurst()
            return
        }
        pressCount += 1
        let upward = direction >= 0
        append(BloomBurst(
            createdAt: Date(),
            position: CGPoint(x: CGFloat.random(in: 0.25...0.75), y: upward ? 0.72 : 0.30),
            hue: palette.hue(forEvent: pressCount),
            label: upward ? "↑" : "↓",
            kind: .comet,
            seed: UInt64.random(in: UInt64.min...UInt64.max),
            intensity: 1.05,
            lifetime: adjustedLifetime(for: .comet),
            heading: upward ? -.pi / 2 : .pi / 2
        ))
    }

    /// Drag trails have their own tight throttle and intentionally bypass the global budget.
    func registerDrag(normalizedPosition: CGPoint) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastDragSpawn >= AppConfig.dragTrailInterval else { return }
        lastDragSpawn = now
        pruneExpiredBursts()
        pressCount += 1
        append(BloomBurst(
            createdAt: Date(),
            position: clampedPosition(normalizedPosition),
            hue: palette.hue(forEvent: pressCount),
            label: "",
            kind: .bubble,
            seed: UInt64.random(in: UInt64.min...UInt64.max),
            intensity: 0.45,
            lifetime: adjustedLifetime(for: .bubble) * 0.5,
            heading: nil
        ))
    }

    static func kind(for keyCode: UInt16, pressCount: Int) -> BloomKind {
        if pressCount.isMultiple(of: 11) { return .confetti }
        switch keyCode {
        case 49: return .rings
        case 36: return .pinwheel
        case 51, 117: return .comet
        default: break
        }
        switch KeyboardLayout.row(for: keyCode) {
        case 0: return .star
        case 1: return .bubble
        case 2: return .flower
        case 3: return .pinwheel
        default: return .bubble
        }
    }

    private func adjustedLifetime(for kind: BloomKind) -> TimeInterval {
        let base = kind == .confetti ? AppConfig.confettiLifetime : AppConfig.burstLifetime
        return base * (calmMotion ? AppConfig.calmLifetimeMultiplier : 1)
    }

    private func pulseExistingBurst(forKey keyCode: UInt16) -> Bool {
        guard let id = latestBurstByKey[keyCode],
              let index = bursts.firstIndex(where: { $0.id == id }),
              Date().timeIntervalSince(bursts[index].createdAt) < bursts[index].lifetime else {
            latestBurstByKey.removeValue(forKey: keyCode)
            return false
        }
        pulse(at: index)
        return true
    }

    private func pulseLastBurst() {
        guard let index = bursts.indices.last else { return }
        pulse(at: index)
    }

    private func pulse(at index: Int) {
        bursts[index].lastPulseAt = Date()
        bursts[index].lifetime = min(
            bursts[index].lifetime + 0.25,
            AppConfig.confettiLifetime * AppConfig.calmLifetimeMultiplier
        )
    }

    private func spawnBudgetAllows() -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        recentSpawns.removeAll { now - $0 > 0.5 }
        guard recentSpawns.count < AppConfig.maximumSpawnsPerHalfSecond else { return false }
        recentSpawns.append(now)
        return true
    }

    private func append(_ burst: BloomBurst) {
        bursts.append(burst)
        if bursts.count > AppConfig.maximumBursts {
            let removeCount = bursts.count - AppConfig.maximumBursts
            let removedIDs = Set(bursts.prefix(removeCount).map(\.id))
            bursts.removeFirst(removeCount)
            latestBurstByKey = latestBurstByKey.filter { !removedIDs.contains($0.value) }
        }
    }

    private func pruneExpiredBursts(now: Date = Date()) {
        let expiredIDs = Set(
            bursts.filter { now.timeIntervalSince($0.createdAt) > ($0.lifetime + 0.5) }.map(\.id)
        )
        guard !expiredIDs.isEmpty else { return }
        bursts.removeAll { expiredIDs.contains($0.id) }
        latestBurstByKey = latestBurstByKey.filter { !expiredIDs.contains($0.value) }
    }

    private func clampedPosition(_ position: CGPoint) -> CGPoint {
        CGPoint(
            x: clamp(position.x, lower: 0.04, upper: 0.96),
            y: clamp(position.y, lower: 0.07, upper: 0.93)
        )
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
