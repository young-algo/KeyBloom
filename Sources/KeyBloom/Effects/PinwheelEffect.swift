import SwiftUI

struct PinwheelEffect: BloomEffect {
    static func draw(_ frame: BloomFrame, in context: inout GraphicsContext, random: inout SplitMix64) {
        let blades = 8
        let rotationRate: CGFloat = frame.calm ? 1.1 : 2.2
        let rotation = frame.progress * rotationRate + CGFloat(random.nextDouble(in: 0...(Double.pi * 2)))
        let inner = frame.radius * 0.16
        let outer = frame.radius * (0.45 + frame.progress * 0.55)
        let sweep = .pi * 2 / CGFloat(blades)
        func polar(_ radius: CGFloat, _ angle: CGFloat) -> CGPoint {
            CGPoint(x: frame.center.x + cos(angle) * radius, y: frame.center.y + sin(angle) * radius)
        }

        for index in 0..<blades {
            let angle = CGFloat(index) * sweep + rotation
            var blade = Path()
            blade.move(to: polar(inner, angle))
            blade.addQuadCurve(
                to: polar(outer, angle + sweep * 0.55),
                control: polar(outer * 0.88, angle + sweep * 0.08)
            )
            blade.addQuadCurve(
                to: polar(inner, angle + sweep * 0.5),
                control: polar(outer * 0.62, angle + sweep * 0.72)
            )
            blade.closeSubpath()
            context.fill(
                blade,
                with: .color(index.isMultiple(of: 2) ? frame.color.opacity(0.86) : .white.opacity(0.78))
            )
        }

        let hub = frame.radius * 0.14
        context.fill(
            Path(ellipseIn: CGRect(
                x: frame.center.x - hub,
                y: frame.center.y - hub,
                width: hub * 2,
                height: hub * 2
            )),
            with: .color(.white.opacity(0.92))
        )
    }
}
