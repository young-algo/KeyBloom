import SwiftUI

enum JellyBounceRenderer {
    private struct CritterState {
        let burst: BloomBurst
        let age: TimeInterval
        let progress: CGFloat
        let opacity: CGFloat
        /// Slumps toward a puddle while the critter fades out.
        let melt: CGFloat
        /// Resting body center. Overlapping neighbors push this apart.
        var base: CGPoint
        let radius: CGFloat
        let row: Int
        /// Body motion now, plus slightly older samples that trailing parts follow.
        let body: JellyMotionSample
        let limbs: JellyMotionSample
        let tips: JellyMotionSample
        let eyes: JellyMotionSample
        /// 0 on the ground, 1 at the height of a first hop.
        let limbLift: CGFloat
        let cheer: CGFloat
        let armWave: CGFloat
        let isBlinking: Bool
        /// Slow -1...1 sway, so resting ears and sprouts never freeze.
        let idle: CGFloat
        var lean: CGFloat = 0
        var gaze: CGVector = .zero

        var stretch: CGFloat {
            min(1.45, max(0.6, 1 + body.deform)) * (1 - melt)
        }

        /// Width follows height so the jelly keeps its volume as it squashes and stretches.
        var widthScale: CGFloat {
            pow(stretch, -0.75)
        }

        var rotation: CGFloat {
            min(0.4, max(-0.4, body.rock + lean))
        }

        /// The point under the feet: squash, stretch, and rock all pivot here.
        var ground: CGPoint {
            CGPoint(x: base.x, y: base.y + JellyBounceRenderer.footDepth * radius)
        }

        /// Hops ease toward the room left above the critter, so top-row ears stay on screen.
        var hopOffset: CGFloat {
            let room = max(0.35, base.y / radius - 1.25)
            return room * tanh(body.height / room) * radius
        }
    }

    /// How far behind the body each trailing part runs (follow-through).
    private enum Lag {
        static let limbs: TimeInterval = 0.05
        static let tips: TimeInterval = 0.09
        static let eyes: TimeInterval = 0.035
    }

    /// Distance from the body's center down to the soles of its feet, in radii.
    private static let footDepth: CGFloat = 0.90

    static func drawScene(
        bursts: [BloomBurst],
        trampolines: [TrampolineEvent],
        in context: inout GraphicsContext,
        size: CGSize,
        date: Date,
        showLabels: Bool,
        calmMotion: Bool
    ) {
        let shortSide = min(size.width, size.height)
        guard shortSide > 0 else { return }
        let tuning = calmMotion ? JellyTuning.calm : .lively

        var states: [CritterState] = []
        states.reserveCapacity(bursts.count)

        for burst in bursts {
            let age = date.timeIntervalSince(burst.createdAt)
            guard age >= 0, age <= burst.lifetime else { continue }
            let progress = CGFloat(age / burst.lifetime)
            let envelope = BloomEnvelope.standard(progress: progress, calm: calmMotion)
            let base = CGPoint(x: burst.position.x * size.width, y: burst.position.y * size.height)

            let motion = JellyMotion(
                burst: burst,
                position: base,
                trampolines: trampolines,
                screenSize: size,
                tuning: tuning,
                calm: calmMotion
            )
            let cheer = burst.kind == .confetti ? 1 : motion.excitement(at: age)
            let limbs = motion.sample(at: age - Lag.limbs)

            let radius = max(
                18,
                shortSide * 0.135 * burst.intensity * inflation(of: burst, at: date) * popScale(age: age, tuning: tuning)
            )
            let blinkCycle = fmod(age + Double(burst.seed % 17) * 0.21, 2.7)

            states.append(CritterState(
                burst: burst,
                age: age,
                progress: progress,
                opacity: envelope.opacity,
                melt: (1 - envelope.opacity) * tuning.melt,
                base: base,
                radius: radius,
                row: burst.row ?? rowFallback(for: burst.kind),
                body: motion.sample(at: age),
                limbs: limbs,
                tips: motion.sample(at: age - Lag.tips),
                eyes: motion.sample(at: age - Lag.eyes),
                limbLift: min(1, max(0, limbs.height / tuning.hopHeight)),
                cheer: cheer,
                armWave: sin(CGFloat(age) * (calmMotion ? 8 : 11)) * tuning.armWave * cheer,
                isBlinking: cheer < 0.1 && blinkCycle > 2.54,
                idle: CGFloat(sin(age * 1.7 + motion.breathPhase))
            ))
        }

        separateNeighbors(&states)
        aimGazes(&states)

        // Shadows go down first so no critter's shadow lands on top of another critter.
        for state in states {
            drawShadow(state, in: &context, tuning: tuning)
        }
        for state in states {
            context.drawLayer { layer in
                layer.opacity = Double(state.opacity)
                drawCritter(state, in: &layer, showLabel: showLabels)
            }
        }
    }

