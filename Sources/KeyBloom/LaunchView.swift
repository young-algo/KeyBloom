import SwiftUI

struct LaunchView: View {
    @EnvironmentObject private var coordinator: GameCoordinator

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
        }
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
        HStack(spacing: 18) {
            PreviewBloom(symbol: "A", hue: 0.02, rotation: -8)
            PreviewBloom(symbol: "✦", hue: 0.14, rotation: 7)
            PreviewBloom(symbol: "⌘", hue: 0.53, rotation: -5)
            PreviewBloom(symbol: "●", hue: 0.75, rotation: 9)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var settings: some View {
        VStack(spacing: 0) {
            SettingRow(title: "Colors", subtitle: coordinator.palette.subtitle) {
                Picker("Colors", selection: $coordinator.palette) {
                    ForEach(BloomPalette.allCases) { palette in
                        Text(palette.title).tag(palette)
                    }
                }
                .labelsHidden()
                .frame(width: 145)
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

private struct PreviewBloom: View {
    let symbol: String
    let hue: Double
    let rotation: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.75, brightness: 1.0),
                            Color(hue: hue, saturation: 0.90, brightness: 0.72)
                        ],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 55
                    )
                )
                .shadow(color: Color(hue: hue, saturation: 0.80, brightness: 1.0).opacity(0.42), radius: 14)

            Text(symbol)
                .font(.system(size: symbol == "⌘" ? 30 : 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 74, height: 74)
        .rotationEffect(.degrees(rotation))
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
