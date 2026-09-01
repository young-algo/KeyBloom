import SwiftUI

@main
struct KeyBloomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator = GameCoordinator.shared

    var body: some Scene {
        WindowGroup(AppConfig.displayName) {
            LaunchView()
                .environmentObject(coordinator)
                .frame(width: 720, height: 720)
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
