import AppKit
import SwiftUI

struct BloomShowcaseView: View {
    let palette: BloomPalette
    let calm: Bool
    private let stops: [Double] = [0.05, 0.25, 0.50, 0.75, 0.95]
    private let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("KeyBloom Effect Showcase")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("\(palette.title) · \(calm ? "Calm motion" : "Standard motion")")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("5%  ·  25%  ·  50%  ·  75%  ·  95%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(BloomKind.allCases, id: \.rawValue) { kind in
                    GridRow {
                        Text(kind.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .frame(width: 72, alignment: .leading)

                        ForEach(stops, id: \.self) { stop in
                            Canvas { context, size in
                                let lifetime = kind == .confetti
                                    ? AppConfig.confettiLifetime
                                    : AppConfig.burstLifetime
                                let burst = BloomBurst(
                                    createdAt: referenceDate.addingTimeInterval(-stop * lifetime),
                                    position: CGPoint(x: 0.5, y: 0.5),
                                    hue: palette.hue(forKeyCode: UInt16(kind.rawValue * 11 + 3)),
                                    label: "A",
                                    kind: kind,
                                    seed: 42,
                                    intensity: 1,
                                    lifetime: lifetime,
                                    heading: kind == .comet ? -.pi / 3 : nil
                                )
                                BloomRenderer.drawBackground(
                                    in: &context,
                                    size: size,
                                    date: referenceDate,
                                    palette: palette,
                                    calmMotion: calm
                                )
                                BloomRenderer.draw(
                                    burst: burst,
                                    in: &context,
                                    size: size,
                                    date: referenceDate,
                                    showLabel: true,
                                    calmMotion: calm
                                )
                            }
                            .frame(width: 148, height: 148)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 890, height: 1128, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct BloomStressView: View {
    let displayCount: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<max(1, displayCount), id: \.self) { displayIndex in
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    Canvas { context, size in
                        BloomRenderer.drawBackground(
                            in: &context,
                            size: size,
                            date: timeline.date,
                            palette: .rainbow,
                            calmMotion: false
                        )
                        for index in 0..<AppConfig.maximumBursts {
                            let kind = BloomKind.allCases[index % BloomKind.allCases.count]
                            let lifetime = kind == .confetti
                                ? AppConfig.confettiLifetime
                                : AppConfig.burstLifetime
                            let progress = 0.08 + Double(index % 12) / 14
                            let burst = BloomBurst(
                                createdAt: timeline.date.addingTimeInterval(-progress * lifetime),
                                position: CGPoint(
                                    x: CGFloat(0.06 + Double((index * 37 + displayIndex * 11) % 88) / 100),
                                    y: CGFloat(0.08 + Double((index * 53 + displayIndex * 7) % 84) / 100)
                                ),
                                hue: Double((index * 137) % 360) / 360,
                                label: String(UnicodeScalar(65 + index % 26)!),
                                kind: kind,
                                seed: UInt64(index + 1),
                                intensity: 0.72,
                                lifetime: lifetime,
                                heading: kind == .comet ? -.pi / 3 : nil
                            )
                            BloomRenderer.draw(
                                burst: burst,
                                in: &context,
                                size: size,
                                date: timeline.date,
                                showLabel: true,
                                calmMotion: false
                            )
                        }
                    }
                }
            }
        }
        .background(.black)
    }
}

@MainActor
enum ShowcaseSnapshotRenderer {
    static func writeAll(to directory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var outputs: [URL] = []
        for palette in BloomPalette.allCases {
            for calm in [false, true] {
                let content = BloomShowcaseView(palette: palette, calm: calm)
                let renderer = ImageRenderer(content: content)
                renderer.scale = 1
                guard let image = renderer.nsImage,
                      let tiff = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff),
                      let png = bitmap.representation(using: .png, properties: [:]) else {
                    throw SnapshotError.renderFailed(palette.title)
                }
                let mode = calm ? "calm" : "standard"
                let output = directory.appendingPathComponent("\(palette.rawValue)-\(mode).png")
                try png.write(to: output, options: .atomic)
                outputs.append(output)
            }
        }
        return outputs
    }

    enum SnapshotError: LocalizedError {
        case renderFailed(String)

        var errorDescription: String? {
            switch self {
            case .renderFailed(let palette):
                return "Could not render the \(palette) showcase."
            }
        }
    }
}
