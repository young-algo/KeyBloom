import SwiftUI

struct GameView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        TimelineView(.animation(minimumInterval: model.calmMotion ? (1.0 / 30.0) : (1.0 / 60.0))) { timeline in
            Canvas { context, size in
                BloomRenderer.drawBackground(
                    in: &context,
                    size: size,
                    date: timeline.date,
                    palette: model.palette,
                    calmMotion: model.calmMotion
                )

                for burst in model.bursts {
                    BloomRenderer.draw(
                        burst: burst,
                        in: &context,
                        size: size,
                        date: timeline.date,
                        showLabel: model.showLabels
                    )
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if let startedAt = model.unlockStartedAt {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(startedAt)
                    let progress = elapsed / AppConfig.exitHoldDuration
                    UnlockProgressView(progress: progress)
                }
                .padding(28)
                .transition(.opacity)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
    }
}

private struct UnlockProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.28))

            Circle()
                .stroke(.white.opacity(0.20), lineWidth: 5)
                .padding(5)

            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(5)

            Image(systemName: "lock.open.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 58, height: 58)
        .shadow(radius: 12)
        .accessibilityLabel("Unlocking")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

private enum BloomRenderer {
    static func drawBackground(
        in context: inout GraphicsContext,
        size: CGSize,
        date: Date,
        palette: BloomPalette,
        calmMotion: Bool
    ) {
        let rect = CGRect(origin: .zero, size: size)
        let phaseSpeed = calmMotion ? 0.010 : 0.018
        let phase = date.timeIntervalSinceReferenceDate * phaseSpeed
        let hues = palette.backgroundHues

        let colorA = Color(
            hue: wrappedHue(hues.0 + sin(phase) * 0.025),
            saturation: 0.74,
            brightness: 0.23
        )
        let colorB = Color(
            hue: wrappedHue(hues.1 + cos(phase * 0.79) * 0.035),
            saturation: 0.78,
            brightness: 0.34
        )
        let colorC = Color(
            hue: wrappedHue(hues.2 + sin(phase * 0.63) * 0.030),
            saturation: 0.70,
            brightness: 0.20
        )

        let start = CGPoint(
            x: size.width * (0.10 + CGFloat((sin(phase * 0.71) + 1.0) * 0.08)),
            y: size.height * 0.05
        )
        let end = CGPoint(
            x: size.width * (0.82 + CGFloat((cos(phase * 0.51) + 1.0) * 0.06)),
            y: size.height * 0.96
        )

        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [colorA, colorB, colorC]),
                startPoint: start,
                endPoint: end
            )
        )

        drawAmbientOrbs(in: &context, size: size, phase: phase, calmMotion: calmMotion)
    }

    static func draw(
        burst: BloomBurst,
        in context: inout GraphicsContext,
        size: CGSize,
        date: Date,
        showLabel: Bool
    ) {
        let age = date.timeIntervalSince(burst.createdAt)
        guard age >= 0, age <= burst.lifetime else { return }

        let progress = CGFloat(age / burst.lifetime)
        let growth = easeOutCubic(progress)
        let fadeBase = max(CGFloat.zero, 1.0 - progress)
        let fade = CGFloat(pow(Double(fadeBase), 1.25))
        let center = CGPoint(
            x: burst.position.x * size.width,
            y: burst.position.y * size.height
        )
        let shortSide = min(size.width, size.height)
        let radius = shortSide * (0.075 + 0.075 * growth) * burst.intensity
        let color = Color(hue: burst.hue, saturation: 0.82, brightness: 1.0)
        var random = SplitMix64(seed: burst.seed)

        context.drawLayer { layer in
            layer.opacity = Double(fade)

            switch burst.kind {
            case .bubble:
                drawBubble(
                    in: &layer,
                    center: center,
                    radius: radius,
                    progress: progress,
                    color: color,
                    random: &random
                )
            case .flower:
                drawFlower(
                    in: &layer,
                    center: center,
                    radius: radius,
                    progress: progress,
                    color: color,
                    baseHue: burst.hue,
                    random: &random
                )
            case .star:
                drawStar(
                    in: &layer,
                    center: center,
                    radius: radius,
                    progress: progress,
                    color: color,
                    random: &random
                )
            case .comet:
                drawComet(
                    in: &layer,
                    center: center,
                    radius: radius,
                    progress: progress,
                    color: color,
                    random: &random
                )
            case .rings:
                drawRings(
                    in: &layer,
                    center: center,
                    radius: radius,
                    progress: progress,
                    color: color
                )
            case .pinwheel:
                drawPinwheel(
                    in: &layer,
                    center: center,
                    radius: radius,
                    progress: progress,
                    color: color,
                    random: &random
                )
            case .confetti:
                drawConfetti(
                    in: &layer,
                    center: center,
                    radius: radius,
                    progress: progress,
                    baseHue: burst.hue,
                    random: &random
                )
            }

            if showLabel {
                drawLabel(
                    burst.label,
                    in: &layer,
                    center: center,
                    radius: radius,
                    progress: progress
                )
            }
        }
    }

    private static func drawAmbientOrbs(
        in context: inout GraphicsContext,
        size: CGSize,
        phase: Double,
        calmMotion: Bool
    ) {
        let count = 18
        let movement: CGFloat = calmMotion ? 0.65 : 1.0

        for index in 0..<count {
            let baseX = CGFloat((index * 47) % 101) / 100.0
            let baseY = CGFloat((index * 71 + 19) % 103) / 102.0
            let x = (baseX * size.width) + sin(CGFloat(phase) * 0.8 + CGFloat(index)) * 26.0 * movement
            let y = (baseY * size.height) + cos(CGFloat(phase) * 0.6 + CGFloat(index) * 0.7) * 22.0 * movement
            let diameter = min(size.width, size.height) * CGFloat(0.012 + Double(index % 5) * 0.004)
            let orb = Path(ellipseIn: CGRect(
                x: x - diameter / 2,
                y: y - diameter / 2,
                width: diameter,
                height: diameter
            ))
            context.fill(orb, with: .color(.white.opacity(0.035 + Double(index % 3) * 0.015)))
        }
    }

    private static func drawBubble(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        progress: CGFloat,
        color: Color,
        random: inout SplitMix64
    ) {
        let coreRadius = radius * (0.30 + progress * 0.22)
        let coreRect = CGRect(
            x: center.x - coreRadius,
            y: center.y - coreRadius,
            width: coreRadius * 2,
            height: coreRadius * 2
        )

        context.drawLayer { glow in
            glow.addFilter(.blur(radius: max(3, radius * 0.10)))
            glow.fill(Path(ellipseIn: coreRect), with: .color(color.opacity(0.55)))
        }
        context.fill(Path(ellipseIn: coreRect), with: .color(color.opacity(0.72)))
        context.stroke(Path(ellipseIn: coreRect), with: .color(.white.opacity(0.80)), lineWidth: max(2, radius * 0.025))

        for index in 0..<10 {
            let angle = (CGFloat(index) / 10.0) * .pi * 2.0 + progress * 1.7
            let distance = radius * (0.48 + progress * 0.78) * CGFloat(random.nextDouble(in: 0.78...1.18))
            let dotRadius = radius * CGFloat(random.nextDouble(in: 0.055...0.12))
            let point = CGPoint(
                x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance
            )
            context.fill(
                Path(ellipseIn: CGRect(
                    x: point.x - dotRadius,
                    y: point.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )),
                with: .color(index.isMultiple(of: 2) ? color.opacity(0.90) : .white.opacity(0.78))
            )
        }
    }

    private static func drawFlower(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        progress: CGFloat,
        color: Color,
        baseHue: Double,
        random: inout SplitMix64
    ) {
        let petals = 9
        let rotation = progress * 1.35 + CGFloat(random.nextDouble(in: 0...(Double.pi * 2.0)))

        for index in 0..<petals {
            let angle = (CGFloat(index) / CGFloat(petals)) * .pi * 2.0 + rotation
            let distance = radius * (0.32 + progress * 0.42)
            let petalRadius = radius * CGFloat(random.nextDouble(in: 0.16...0.24))
            let point = CGPoint(
                x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance
            )
            let petalHueShift = Double(index) * 0.018
            let petalColor = Color(
                hue: wrappedHue(baseHue + petalHueShift),
                saturation: 0.78,
                brightness: 1.0
            )
            context.fill(
                Path(ellipseIn: CGRect(
                    x: point.x - petalRadius,
                    y: point.y - petalRadius,
                    width: petalRadius * 2,
                    height: petalRadius * 2
                )),
                with: .color(index.isMultiple(of: 2) ? color.opacity(0.82) : petalColor.opacity(0.72))
            )
        }

        let centerRadius = radius * 0.27
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - centerRadius,
                y: center.y - centerRadius,
                width: centerRadius * 2,
                height: centerRadius * 2
            )),
            with: .color(.white.opacity(0.92))
        )
    }

    private static func drawStar(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        progress: CGFloat,
        color: Color,
        random: inout SplitMix64
    ) {
        let rotation = Double(progress) * 1.8 + random.nextDouble(in: 0...(Double.pi * 2.0))
        let path = starPath(
            center: center,
            outerRadius: radius * (0.55 + progress * 0.45),
            innerRadius: radius * 0.34,
            points: 6,
            rotation: rotation
        )

        context.drawLayer { glow in
            glow.addFilter(.blur(radius: max(4, radius * 0.08)))
            glow.fill(path, with: .color(color.opacity(0.55)))
        }
        context.fill(path, with: .color(color.opacity(0.88)))
        context.stroke(path, with: .color(.white.opacity(0.82)), lineWidth: max(2, radius * 0.024))

        for index in 0..<6 {
            let angle = CGFloat(index) / 6.0 * .pi * 2.0 - progress
            let point = CGPoint(
                x: center.x + cos(angle) * radius * (0.85 + progress * 0.35),
                y: center.y + sin(angle) * radius * (0.85 + progress * 0.35)
            )
            let sparkle = starPath(
                center: point,
                outerRadius: radius * 0.10,
                innerRadius: radius * 0.035,
                points: 4,
                rotation: rotation * -0.5
            )
            context.fill(sparkle, with: .color(.white.opacity(0.88)))
        }
    }

    private static func drawComet(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        progress: CGFloat,
        color: Color,
        random: inout SplitMix64
    ) {
        let angle = CGFloat(random.nextDouble(in: -2.8 ... -0.35))
        let travel = radius * (0.15 + progress * 0.75)
        let head = CGPoint(
            x: center.x + cos(angle) * travel,
            y: center.y + sin(angle) * travel
        )

        for index in stride(from: 10, through: 1, by: -1) {
            let fraction = CGFloat(index) / 10.0
            let distance = radius * fraction * (0.85 + progress * 0.35)
            let point = CGPoint(
                x: head.x - cos(angle) * distance,
                y: head.y - sin(angle) * distance
            )
            let dotRadius = radius * (0.025 + fraction * 0.045)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: point.x - dotRadius,
                    y: point.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )),
                with: .color(color.opacity(Double(0.14 + fraction * 0.55)))
            )
        }

        let headRadius = radius * 0.30
        context.drawLayer { glow in
            glow.addFilter(.blur(radius: max(3, radius * 0.08)))
            glow.fill(
                Path(ellipseIn: CGRect(
                    x: head.x - headRadius,
                    y: head.y - headRadius,
                    width: headRadius * 2,
                    height: headRadius * 2
                )),
                with: .color(color.opacity(0.62))
            )
        }
        context.fill(
            Path(ellipseIn: CGRect(
                x: head.x - headRadius,
                y: head.y - headRadius,
                width: headRadius * 2,
                height: headRadius * 2
            )),
            with: .color(color.opacity(0.88))
        )
    }

    private static func drawRings(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        progress: CGFloat,
        color: Color
    ) {
        for index in 0..<5 {
            let delay = CGFloat(index) * 0.10
            let localProgress = min(max((progress - delay) / max(0.001, 1.0 - delay), 0), 1)
            let ringRadius = radius * (0.22 + localProgress * (0.72 + CGFloat(index) * 0.18))
            let lineWidth = max(2, radius * (0.055 - CGFloat(index) * 0.006))
            let ring = Path(ellipseIn: CGRect(
                x: center.x - ringRadius,
                y: center.y - ringRadius,
                width: ringRadius * 2,
                height: ringRadius * 2
            ))
            context.stroke(
                ring,
                with: .color(index.isMultiple(of: 2) ? color.opacity(0.82) : .white.opacity(0.65)),
                lineWidth: lineWidth
            )
        }
    }

    private static func drawPinwheel(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        progress: CGFloat,
        color: Color,
        random: inout SplitMix64
    ) {
        let spokes = 12
        let rotation = progress * 2.2 + CGFloat(random.nextDouble(in: 0...(Double.pi * 2.0)))

        for index in 0..<spokes {
            let angle = CGFloat(index) / CGFloat(spokes) * .pi * 2.0 + rotation
            let inner = radius * 0.18
            let outer = radius * (0.48 + progress * 0.52)
            var path = Path()
            path.move(to: CGPoint(
                x: center.x + cos(angle) * inner,
                y: center.y + sin(angle) * inner
            ))
            path.addLine(to: CGPoint(
                x: center.x + cos(angle + 0.10) * outer,
                y: center.y + sin(angle + 0.10) * outer
            ))
            context.stroke(
                path,
                with: .color(index.isMultiple(of: 3) ? .white.opacity(0.82) : color.opacity(0.82)),
                style: StrokeStyle(lineWidth: max(2, radius * 0.045), lineCap: .round)
            )
        }

        let coreRadius = radius * 0.20
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - coreRadius,
                y: center.y - coreRadius,
                width: coreRadius * 2,
                height: coreRadius * 2
            )),
            with: .color(.white.opacity(0.90))
        )
    }

    private static func drawConfetti(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        progress: CGFloat,
        baseHue: Double,
        random: inout SplitMix64
    ) {
        let count = 30

        for index in 0..<count {
            let angle = CGFloat(random.nextDouble(in: 0...(Double.pi * 2.0)))
            let speed = CGFloat(random.nextDouble(in: 0.45...1.25))
            let gravity = radius * progress * progress * CGFloat(random.nextDouble(in: 0.12...0.42))
            let distance = radius * progress * speed
            let point = CGPoint(
                x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance + gravity
            )
            let width = radius * CGFloat(random.nextDouble(in: 0.035...0.085))
            let height = width * CGFloat(random.nextDouble(in: 1.4...2.8))
            let rect = CGRect(
                x: point.x - width / 2,
                y: point.y - height / 2,
                width: width,
                height: height
            )
            let hue = wrappedHue(baseHue + Double(index) * 0.073)
            let confettiColor = Color(hue: hue, saturation: 0.80, brightness: 1.0)
            context.fill(
                Path(roundedRect: rect, cornerRadius: width * 0.45),
                with: .color(index.isMultiple(of: 5) ? .white.opacity(0.90) : confettiColor.opacity(0.88))
            )
        }
    }

    private static func drawLabel(
        _ label: String,
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        progress: CGFloat
    ) {
        guard !label.isEmpty else { return }

        let entrance = min(progress / 0.22, 1.0)
        let bounce = 0.90 + sin(entrance * .pi) * 0.12
        let fontSize = max(34, radius * 0.73 * bounce)
        let text = Text(label)
            .font(.system(size: fontSize, weight: .black, design: .rounded))
            .foregroundStyle(.white)
        let resolved = context.resolve(text)

        context.drawLayer { shadow in
            shadow.addFilter(.shadow(color: .black.opacity(0.35), radius: max(3, radius * 0.035), x: 0, y: 4))
            shadow.draw(resolved, at: center, anchor: .center)
        }
    }

    private static func starPath(
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
            let angle = CGFloat(rotation) + CGFloat(index) / CGFloat(count) * .pi * 2.0 - .pi / 2.0
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }

    private static func easeOutCubic(_ value: CGFloat) -> CGFloat {
        let inverse = 1.0 - value
        return 1.0 - inverse * inverse * inverse
    }

    private static func wrappedHue(_ hue: Double) -> Double {
        let value = hue.truncatingRemainder(dividingBy: 1.0)
        return value < 0 ? value + 1.0 : value
    }

}

private struct SplitMix64 {
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
