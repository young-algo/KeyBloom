import SwiftUI

struct ConfettiEffect: BloomEffect {
    static func draw(_ frame: BloomFrame, in context: inout GraphicsContext, random: inout SplitMix64) {
        let count = frame.calm ? 20 : 34
        let eased = BloomEnvelope.easeOutCubic(frame.progress)

        for index in 0..<count {
            let angle = CGFloat(random.nextDouble(in: 0...(Double.pi * 2)))
            let speed = CGFloat(random.nextDouble(in: 0.6...1.6))
            let fall = CGFloat(random.nextDouble(in: 0.8...1.8))
            let spin = CGFloat(random.nextDouble(in: -7...7))
            let flips = CGFloat(random.nextDouble(in: 1.5...4))
            let startAngle = CGFloat(random.nextDouble(in: 0...(Double.pi * 2)))
            let width = frame.radius * CGFloat(random.nextDouble(in: 0.035...0.085))
            let height = width * CGFloat(random.nextDouble(in: 1.4...2.8))
            let hue = PerceptualColor.wrappedHue(frame.baseHue + Double(index) * 0.073)
            let point = CGPoint(
                x: frame.center.x + cos(angle) * frame.radius * eased * speed,
                y: frame.center.y + sin(angle) * frame.radius * eased * speed
                    + frame.radius * frame.progress * frame.progress * fall
            )
            let flip = max(0.08, abs(cos(frame.progress * flips * .pi)))
            var piece = context
            piece.translateBy(x: point.x, y: point.y)
            piece.rotate(by: .radians(Double(startAngle + spin * frame.progress)))
            let rect = CGRect(x: -width * flip / 2, y: -height / 2, width: width * flip, height: height)
            piece.fill(
                Path(roundedRect: rect, cornerRadius: width * 0.45),
                with: .color(index.isMultiple(of: 5) ? .white.opacity(0.9) : PerceptualColor.bloom(hue: hue, opacity: 0.88))
            )
        }
    }
}
