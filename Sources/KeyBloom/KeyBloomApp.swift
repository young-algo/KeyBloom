import SwiftUI

@main
struct KeyBloomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator = GameCoordinator.shared

    var body: some Scene {
        WindowGroup(AppConfig.displayName) {
            if ProcessInfo.processInfo.environment["KEYBLOOM_STRESS"] == "1" {
                BloomStressView(
                    displayCount: Int(
                        ProcessInfo.processInfo.environment["KEYBLOOM_PROFILE_DISPLAYS"] ?? "1"
                    ) ?? 1
                )
                .frame(width: 1440, height: 900)
            } else if ProcessInfo.processInfo.environment["KEYBLOOM_SHOWCASE"] == "1" {
                ScrollView([.horizontal, .vertical]) {
                    BloomShowcaseView(palette: .rainbow, calm: false)
                }
                .frame(width: 920, height: 760)
            } else {
                LaunchView()
                    .environmentObject(coordinator)
                    .frame(width: 720, height: 720)
            }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .saveItem) { }
            CommandGroup(replacing: .printItem) { }
            CommandGroup(replacing: .appTermination) {
                Button("Quit KeyBloom") {
                    coordinator.quitFromSetup()
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}
