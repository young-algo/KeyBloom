import SwiftUI

struct LaunchView: View {
    @EnvironmentObject private var coordinator: GameCoordinator
    @StateObject private var previewModel = GameModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: 0.64, saturation: 0.58, brightness: 0.20),
                    Color(hue: 0.77, saturation: 0.62, brightness: 0.28),
                    Color(hue: 0.93, saturation: 0.55, brightness: 0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    header
                    preview
                    settings
                    exitInstructions
                    startButton
                }
                .padding(30)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            coordinator.refreshAccessibilityPermission()
            resetPreview()
        }
        .onChange(of: coordinator.palette) { _, _ in resetPreview() }
        .onChange(of: coordinator.showLabels) { _, _ in resetPreview() }
        .onChange(of: coordinator.calmMotion) { _, _ in resetPreview() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("KEYBLOOM")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .tracking(3)

            Text("A harmless keyboard playground for tiny hands")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.top, 4)
    }

    private var preview: some View {
        LivePreview(model: previewModel)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var settings: some View {
        VStack(spacing: 0) {
            SettingRow(title: "Colors", subtitle: coordinator.palette.subtitle) {
                PaletteSwatches(selection: $coordinator.palette)
            }

            divider

            SettingRow(
                title: "Show key symbols",
                subtitle: "Each press displays a large letter or symbol"
            ) {
                Toggle("Show key symbols", isOn: $coordinator.showLabels)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            divider

            SettingRow(
                title: "Calm motion",
                subtitle: "Gentler movement with no rapid flashing"
            ) {
                Toggle("Calm motion", isOn: $coordinator.calmMotion)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            divider

            VStack(spacing: 12) {
                SettingRow(
                    title: "Strong lock",
                    subtitle: "Blocks system shortcuts and trackpad escape gestures"
                ) {
                    Toggle("Strong lock", isOn: $coordinator.strongLock)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                if coordinator.strongLock {
                    HStack(spacing: 10) {
                        Label(
                            coordinator.accessibilityPermissionGranted
                                ? "Accessibility permission is enabled"
                                : "One-time Accessibility permission is required",
                            systemImage: coordinator.accessibilityPermissionGranted
                                ? "checkmark.shield.fill"
                                : "lock.shield"
                        )
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            coordinator.accessibilityPermissionGranted
                                ? Color.green.opacity(0.90)
                                : Color.white.opacity(0.70)
                        )

                        Spacer()

                        if !coordinator.accessibilityPermissionGranted {
                            Button("Grant Permission") {
                                coordinator.requestAccessibilityPermission()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
                }
            }
        }
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var exitInstructions: some View {
        VStack(spacing: 13) {
            Text("ADULT EXIT")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.52))

            HStack(spacing: 8) {
                KeyCap("⌃")
                KeyCap("⌥")
                KeyCap("⇧")
                KeyCap("⌘")
                Text("+")
                    .foregroundStyle(.white.opacity(0.45))
                KeyCap("delete", width: 66)
            }

            Text("Hold all five for 1.5 seconds. A small unlock ring confirms the hold.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)

            Text("Backslash (\\) also works in place of delete.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.50))
                .multilineTextAlignment(.center)

            Text("Command–Option–Escape exits immediately. The Mac’s power controls remain available as a final fallback.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.46))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var startButton: some View {
        VStack(spacing: 10) {
            if let statusMessage = coordinator.statusMessage {
                Text(statusMessage)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.yellow.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }

            Button {
                coordinator.startBabyMode()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                    Text("Start Baby Mode")
                }
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black.opacity(0.82))
            .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .shadow(color: .black.opacity(0.24), radius: 16, y: 8)
            .keyboardShortcut(.return, modifiers: [])

            Text("No files are opened, no text is saved, and no input is sent to another app.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 18)
    }

    private func resetPreview() {
        previewModel.reset(
            palette: coordinator.palette,
            showLabels: coordinator.showLabels,
            calmMotion: coordinator.calmMotion
        )
        [0, 12, 18, 6, 49, 36].forEach { previewModel.registerKey(keyCode: UInt16($0)) }
    }
}

private struct SettingRow<Accessory: View>: View {
    let title: String
    let subtitle: String
    let accessory: Accessory

    init(
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer(minLength: 12)
            accessory
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct LivePreview: View {
    @ObservedObject var model: GameModel
    @State private var sampleIndex = 0
    private let timer = Timer.publish(every: 1.1, on: .main, in: .common).autoconnect()
    private let sampleKeys: [UInt16] = [0, 12, 18, 6, 49, 36]

    var body: some View {
        GameView(model: model)
            .allowsHitTesting(false)
            .onReceive(timer) { _ in
                model.registerKey(keyCode: sampleKeys[sampleIndex % sampleKeys.count])
                sampleIndex += 1
            }
            .accessibilityLabel("Live preview of the selected KeyBloom settings")
    }
}

private struct PaletteSwatches: View {
    @Binding var selection: BloomPalette

    var body: some View {
        HStack(spacing: 8) {
            ForEach(BloomPalette.allCases) { palette in
                Button {
                    selection = palette
                } label: {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.24))
                        ForEach(0..<4, id: \.self) { index in
                            let angle = CGFloat(index) / 4 * .pi * 2 - .pi / 2
                            Circle()
                                .fill(PerceptualColor.bloom(hue: palette.hue(offset: Double(index) / 4)))
                                .frame(width: 10, height: 10)
                                .offset(x: cos(angle) * 10, y: sin(angle) * 10)
                        }
                    }
                    .frame(width: 38, height: 38)
                    .overlay {
                        Circle()
                            .stroke(selection == palette ? .white : .white.opacity(0.18), lineWidth: selection == palette ? 3 : 1)
                    }
                }
                .buttonStyle(.plain)
                .help(palette.title)
                .accessibilityLabel(palette.title)
                .accessibilityAddTraits(selection == palette ? .isSelected : [])
            }
        }
    }
}

private struct KeyCap: View {
    let label: String
    let width: CGFloat

    init(_ label: String, width: CGFloat = 42) {
        self.label = label
        self.width = width
    }

    var body: some View {
        Text(label)
            .font(.system(size: label == "esc" ? 13 : 19, weight: .bold, design: .rounded))
            .frame(width: width, height: 37)
            .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.24), radius: 3, y: 2)
    }
}
