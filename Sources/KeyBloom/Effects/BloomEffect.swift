import SwiftUI

struct BloomEnvelope {
    let scale: CGFloat
    let opacity: CGFloat

    static func standard(progress: CGFloat, calm: Bool) -> BloomEnvelope {
        let p = min(max(progress, 0), 1)
        let entryLength: CGFloat = calm ? 0.26 : 0.18
        let entry = min(p / entryLength, 1)
        let scale = 0.25 + 0.75 * (calm ? easeOutCubic(entry) : easeOutBack(entry))
        let exit = max(0, (p - 0.55) / 0.45)
        return BloomEnvelope(scale: scale, opacity: 1 - smoothstep(exit))
    }

    static func easeOutCubic(_ value: CGFloat) -> CGFloat {
        1 - pow(1 - value, 3)
    }

    static func easeOutBack(_ value: CGFloat) -> CGFloat {
        let c1: CGFloat = 1.70158
        return 1 + (c1 + 1) * pow(value - 1, 3) + c1 * pow(value - 1, 2)
    }

    static func smoothstep(_ value: CGFloat) -> CGFloat {
        let t = min(max(value, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

struct BloomFrame {
    let center: CGPoint
    let radius: CGFloat
    let progress: CGFloat
    let color: Color
    let baseHue: Double
    let heading: CGFloat?
    let calm: Bool
}

protocol BloomEffect {
    static func draw(
        _ frame: BloomFrame,
        in context: inout GraphicsContext,
        random: inout SplitMix64
    )
}

extension BloomKind {
    var effect: BloomEffect.Type {
        switch self {
        case .bubble: return BubbleEffect.self
        case .flower: return FlowerEffect.self
        case .star: return StarEffect.self
        case .comet: return CometEffect.self
        case .rings: return RingsEffect.self
        case .pinwheel: return PinwheelEffect.self
        case .confetti: return ConfettiEffect.self
        }
    }
}

enum BloomMath {
    static func drawGlow(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color,
        opacity: Double
    ) {
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [
                    color.opacity(opacity),
                    color.opacity(opacity * 0.25),
                    color.opacity(0)
                ]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    static func starPath(
        center: CGPoint,
        outerRadius: CGFloat,
        innerRadius: CGFloat,
        points: Int,
        rotation: Double
    ) -> Path {
        var path = Path()
        let count = points * 2
        for index in 0..<count {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = CGFloat(rotation) + CGFloat(index) / CGFloat(count) * .pi * 2 - .pi / 2
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) / Double(1 << 53)
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }
}
