import CoreGraphics
import Foundation

/// Motion constants for Jelly Bounce. Heights are in critter radii; times are in seconds.
struct JellyTuning {
    /// First hop height after a critter appears.
    let hopHeight: CGFloat
    /// Airtime of that first hop. Lower hops are shorter, as they would be under one gravity.
    let hopAirtime: TimeInterval
    /// Share of the previous hop's height that each bounce keeps.
    let bounceRetention: CGFloat
    /// Hops lower than this settle instead of bouncing again.
    let minimumHop: CGFloat
    let holdHopHeight: CGFloat
    let trampolineHopHeight: CGFloat
    /// Overlapping hops ease toward this height instead of stacking without limit.
    let heightCeiling: CGFloat
    /// Deepest squash of a full-height landing, as a fraction of body height.
    let squashDepth: CGFloat
    /// Stretch while falling into a full-height landing.
    let fallStretch: CGFloat
    let squashSpring: DampedSpring
    /// Peak side-to-side rock after a full-height landing, in radians.
    let rockAmount: CGFloat
    let rockSpring: DampedSpring
    /// Resting squash "breathing", so settled critters never freeze.
    let breath: CGFloat
    /// How far a critter slumps while it fades out.
    let melt: CGFloat
    let popDuration: TimeInterval
    let popOvershoots: Bool
    let armWave: CGFloat

    static let lively = JellyTuning(
        hopHeight: 0.55,
        hopAirtime: 0.46,
        bounceRetention: 0.44,
        minimumHop: 0.04,
        holdHopHeight: 0.40,
        trampolineHopHeight: 0.80,
        heightCeiling: 1.10,
        squashDepth: 0.28,
        fallStretch: 0.10,
        squashSpring: DampedSpring(hertz: 4.2, damping: 0.30),
        rockAmount: 0.12,
        rockSpring: DampedSpring(hertz: 2.3, damping: 0.16),
        breath: 0.014,
        melt: 0.30,
        popDuration: 0.30,
        popOvershoots: true,
        armWave: 0.32
    )

    static let calm = JellyTuning(
        hopHeight: 0.30,
        hopAirtime: 0.52,
        bounceRetention: 0.27,
        minimumHop: 0.04,
        holdHopHeight: 0.22,
        trampolineHopHeight: 0.40,
        heightCeiling: 0.60,
        squashDepth: 0.15,
        fallStretch: 0.05,
        squashSpring: DampedSpring(hertz: 3.0, damping: 0.48),
        rockAmount: 0.05,
        rockSpring: DampedSpring(hertz: 1.8, damping: 0.30),
        breath: 0.010,
        melt: 0.18,
        popDuration: 0.42,
        popOvershoots: false,
        armWave: 0.18
    )

    /// Ground contact lasts half a squash-spring cycle: the body squashes on landing and
    /// leaves the ground just as it rebounds into a stretch.
    var contactDuration: TimeInterval {
        .pi / squashSpring.dampedFrequency
    }

    func airtime(for height: CGFloat) -> TimeInterval {
        hopAirtime * Double((max(height, 0) / hopHeight).squareRoot())
    }
}

/// A damped harmonic oscillator solved in closed form, so it can be sampled at any time.
struct DampedSpring {
    let naturalFrequency: Double
    let damping: Double
    let dampedFrequency: Double
    /// Peak displacement after a kick of unit velocity from rest.
    private let unitKickPeak: Double

    init(hertz: Double, damping: Double) {
        let underdamped = (1 - damping * damping).squareRoot()
        naturalFrequency = 2 * .pi * hertz
        self.damping = damping
        dampedFrequency = naturalFrequency * underdamped
        let peakTime = atan2(underdamped, damping) / dampedFrequency
        unitKickPeak = exp(-damping * naturalFrequency * peakTime)
            * sin(dampedFrequency * peakTime) / dampedFrequency
    }

    /// Displacement `time` seconds after a kick that would peak at `peak` if started from rest.
    func kick(after time: Double, peak: Double, from position: Double = 0) -> Double {
        guard time >= 0 else { return 0 }
        let velocity = peak / unitKickPeak
        let decay = exp(-damping * naturalFrequency * time)
        let angle = dampedFrequency * time
        let sineWeight = (velocity + damping * naturalFrequency * position) / dampedFrequency
        return decay * (position * cos(angle) + sineWeight * sin(angle))
    }
}