    // MARK: - Motion Helpers

    /// Held keys puff the critter up. Each pulse eases in over the minimum repeat interval,
    /// so steady key repeats grow it smoothly instead of in visible steps.
    private static func inflation(of burst: BloomBurst, at date: Date) -> CGFloat {
        guard burst.pulseCount > 0, let lastPulseAt = burst.lastPulseAt else { return 1 }
        let ramp = min(1, max(0, date.timeIntervalSince(lastPulseAt) / AppConfig.repeatKeyMinimumInterval))
        return 1 + 0.08 * min(CGFloat(burst.pulseCount - 1) + CGFloat(ramp), 4.75)
    }

    private static func popScale(age: TimeInterval, tuning: JellyTuning) -> CGFloat {
        let t = CGFloat(min(1, max(0, age / tuning.popDuration)))
        let eased = tuning.popOvershoots ? BloomEnvelope.easeOutBack(t) : BloomEnvelope.easeOutCubic(t)
        return 0.35 + 0.65 * eased
    }

    /// Overlapping critters nudge apart and lean away from each other, in proportion to how much
    /// they overlap. Fading critters let go gradually instead of releasing neighbors all at once.
    private static func separateNeighbors(_ states: inout [CritterState]) {
        guard states.count > 1 else { return }
        for i in 0..<(states.count - 1) {
            for j in (i + 1)..<states.count {
                let dx = states[j].base.x - states[i].base.x
                let dy = states[j].base.y - states[i].base.y
                let distance = hypot(dx, dy)
                let minimum = (states[i].radius + states[j].radius) * 0.88
                guard distance > 0.001, distance < minimum else { continue }

                let presence = min(states[i].opacity, states[j].opacity)
                let push = (minimum - distance) * 0.48 * presence
                let lean = (minimum - distance) / minimum * 0.5 * presence
                let nx = dx / distance
                let ny = dy / distance
                states[i].base.x -= nx * push
                states[i].base.y -= ny * push
                states[j].base.x += nx * push
                states[j].base.y += ny * push
                states[i].lean -= nx * lean
                states[j].lean += nx * lean
            }
        }
    }

    /// Everyone turns to look at the newest critter; the newest looks out at the child.
    private static func aimGazes(_ states: inout [CritterState]) {
        guard let newest = states.last else { return }
        let previous = states.count > 1 ? states[states.count - 2] : nil
        let turn = BloomEnvelope.easeOutCubic(CGFloat(min(1, newest.age / 0.35))) * newest.opacity
        for index in states.indices {
            let toNewest = direction(from: states[index], to: newest)
            let toPrevious = previous.map { direction(from: states[index], to: $0) } ?? .zero
            states[index].gaze = CGVector(
                dx: toPrevious.dx + (toNewest.dx - toPrevious.dx) * turn,
                dy: toPrevious.dy + (toNewest.dy - toPrevious.dy) * turn
            )
        }
    }

    private static func direction(from viewer: CritterState, to target: CritterState) -> CGVector {
        guard viewer.burst.id != target.burst.id else { return .zero }
        let dx = target.base.x - viewer.base.x
        let dy = target.base.y - viewer.base.y
        let length = hypot(dx, dy)
        guard length > 1 else { return .zero }
        return CGVector(dx: dx / length, dy: dy / length)
    }

    // MARK: - Squishy Character Drawing

