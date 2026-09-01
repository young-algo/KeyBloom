import SwiftUI

struct FlowerEffect: BloomEffect {
    static func draw(_ frame: BloomFrame, in context: inout GraphicsContext, random: inout SplitMix64) {
        let petals = 9
        let rotationRate: CGFloat = frame.calm ? 0.675 : 1.35
        let rotation = frame.progress * rotationRate + CGFloat(random.nextDouble(in: 0...(Double.pi * 2)))

        for index in 0..<petals {
            let angle = CGFloat(index) / CGFloat(petals) * .pi * 2 + rotation
            let start = CGFloat(index) / CGFloat(petals) * 0.28
            let unfurl = BloomEnvelope.smoothstep((frame.progress - start) / 0.22)
            let distance = frame.radius * (0.30 + 0.40 * unfurl)
            let length = frame.radius * CGFloat(random.nextDouble(in: 0.30...0.40)) * unfurl
            let breadth = length * 0.55
            let petalColor = PerceptualColor.bloom(
                hue: PerceptualColor.wrappedHue(frame.baseHue + Double(index) * 0.018),
                opacity: 0.78
            )
            var petal = context
            petal.translateBy(
                x: frame.center.x + cos(angle) * distance,
                y: frame.center.y + sin(angle) * distance
            )
            petal.rotate(by: .radians(Double(angle)))
            petal.fill(
                Path(ellipseIn: CGRect(x: -length / 2, y: -breadth / 2, width: length, height: breadth)),
                with: .color(index.isMultiple(of: 2) ? frame.color.opacity(0.82) : petalColor)
            )
        }

        let centerRadius = frame.radius * 0.27
        context.fill(
            Path(ellipseIn: CGRect(
                x: frame.center.x - centerRadius,
                y: frame.center.y - centerRadius,
                width: centerRadius * 2,
                height: centerRadius * 2
            )),
            with: .color(.white.opacity(0.92))
        )
    }
}