/// One hop sequence: a crouch on the ground, a launch, then lower bounces until it settles.
/// Appearing, holding a key, and trampoline waves each start one, and their motion adds up.
struct JellyBounce {
    /// Critter age when the crouch begins.
    let start: TimeInterval
    /// First hop height.
    let height: CGFloat
    /// Crouch depth before the first hop; 1 matches a full-height landing.
    let crouch: CGFloat
    /// While takeoffs happen before this age, keep relaunching at full `height`.
    var sustainUntil: TimeInterval?
    /// How excited the critter's face gets, 0...1.
    var excitement: CGFloat = 1
}

struct JellyMotionSample {
    /// Radii above the ground.
    var height: CGFloat = 0
    /// Above 0 is stretched tall; below 0 is squashed flat.
    var deform: CGFloat = 0
    /// Side-to-side rock, in radians.
    var rock: CGFloat = 0
}

/// Physics for one critter. Like every KeyBloom effect, motion is a pure function of age and
/// recorded input, so each display can draw any frame without per-frame simulation state.
struct JellyMotion {
    let bounces: [JellyBounce]
    let tuning: JellyTuning
    /// -1 or 1: which way this critter rocks first.
    let rockDirection: CGFloat
    let breathPhase: Double

    private static let maximumContacts = 64
    /// Spring kicks older than this have decayed to nothing visible.
    private static let springMemory: TimeInterval = 1.6

    func sample(at age: TimeInterval) -> JellyMotionSample {
        var sample = JellyMotionSample()
        var stackedHeight: CGFloat = 0
        for bounce in bounces {
            accumulate(bounce, at: age, height: &stackedHeight, into: &sample)
        }
        sample.height = easedTowardCeiling(stackedHeight)
        sample.deform += tuning.breath * CGFloat(sin(age * 2 * .pi * 0.45 + breathPhase))
        return sample
    }

    private func accumulate(
        _ bounce: JellyBounce,
        at age: TimeInterval,
        height: inout CGFloat,
        into sample: inout JellyMotionSample
    ) {
        let time = age - bounce.start
        guard time >= 0 else { return }

        let contactDuration = tuning.contactDuration
        var contactStart: TimeInterval = 0
        var hop = bounce.height
        var impact = bounce.crouch
        var landingStretch: CGFloat = 0

        for contactIndex in 0..<Self.maximumContacts {
            addContact(
                after: time - contactStart,
                impact: impact,
                landingStretch: landingStretch,
                side: contactIndex.isMultiple(of: 2) ? 1 : -1,
                into: &sample
            )

            let takeoff = contactStart + contactDuration
            guard hop >= tuning.minimumHop, time >= takeoff else { return }

            let airtime = tuning.airtime(for: hop)
            let landing = takeoff + airtime
            let speed = (hop / tuning.hopHeight).squareRoot()
            if time < landing {
                let u = CGFloat((time - takeoff) / airtime)
                height += 4 * hop * u * (1 - u)
                sample.deform += tuning.fallStretch * speed * BloomEnvelope.smoothstep((u - 0.5) * 2)
                return
            }

            impact = speed
            landingStretch = tuning.fallStretch * speed
            let sustained = bounce.sustainUntil.map { landing + contactDuration <= $0 } ?? false
            hop = sustained ? bounce.height : hop * tuning.bounceRetention
            contactStart = landing
        }
    }

    /// A landing (or crouch) kicks the squash spring down and the rock spring sideways.
    /// The squash starts from the falling stretch, so the shape never jumps on impact.
    private func addContact(
        after elapsed: TimeInterval,
        impact: CGFloat,
        landingStretch: CGFloat,
        side: CGFloat,
        into sample: inout JellyMotionSample
    ) {
        guard elapsed < Self.springMemory else { return }
        sample.deform += CGFloat(tuning.squashSpring.kick(
            after: elapsed,
            peak: -Double(impact * tuning.squashDepth),
            from: Double(landingStretch)
        ))
        sample.rock += rockDirection * side * impact * tuning.rockAmount
            * CGFloat(tuning.rockSpring.kick(after: elapsed, peak: 1))
    }