    /// A soft contact shadow that shrinks and fades as the critter leaves the ground,
    /// which is what makes a hop read as height rather than sliding upward.
    private static func drawShadow(_ state: CritterState, in context: inout GraphicsContext, tuning: JellyTuning) {
        let lift = min(1, max(0, state.body.height / tuning.heightCeiling))
        let width = state.radius * 0.95 * state.widthScale * (1 - 0.40 * lift)
        let alpha = 0.26 * (1 - 0.60 * lift) * Double(state.opacity)
        var shadow = context
        shadow.translateBy(x: state.ground.x, y: state.ground.y)
        shadow.scaleBy(x: 1, y: 0.20)
        shadow.fill(
            Path(ellipseIn: CGRect(x: -width, y: -width, width: width * 2, height: width * 2)),
            with: .radialGradient(
                Gradient(colors: [.black.opacity(alpha), .black.opacity(alpha * 0.55), .clear]),
                center: .zero,
                startRadius: 0,
                endRadius: width
            )
        )
    }

    private static func drawCritter(
        _ state: CritterState,
        in context: inout GraphicsContext,
        showLabel: Bool
    ) {
        let r = state.radius

        if state.burst.kind == .confetti {
            drawChordMiniJellies(
                state,
                center: CGPoint(x: state.base.x, y: state.base.y - state.hopOffset),
                in: &context
            )
        }

        var bodyLayer = context
        bodyLayer.translateBy(x: state.ground.x, y: state.ground.y - state.hopOffset)
        bodyLayer.rotate(by: .radians(Double(state.rotation)))
        bodyLayer.scaleBy(x: state.widthScale, y: state.stretch)
        bodyLayer.translateBy(x: 0, y: -footDepth * r)

        let topColor = PerceptualColor.bloom(
            hue: state.burst.hue,
            lightness: 0.84,
            chroma: 0.18,
            opacity: 0.97
        )
        let bottomColor = PerceptualColor.bloom(
            hue: state.burst.hue,
            lightness: 0.67,
            chroma: 0.21,
            opacity: 0.97
        )
        let darkOutline = PerceptualColor.bloom(
            hue: state.burst.hue,
            lightness: 0.26,
            chroma: 0.14,
            opacity: 0.92
        )

        // 1. Waving Arms & Little Feet
        drawLimbs(state, in: &bodyLayer, radius: r, fill: bottomColor)

        // 2. Row-Specific Ears / Antennas / Sprouts on Top
        drawHeadAttachments(state, in: &bodyLayer, radius: r, fill: topColor)

        // 3. Main Squishy Jelly Body Silhouette
        let bodyPath = critterBodyPath(row: state.row, radius: r)
        bodyLayer.fill(
            bodyPath,
            with: .linearGradient(
                Gradient(colors: [topColor, bottomColor]),
                startPoint: CGPoint(x: 0, y: -r),
                endPoint: CGPoint(x: 0, y: r)
            )
        )
        bodyLayer.stroke(
            bodyPath,
            with: .color(.white.opacity(0.90)),
            lineWidth: max(2.5, r * 0.06)
        )
        bodyLayer.stroke(
            bodyPath,
            with: .color(darkOutline),
            lineWidth: max(1.2, r * 0.025)
        )

        // 4. Glossy Specular Jelly Highlight
        var gloss = bodyLayer
        gloss.translateBy(x: -r * 0.38, y: -r * 0.44)
        gloss.rotate(by: .radians(-0.48))
        gloss.fill(
            Path(ellipseIn: CGRect(x: -r * 0.22, y: -r * 0.10, width: r * 0.44, height: r * 0.20)),
            with: .color(.white.opacity(0.72))
        )

        // 5. Big Googly Cartoon Eyes & Expressive Mouth
        drawGooglyFace(state, in: &bodyLayer, radius: r)

        // 6. Key Symbol Belly Badge (tucked cleanly at the bottom below the mouth)
        if showLabel, !state.burst.label.isEmpty {
            drawBellyBadge(
                state.burst.label,
                in: &bodyLayer,
                radius: r,
                hue: state.burst.hue
            )
        }
    }

    private static func critterBodyPath(row: Int, radius r: CGFloat) -> Path {
        var path = Path()
        switch row {
        case 3:
            // Row 3: Chonky Rounded Gummy Cube
            let rect = CGRect(x: -r * 0.88, y: -r * 0.82, width: r * 1.76, height: r * 1.64)
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: r * 0.40, height: r * 0.40))

