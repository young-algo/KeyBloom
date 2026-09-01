import SwiftUI

struct GameView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
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
                        showLabel: model.showLabels,
                        calmMotion: model.calmMotion
                    )
                }
            }
            .accessibilityHidden(true)
        }
        .overlay(alignment: .topTrailing) {
            if let startedAt = model.unlockStartedAt {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(startedAt)
                    UnlockProgressView(progress: elapsed / AppConfig.exitHoldDuration)
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
            Circle().fill(.black.opacity(0.28))
            Circle().stroke(.white.opacity(0.20), lineWidth: 5).padding(5)
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
        .shadow(radius: 8)
        .accessibilityLabel("Unlocking")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

enum BloomRenderer {
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
            hue: PerceptualColor.wrappedHue(hues.0 + sin(phase) * 0.025),
            saturation: 0.56,
            brightness: 0.21
        )
        let colorB = Color(
            hue: PerceptualColor.wrappedHue(hues.1 + cos(phase * 0.79) * 0.035),
            saturation: 0.60,
            brightness: 0.31
        )
        let colorC = Color(
            hue: PerceptualColor.wrappedHue(hues.2 + sin(phase * 0.63) * 0.030),
            saturation: 0.55,
            brightness: 0.18
        )
        let start = CGPoint(
            x: size.width * (0.10 + CGFloat((sin(phase * 0.71) + 1) * 0.08)),
            y: size.height * 0.05
        )
        let end = CGPoint(
            x: size.width * (0.82 + CGFloat((cos(phase * 0.51) + 1) * 0.06)),
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

        let shortSide = min(size.width, size.height)
        context.fill(
            Path(rect),
            with: .radialGradient(
                Gradient(colors: [.clear, .black.opacity(0.38)]),
                center: CGPoint(x: size.width / 2, y: size.height / 2),
                startRadius: shortSide * 0.35,
                endRadius: shortSide * 0.95
            )
        )
    }

    static func draw(
        burst: BloomBurst,
        in context: inout GraphicsContext,
        size: CGSize,
        date: Date,
        showLabel: Bool,
        calmMotion: Bool
    ) {
        let age = date.timeIntervalSince(burst.createdAt)
        guard age >= 0, age <= burst.lifetime else { return }
        let progress = CGFloat(age / burst.lifetime)
        let envelope = BloomEnvelope.standard(progress: progress, calm: calmMotion)
        var pulse: CGFloat = 1
        if let lastPulseAt = burst.lastPulseAt {
            let elapsed = max(0, date.timeIntervalSince(lastPulseAt))
            pulse += 0.14 * CGFloat(exp(-elapsed * 7))
        }
        let center = CGPoint(x: burst.position.x * size.width, y: burst.position.y * size.height)
        let radius = min(size.width, size.height) * 0.15 * burst.intensity * envelope.scale * pulse
        let color = PerceptualColor.bloom(hue: burst.hue)
        var random = SplitMix64(seed: burst.seed)
        let frame = BloomFrame(
            center: center,
            radius: radius,
            progress: progress,
            color: color,
            baseHue: burst.hue,
            heading: burst.heading,
            calm: calmMotion
        )

        context.drawLayer { layer in
            layer.opacity = Double(envelope.opacity)
            burst.kind.effect.draw(frame, in: &layer, random: &random)
            if showLabel {
                drawLabel(
                    burst.label,
                    in: &layer,
                    center: center,
                    radius: radius,
                    progress: progress,
                    hue: burst.hue
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
        let shortSide = min(size.width, size.height)
        let movement: CGFloat = calmMotion ? 0.5 : 1
        let drift = CGFloat(phase)
        for index in 0..<7 {
            let baseX = CGFloat((index * 47) % 101) / 100
            let baseY = CGFloat((index * 71 + 19) % 103) / 102
            let x = baseX * size.width + sin(drift * 0.8 + CGFloat(index)) * shortSide * 0.04 * movement
            let y = baseY * size.height + cos(drift * 0.6 + CGFloat(index) * 0.7) * shortSide * 0.035 * movement
            let radius = shortSide * (0.12 + CGFloat(index % 3) * 0.06)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: x - radius,
                    y: y - radius,
                    width: radius * 2,
                    height: radius * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.06), .white.opacity(0)]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }
    }

    private static func drawLabel(
        _ label: String,
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        progress: CGFloat,
        hue: Double
    ) {
        guard !label.isEmpty else { return }
        let entrance = min(progress / 0.22, 1)
        let bounce = 0.90 + sin(entrance * .pi) * 0.12
        let fontSize = max(34, radius * 0.70 * bounce)
        let haloRadius = max(30, radius * 0.58)
        let backdropCore = PerceptualColor.bloom(
            hue: hue,
            lightness: 0.22,
            chroma: 0.07,
            opacity: 0.94
        )
        let backdropEdge = PerceptualColor.bloom(
            hue: hue,
            lightness: 0.28,
            chroma: 0.09,
            opacity: 0.48
        )
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - haloRadius,
                y: center.y - haloRadius,
                width: haloRadius * 2,
                height: haloRadius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [backdropCore, backdropEdge, .clear]),
                center: center,
                startRadius: haloRadius * 0.08,
                endRadius: haloRadius
            )
        )

        let shadow = context.resolve(
            Text(label)
                .font(.system(size: 100, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    PerceptualColor.bloom(
                        hue: hue,
                        lightness: 0.10,
                        chroma: 0.035,
                        opacity: 0.72
                    )
                )
        )
        let ink = PerceptualColor.bloom(
            hue: hue,
            lightness: 0.96,
            chroma: 0.018
        )
        let resolved = context.resolve(
            Text(label)
                .font(.system(size: 100, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)
        )
        var labelLayer = context
        labelLayer.translateBy(x: center.x, y: center.y)
        labelLayer.scaleBy(x: fontSize / 100, y: fontSize / 100)
        labelLayer.draw(shadow, at: CGPoint(x: 1.8, y: 2.6), anchor: .center)
        labelLayer.draw(resolved, at: .zero, anchor: .center)
    }
}