    private func easedTowardCeiling(_ height: CGFloat) -> CGFloat {
        let knee = tuning.heightCeiling * 0.7
        guard height > knee else { return height }
        let room = tuning.heightCeiling - knee
        return knee + room * tanh((height - knee) / room)
    }
}

extension JellyMotion {
    /// A critter's motion from everything that has happened to it so far: appearing,
    /// key holds, and trampoline waves that reached its spot (`position`, in points).
    init(
        burst: BloomBurst,
        position: CGPoint,
        trampolines: [TrampolineEvent],
        screenSize: CGSize,
        tuning: JellyTuning,
        calm: Bool
    ) {
        var random = SplitMix64(seed: burst.seed)
        let bounciness = CGFloat(random.nextDouble(in: 0.88...1.12))
        let rockDirection: CGFloat = random.nextDouble(in: 0...1) < 0.5 ? -1 : 1
        let breathPhase = random.nextDouble(in: 0...(2 * .pi))

        var bounces = [JellyBounce(start: 0, height: tuning.hopHeight * bounciness, crouch: 0.7)]

        for streak in burst.holdStreaks {
            bounces.append(JellyBounce(
                start: streak.startedAt.timeIntervalSince(burst.createdAt),
                height: tuning.holdHopHeight * bounciness,
                crouch: 0.8,
                sustainUntil: streak.lastPulseAt.timeIntervalSince(burst.createdAt) + AppConfig.holdStreakGap
            ))
        }

        // A critter is never bounced by a wave that started before it existed.
        let shortSide = max(1, min(screenSize.width, screenSize.height))
        for event in trampolines where event.date.timeIntervalSince(burst.createdAt) > 0.03 {
            let origin = CGPoint(x: event.origin.x * screenSize.width, y: event.origin.y * screenSize.height)
            let distance = hypot(position.x - origin.x, position.y - origin.y) / shortSide
            let kick = JellyTrampoline.kick(distance: distance, calm: calm)
            let strength = min(1, max(0, kick.strength))
            guard strength > 0.01 else { continue }
            bounces.append(JellyBounce(
                start: event.date.timeIntervalSince(burst.createdAt) + max(0, kick.delay),
                height: tuning.trampolineHopHeight * strength * bounciness,
                crouch: strength,
                excitement: strength
            ))
        }

        self.init(bounces: bounces, tuning: tuning, rockDirection: rockDirection, breathPhase: breathPhase)
    }

    /// 0...1: rises quickly when a bounce starts, holds through a key hold, then relaxes.
    func excitement(at age: TimeInterval) -> CGFloat {
        bounces.reduce(0) { level, bounce in
            let rise = BloomEnvelope.smoothstep(CGFloat((age - bounce.start) / 0.08))
            let end = bounce.sustainUntil ?? bounce.start
            let relax = BloomEnvelope.smoothstep(CGFloat((age - end - 0.35) / 0.4))
            return max(level, bounce.excitement * rise * (1 - relax))
        }
    }
}

/// How a trampoline wave (Space, or a multi-key chord) reaches each critter.
enum JellyTrampoline {
    struct Kick {
        /// Seconds after the press before this critter is launched.
        let delay: TimeInterval
        /// 0 leaves the critter alone; 1 is a full trampoline hop.
        let strength: CGFloat
    }

    /// `distance` is measured from where the wave started, in screen short sides:
    /// 0 is the pressed key itself, and about 1 is the far side of the screen.
    ///
    /// The wave rolls outward from the key, so nearby critters launch first and highest.
    /// It stays quick enough to read as one reaction to one press, and distant critters
    /// keep a floor of strength so everyone joins in.
    static func kick(distance: CGFloat, calm: Bool) -> Kick {
        let distance = max(0, distance)
        let secondsPerScreen: TimeInterval = calm ? 0.42 : 0.30
        let farStrength: CGFloat = calm ? 0.55 : 0.45
        let falloff = exp(-distance * 1.6)
        return Kick(
            delay: Double(distance) * secondsPerScreen,
            strength: farStrength + (1 - farStrength) * falloff
        )
    }
}
