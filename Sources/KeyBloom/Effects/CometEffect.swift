import SwiftUI

struct CometEffect: BloomEffect {
    static func draw(_ frame: BloomFrame, in context: inout GraphicsContext, random: inout SplitMix64) {
        let angle = frame.heading ?? CGFloat(random.nextDouble(in: -2.8 ... -0.35))
        let travel = frame.radius * (0.2 + BloomEnvelope.easeOutCubic(frame.progress) * 2.6)
        let head = CGPoint(
            x: frame.center.x + cos(angle) * travel,
            y: frame.center.y + sin(angle) * travel
        )
        let tailLength = min(travel, frame.radius * (0.8 + frame.progress * 0.9))
        let segments = 16
        for index in 0..<segments {
            let fraction = CGFloat(index) / CGFloat(segments - 1)
            let point = CGPoint(
                x: head.x - cos(angle) * tailLength * fraction,
                y: head.y - sin(angle) * tailLength * fraction
            )
            let radius = max(1, frame.radius * 0.28 * (1 - fraction))
            let opacity = Double(0.7 * (1 - fraction) * (1 - fraction))
            context.fill(
                Path(ellipseIn: CGRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )),
                with: .color(frame.color.opacity(opacity))
            )
        }

        let headRadius = frame.radius * 0.28
        BloomMath.drawGlow(
            in: &context,
            center: head,
            radius: headRadius * 2.2,
            color: frame.color,
            opacity: 0.45
        )
        context.fill(
            Path(ellipseIn: CGRect(
                x: head.x - headRadius,
                y: head.y - headRadius,
                width: headRadius * 2,
                height: headRadius * 2
            )),
            with: .color(frame.color.opacity(0.92))
        )
        let core = headRadius * 0.45
        context.fill(
            Path(ellipseIn: CGRect(x: head.x - core, y: head.y - core, width: core * 2, height: core * 2)),
            with: .color(.white.opacity(0.85))
        )
    }
}
