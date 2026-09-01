import SwiftUI

struct RingsEffect: BloomEffect {
    static func draw(_ frame: BloomFrame, in context: inout GraphicsContext, random: inout SplitMix64) {
        for index in 0..<5 {
            let delay = CGFloat(index) * 0.10
            let local = min(max((frame.progress - delay) / max(0.001, 1 - delay), 0), 1)
            let radius = frame.radius * (0.22 + local * (0.72 + CGFloat(index) * 0.18))
            let ring = Path(ellipseIn: CGRect(
                x: frame.center.x - radius,
                y: frame.center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            context.stroke(
                ring,
                with: .color(index.isMultiple(of: 2) ? frame.color.opacity(0.82) : .white.opacity(0.65)),
                lineWidth: max(2, frame.radius * (0.055 - CGFloat(index) * 0.006))
            )
        }
    }
}
