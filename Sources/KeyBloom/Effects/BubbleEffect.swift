import SwiftUI

struct BubbleEffect: BloomEffect {
    static func draw(_ frame: BloomFrame, in context: inout GraphicsContext, random: inout SplitMix64) {
        let coreRadius = frame.radius * (0.30 + frame.progress * 0.22)
        let coreRect = CGRect(
            x: frame.center.x - coreRadius,
            y: frame.center.y - coreRadius,
            width: coreRadius * 2,
            height: coreRadius * 2
        )
        BloomMath.drawGlow(
            in: &context,
            center: frame.center,
            radius: coreRadius * 1.6,
            color: frame.color,
            opacity: 0.38
        )
        let highlight = CGPoint(
            x: frame.center.x - coreRadius * 0.35,
            y: frame.center.y - coreRadius * 0.35
        )
        context.fill(
            Path(ellipseIn: coreRect),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.55), frame.color.opacity(0.75), frame.color.opacity(0.38)]),
                center: highlight,
                startRadius: 0,
                endRadius: coreRadius * 1.6
            )
        )
        context.stroke(
            Path(ellipseIn: coreRect),
            with: .color(.white.opacity(0.80)),
            lineWidth: max(2, frame.radius * 0.025)
        )

        for index in 0..<10 {
            let angle = CGFloat(index) / 10 * .pi * 2 + frame.progress * 1.7
            let distance = frame.radius * (0.48 + frame.progress * 0.78)
                * CGFloat(random.nextDouble(in: 0.78...1.18))
            let dotRadius = frame.radius * CGFloat(random.nextDouble(in: 0.055...0.12))
            let point = CGPoint(
                x: frame.center.x + cos(angle) * distance,
                y: frame.center.y + sin(angle) * distance
            )
            context.fill(
                Path(ellipseIn: CGRect(
                    x: point.x - dotRadius,
                    y: point.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )),
                with: .color(index.isMultiple(of: 2) ? frame.color.opacity(0.90) : .white.opacity(0.78))
            )
        }
    }
}
