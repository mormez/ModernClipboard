import Foundation
import OSLog

// Writes a plain-text log to ~/Library/Logs/Modern Clipboard/app.log so non-technical
// users can attach it to a bug report via the "Export Diagnostics…" button.
// Never log clipboard contents — only metadata (type, length, success/failure).
final class AppLogger {
    static let shared = AppLogger()

    static var fileURL: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/Modern Clipboard", isDirectory: true)
            .appendingPathComponent("app.log")
    }

    private let osLog = Logger(subsystem: "com.modernclipboard.app", category: "general")
    private let queue = DispatchQueue(label: "com.modernclipboard.logger")
    private let maxBytes = 2_000_000

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private init() {
        try? FileManager.default.createDirectory(
            at: Self.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    func log(_ message: String) {
        osLog.log("\(message, privacy: .public)")
        queue.async { self.append(message) }
    }

    private func append(_ message: String) {
        let line = "[\(Self.formatter.string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if let handle = try? FileHandle(forWritingTo: Self.fileURL) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try? data.write(to: Self.fileURL)
        }
        trimIfNeeded()
    }

    private func trimIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: Self.fileURL.path),
              let size = attrs[.size] as? Int, size > maxBytes,
              let content = try? String(contentsOf: Self.fileURL, encoding: .utf8) else { return }
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        let keep = lines.suffix(lines.count / 2).joined(separator: "\n")
        try? keep.write(to: Self.fileURL, atomically: true, encoding: .utf8)
    }
}
