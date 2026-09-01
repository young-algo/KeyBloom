import Foundation

/// Opt-in diagnostic logging. Enabled by launching with KEYBLOOM_DEBUG=1.
/// Writes to ~/Library/Logs/KeyBloom.log so the kiosk UI never has to surface it.
enum DebugLog {
    static let isEnabled: Bool = ProcessInfo.processInfo.environment["KEYBLOOM_DEBUG"] == "1"

    private static let queue = DispatchQueue(label: "com.kevinturner.keybloom.debuglog")

    private static let fileURL: URL = {
        let logs = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs.appendingPathComponent("KeyBloom.log")
    }()

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func write(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        let line = "\(formatter.string(from: Date())) \(message())\n"

        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
}
