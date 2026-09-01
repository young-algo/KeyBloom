import SwiftUI

struct StarEffect: BloomEffect {
    static func draw(_ frame: BloomFrame, in context: inout GraphicsContext, random: inout SplitMix64) {
        let rotationRate = frame.calm ? 0.9 : 1.8
        let rotation = Double(frame.progress) * rotationRate + random.nextDouble(in: 0...(Double.pi * 2))
        let outerRadius = frame.radius * (0.55 + frame.progress * 0.45)
        let path = BloomMath.starPath(
            center: frame.center,
            outerRadius: outerRadius,
            innerRadius: frame.radius * 0.34,
            points: 6,
            rotation: rotation
        )
        BloomMath.drawGlow(
            in: &context,
            center: frame.center,
            radius: outerRadius * 1.25,
            color: frame.color,
            opacity: 0.36
        )
        context.fill(path, with: .color(frame.color.opacity(0.88)))
        context.stroke(path, with: .color(.white.opacity(0.82)), lineWidth: max(2, frame.radius * 0.024))

        for index in 0..<6 {
            let angle = CGFloat(index) / 6 * .pi * 2 - frame.progress
            let point = CGPoint(
                x: frame.center.x + cos(angle) * frame.radius * (0.85 + frame.progress * 0.35),
                y: frame.center.y + sin(angle) * frame.radius * (0.85 + frame.progress * 0.35)
            )
            context.fill(
                BloomMath.starPath(
                    center: point,
                    outerRadius: frame.radius * 0.10,
                    innerRadius: frame.radius * 0.035,
                    points: 4,
                    rotation: rotation * -0.5
                ),
                with: .color(.white.opacity(0.88))
            )
        }
    }
}