        case 1:
            // Row 1: Pear / Gumdrop Jelly (narrower crown, chubby lower cheeks)
            path.move(to: CGPoint(x: 0, y: -r * 0.88))
            path.addCurve(
                to: CGPoint(x: r * 0.96, y: r * 0.24),
                control1: CGPoint(x: r * 0.60, y: -r * 0.88),
                control2: CGPoint(x: r * 0.98, y: -r * 0.32)
            )
            path.addCurve(
                to: CGPoint(x: 0, y: r * 0.84),
                control1: CGPoint(x: r * 0.94, y: r * 0.78),
                control2: CGPoint(x: r * 0.48, y: r * 0.84)
            )
            path.addCurve(
                to: CGPoint(x: -r * 0.96, y: r * 0.24),
                control1: CGPoint(x: -r * 0.48, y: r * 0.84),
                control2: CGPoint(x: -r * 0.94, y: r * 0.78)
            )
            path.addCurve(
                to: CGPoint(x: 0, y: -r * 0.88),
                control1: CGPoint(x: -r * 0.98, y: -r * 0.32),
                control2: CGPoint(x: -r * 0.60, y: -r * 0.88)
            )
            path.closeSubpath()

        default:
            // Row 0 & Row 2: Wide Pudding / Slime Dome with flat-ish bottom cushion
            path.move(to: CGPoint(x: 0, y: -r * 0.86))
            path.addCurve(
                to: CGPoint(x: r * 0.96, y: r * 0.20),
                control1: CGPoint(x: r * 0.68, y: -r * 0.86),
                control2: CGPoint(x: r * 0.98, y: -r * 0.38)
            )
            path.addCurve(
                to: CGPoint(x: 0, y: r * 0.80),
                control1: CGPoint(x: r * 0.95, y: r * 0.76),
                control2: CGPoint(x: r * 0.52, y: r * 0.80)
            )
            path.addCurve(
                to: CGPoint(x: -r * 0.96, y: r * 0.20),
                control1: CGPoint(x: -r * 0.52, y: r * 0.80),
                control2: CGPoint(x: -r * 0.95, y: r * 0.76)
            )
            path.addCurve(
                to: CGPoint(x: 0, y: -r * 0.86),
                control1: CGPoint(x: -r * 0.98, y: -r * 0.38),
                control2: CGPoint(x: -r * 0.68, y: -r * 0.86)
            )
            path.closeSubpath()
        }
        return path
    }

    /// Arms rise with height and fling down on impact, a beat behind the body.
    /// Feet dangle and splay while airborne.
    private static func drawLimbs(
        _ state: CritterState,
        in context: inout GraphicsContext,
        radius r: CGFloat,
        fill: Color
    ) {
        let raise = clamp(
            0.30 + 0.65 * state.limbLift + 1.4 * state.limbs.deform,
            lower: -0.30,
            upper: 1.15
        )
        for dir in [-1.0 as CGFloat, 1.0 as CGFloat] {
            var arm = context
            arm.translateBy(x: dir * r * 0.84, y: -r * 0.02)
            arm.rotate(by: .radians(Double(dir * (state.armWave - raise))))
            let armRect = CGRect(
                x: dir > 0 ? -r * 0.05 : -r * 0.43,
                y: -r * 0.14,
                width: r * 0.48,
                height: r * 0.28
            )
            let armPath = Path(roundedRect: armRect, cornerRadius: r * 0.14)
            arm.fill(armPath, with: .color(fill))
            arm.stroke(armPath, with: .color(.white.opacity(0.88)), lineWidth: max(2.0, r * 0.05))

            var foot = context
            foot.translateBy(x: dir * r * 0.45, y: r * (0.76 + 0.06 * state.limbLift))
            foot.rotate(by: .radians(Double(dir * 0.28 * state.limbLift)))
            let footRect = CGRect(x: -r * 0.24, y: -r * 0.14, width: r * 0.48, height: r * 0.30)
            let footPath = Path(ellipseIn: footRect)
            foot.fill(footPath, with: .color(fill))
            foot.stroke(footPath, with: .color(.white.opacity(0.88)), lineWidth: max(2.0, r * 0.05))
        }
    }

    /// Head parts trail the body: they splay outward when it squashes, pinch in when it
    /// stretches, and swing behind it when it rocks.
    private static func drawHeadAttachments(
        _ state: CritterState,
        in context: inout GraphicsContext,
        radius r: CGFloat,
        fill: Color
    ) {
        if state.burst.kind == .confetti {
            drawPartyCrown(in: &context, radius: r)
            return
        }

        let splay = -state.tips.deform
        let swing = state.tips.rock - state.body.rock

        switch state.row {
        case 0:
            // Row 0: Two Bouncy Alien Pom-Pom Antennas
            let spread = clamp(1.3 * splay, lower: -0.35, upper: 0.6) + 0.06 * state.idle
            for dir in [-1.0 as CGFloat, 1.0 as CGFloat] {
                var stalk = Path()
                let base = CGPoint(x: dir * r * 0.32, y: -r * 0.76)
                let tip = CGPoint(
                    x: dir * r * (0.48 + spread * 0.3) + swing * r * 0.6,
                    y: -r * 1.22
                )
                stalk.move(to: base)
                stalk.addQuadCurve(
                    to: tip,
                    control: CGPoint(x: dir * r * 0.20, y: -r * 1.05)
                )
                context.stroke(
                    stalk,
                    with: .color(.white.opacity(0.92)),
                    style: StrokeStyle(lineWidth: max(2.5, r * 0.07), lineCap: .round)
                )
                let bulbR = r * 0.17
                let bulbRect = CGRect(x: tip.x - bulbR, y: tip.y - bulbR, width: bulbR * 2, height: bulbR * 2)
                context.fill(Path(ellipseIn: bulbRect), with: .color(fill))
                context.stroke(Path(ellipseIn: bulbRect), with: .color(.white), lineWidth: max(1.5, r * 0.04))
            }

        case 1:
            // Row 1: Tall Floppy Bunny Ears
            let flop = clamp(1.5 * splay, lower: -0.25, upper: 0.55) + 0.05 * state.idle
            for dir in [-1.0 as CGFloat, 1.0 as CGFloat] {
                var ear = context
                ear.translateBy(x: dir * r * 0.36, y: -r * 0.74)
                ear.rotate(by: .radians(Double(dir * (0.24 + flop) + swing * 1.2)))
                let earRect = CGRect(x: -r * 0.19, y: -r * 0.66, width: r * 0.38, height: r * 0.76)
                let earPath = Path(roundedRect: earRect, cornerRadius: r * 0.19)
                ear.fill(earPath, with: .color(fill))
                ear.stroke(earPath, with: .color(.white.opacity(0.90)), lineWidth: max(2.0, r * 0.05))
                let innerRect = CGRect(x: -r * 0.09, y: -r * 0.50, width: r * 0.18, height: r * 0.46)
                ear.fill(
                    Path(roundedRect: innerRect, cornerRadius: r * 0.09),
                    with: .color(Color(red: 1.0, green: 0.65, blue: 0.78).opacity(0.78))
                )
            }

        case 3:
            // Row 3: Round Bear Ears on Top Corners
            for dir in [-1.0 as CGFloat, 1.0 as CGFloat] {
                let earCenter = CGPoint(x: dir * r * 0.58, y: -r * 0.80)
                let earR = r * 0.27
                let earRect = CGRect(x: earCenter.x - earR, y: earCenter.y - earR, width: earR * 2, height: earR * 2)
                context.fill(Path(ellipseIn: earRect), with: .color(fill))
                context.stroke(Path(ellipseIn: earRect), with: .color(.white.opacity(0.90)), lineWidth: max(2.0, r * 0.05))
            }

        default:
            // Row 2: Two-Leaf Bouncy Sprout on Top
            var sprout = context
            sprout.translateBy(x: 0, y: -r * 0.80)
            sprout.rotate(by: .radians(Double(0.06 * state.idle + swing * 1.4)))
            var stem = Path()
            stem.move(to: .zero)
            stem.addLine(to: CGPoint(x: 0, y: -r * 0.28))
            sprout.stroke(
                stem,
                with: .color(.white.opacity(0.92)),
                style: StrokeStyle(lineWidth: max(2.5, r * 0.06), lineCap: .round)
            )
            let leafColor = PerceptualColor.bloom(
                hue: PerceptualColor.wrappedHue(state.burst.hue + 0.25),
                lightness: 0.86,
                chroma: 0.18
            )
            let leafOpen = clamp(1.2 * splay, lower: -0.3, upper: 0.5)
            for dir in [-1.0 as CGFloat, 1.0 as CGFloat] {
                var leaf = sprout
                leaf.translateBy(x: dir * r * 0.19, y: -r * 0.28)
                leaf.rotate(by: .radians(Double(dir * (0.50 + leafOpen))))
                let leafRect = CGRect(x: -r * 0.19, y: -r * 0.10, width: r * 0.38, height: r * 0.20)
                leaf.fill(Path(ellipseIn: leafRect), with: .color(leafColor))
                leaf.stroke(Path(ellipseIn: leafRect), with: .color(.white.opacity(0.88)), lineWidth: 1.5)
            }
        }
    }

    private static func drawGooglyFace(
        _ state: CritterState,
        in context: inout GraphicsContext,
        radius r: CGFloat
    ) {
        let eyeY = -r * 0.24
        let eyeX = r * 0.36
        let whiteEyeR = r * 0.27
        let pupilR = r * 0.145
        let ink = Color(red: 0.09, green: 0.07, blue: 0.16)
        let cheekColor = Color(red: 1.0, green: 0.42, blue: 0.62).opacity(0.65)

        // Pupils look toward the gaze target and sink with the squash a beat late, like loose googly eyes.
        var look = CGVector(
            dx: state.gaze.dx * whiteEyeR * 0.30,
            dy: state.gaze.dy * whiteEyeR * 0.30 - state.eyes.deform * whiteEyeR * 0.9
        )
        let maxLook = whiteEyeR - pupilR - r * 0.01
        let lookLength = hypot(look.dx, look.dy)
        if lookLength > maxLook {
            look = CGVector(dx: look.dx / lookLength * maxLook, dy: look.dy / lookLength * maxLook)
        }

        for dir in [-1.0 as CGFloat, 1.0 as CGFloat] {
            let ex = dir * eyeX
            let eyeRect = CGRect(
                x: ex - whiteEyeR,
                y: eyeY - whiteEyeR,
                width: whiteEyeR * 2,
                height: whiteEyeR * 2
            )

            // Big Googly White Sclera
            context.fill(Path(ellipseIn: eyeRect), with: .color(.white))
            context.stroke(Path(ellipseIn: eyeRect), with: .color(ink.opacity(0.85)), lineWidth: max(2.0, r * 0.045))

            if state.isBlinking {
                var blink = Path()
                blink.move(to: CGPoint(x: ex - whiteEyeR * 0.65, y: eyeY))
                blink.addLine(to: CGPoint(x: ex + whiteEyeR * 0.65, y: eyeY))
                context.stroke(
                    blink,
                    with: .color(ink),
                    style: StrokeStyle(lineWidth: max(2.2, r * 0.055), lineCap: .round)
                )
            } else {
                let px = ex + look.dx
                let py = eyeY + look.dy
                let pupilRect = CGRect(x: px - pupilR, y: py - pupilR, width: pupilR * 2, height: pupilR * 2)
                context.fill(Path(ellipseIn: pupilRect), with: .color(ink))

                let shineR = pupilR * 0.38
                let shineRect = CGRect(
                    x: px - pupilR * 0.35 - shineR,
                    y: py - pupilR * 0.35 - shineR,
                    width: shineR * 2,
                    height: shineR * 2
                )
                context.fill(Path(ellipseIn: shineRect), with: .color(.white))
            }

            // Rosy cheeks
            let cheekRect = CGRect(
                x: dir * r * 0.60 - r * 0.14,
                y: eyeY + r * 0.24,
                width: r * 0.28,
                height: r * 0.16
            )
            context.fill(Path(ellipseIn: cheekRect), with: .color(cheekColor))
        }

        // Expressive Mouth: opens smoothly into a wide cheering D-mouth with a pink tongue
        let mouthY = eyeY + r * 0.28
        let mouthW = r * (0.30 + 0.08 * state.cheer)
        let mouthH = r * (0.17 + 0.08 * state.cheer)

        var mouthPath = Path()
        mouthPath.move(to: CGPoint(x: -mouthW / 2, y: mouthY))
        mouthPath.addQuadCurve(
            to: CGPoint(x: mouthW / 2, y: mouthY),
            control: CGPoint(x: 0, y: mouthY + mouthH * 1.45)
        )
        mouthPath.closeSubpath()
        context.fill(mouthPath, with: .color(ink))

        let tongueW = mouthW * 0.58
        let tongueH = mouthH * 0.56
        let tongueRect = CGRect(
            x: -tongueW / 2,
            y: mouthY + mouthH * 0.22,
            width: tongueW,
            height: tongueH
        )
        context.fill(
            Path(ellipseIn: tongueRect),
            with: .color(Color(red: 1.0, green: 0.48, blue: 0.65))
        )
    }

    private static func drawBellyBadge(
        _ label: String,
        in context: inout GraphicsContext,
        radius r: CGFloat,
        hue: Double
    ) {
        let badgeY = r * 0.48
        let badgeR = r * 0.26
        let badgeRect = CGRect(
            x: -badgeR * 1.20,
            y: badgeY - badgeR * 0.82,
            width: badgeR * 2.40,
            height: badgeR * 1.64
        )
        context.fill(
            Path(roundedRect: badgeRect, cornerRadius: badgeR * 0.82),
            with: .color(.white.opacity(0.92))
        )

        let fontSize = max(12, r * 0.36)
        let ink = PerceptualColor.bloom(
            hue: hue,
            lightness: 0.24,
            chroma: 0.14,
            opacity: 0.96
        )
        let resolved = context.resolve(
            Text(label)
                .font(.system(size: 100, weight: .black, design: .rounded))
                .foregroundStyle(ink)
        )
        var textLayer = context
        textLayer.translateBy(x: 0, y: badgeY)
        textLayer.scaleBy(x: fontSize / 100.0, y: fontSize / 100.0)
        textLayer.draw(resolved, at: .zero, anchor: .center)
    }

    private static func drawPartyCrown(in context: inout GraphicsContext, radius r: CGFloat) {
        var crown = Path()
        let baseW = r * 0.48
        let topY = -r * 1.24
        let botY = -r * 0.80
        crown.move(to: CGPoint(x: -baseW, y: botY))
        crown.addLine(to: CGPoint(x: -baseW * 0.85, y: topY))
        crown.addLine(to: CGPoint(x: -baseW * 0.32, y: (topY + botY) * 0.52))
        crown.addLine(to: CGPoint(x: 0, y: topY - r * 0.10))
        crown.addLine(to: CGPoint(x: baseW * 0.32, y: (topY + botY) * 0.52))
        crown.addLine(to: CGPoint(x: baseW * 0.85, y: topY))
        crown.addLine(to: CGPoint(x: baseW, y: botY))
        crown.closeSubpath()

        let gold = PerceptualColor.bloom(hue: 0.14, lightness: 0.88, chroma: 0.18, opacity: 0.98)
        context.fill(crown, with: .color(gold))
        context.stroke(crown, with: .color(.white.opacity(0.92)), lineWidth: max(2.0, r * 0.04))
    }

    /// Little party jellies spiral outward, hopping lower as they go and squashing on each landing.
    private static func drawChordMiniJellies(
        _ state: CritterState,
        center: CGPoint,
        in context: inout GraphicsContext
    ) {
        let count = 6
        let eased = BloomEnvelope.easeOutCubic(state.progress)
        let miniR = state.radius * 0.28
        let hopHeight = state.radius * 0.38 * (1 - 0.6 * eased)
        for idx in 0..<count {
            let angle = CGFloat(idx) / CGFloat(count) * .pi * 2.0 + state.progress * 1.5
            let spread = state.radius * (1.20 + eased * 1.25)
            let arc = abs(sin(CGFloat(state.age) * 6.5 + CGFloat(idx)))
            let contact = 1 - min(1, arc / 0.22)
            let width = miniR * (1 + 0.24 * contact)
            let height = miniR * (1 - 0.24 * contact)
            let bottom = CGPoint(
                x: center.x + cos(angle) * spread,
                y: center.y + sin(angle) * spread * 0.55 + miniR - arc * hopHeight
            )
            let miniHue = PerceptualColor.wrappedHue(state.burst.hue + Double(idx) * 0.14)
            let miniColor = PerceptualColor.bloom(hue: miniHue, opacity: 0.94)
            let rect = CGRect(x: bottom.x - width, y: bottom.y - height * 2, width: width * 2, height: height * 2)
            context.fill(Path(ellipseIn: rect), with: .color(miniColor))
            context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.88)), lineWidth: 2.0)
        }
    }

    private static func rowFallback(for kind: BloomKind) -> Int {
        switch kind {
        case .star: return 0
        case .bubble: return 1
        case .flower: return 2
        case .pinwheel: return 3
        default: return 2
        }
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
