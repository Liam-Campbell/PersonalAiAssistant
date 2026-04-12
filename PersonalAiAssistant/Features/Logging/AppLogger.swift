import Foundation
import SwiftData

@Observable final class AppLogger {
    static let shared = AppLogger()

    private(set) var container: ModelContainer?

    var logContainer: ModelContainer? { container }

    private static let crashLogURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("crash_log.txt")
    }()

    private init() {}

    func configure(container: ModelContainer) {
        self.container = container
    }

    @MainActor
    func log(_ level: LogLevel, source: String, message: String, detail: String? = nil, relatedEntityId: UUID? = nil) {
        guard let container else { return }
        let context = container.mainContext
        let entry = LogEntry(level: level, source: source, message: message, detail: detail, relatedEntityId: relatedEntityId)
        context.insert(entry)
        try? context.save()
    }

    @MainActor
    func flush() {
        guard let container else { return }
        try? container.mainContext.save()
    }

    func crashLog(_ level: LogLevel, source: String, message: String, detail: String? = nil) {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = iso.string(from: Date())
        var line = "[\(timestamp)] [\(level.rawValue.uppercased())] [\(source)] \(message)"
        if let detail {
            line += " | \(detail)"
        }
        line += "\n"

        guard let data = line.data(using: .utf8) else { return }
        let url = Self.crashLogURL

        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    @MainActor
    func importCrashLogsIfNeeded() {
        let url = Self.crashLogURL
        guard FileManager.default.fileExists(atPath: url.path),
              let contents = try? String(contentsOf: url, encoding: .utf8),
              !contents.isEmpty,
              let container else { return }

        let context = container.mainContext
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for line in contents.components(separatedBy: "\n") where !line.isEmpty {
            let parsed = parseCrashLogLine(line, formatter: iso)
            let entry = LogEntry(
                level: parsed.level,
                source: parsed.source,
                message: parsed.message,
                detail: parsed.detail
            )
            entry.timestamp = parsed.timestamp
            context.insert(entry)
        }
        try? context.save()
        try? FileManager.default.removeItem(at: url)
    }

    private func parseCrashLogLine(_ line: String, formatter: ISO8601DateFormatter) -> (timestamp: Date, level: LogLevel, source: String, message: String, detail: String?) {
        var timestamp = Date()
        var level = LogLevel.error
        var source = "CrashLog"
        var message = line
        var detail: String?

        let pattern = /^\[(.+?)\] \[(.+?)\] \[(.+?)\] (.+)$/
        if let match = try? pattern.firstMatch(in: line) {
            if let date = formatter.date(from: String(match.1)) {
                timestamp = date
            }
            level = LogLevel(rawValue: String(match.2).lowercased()) ?? .error
            source = String(match.3)
            let remainder = String(match.4)
            if let pipeIndex = remainder.range(of: " | ") {
                message = String(remainder[remainder.startIndex..<pipeIndex.lowerBound])
                detail = String(remainder[pipeIndex.upperBound...])
            } else {
                message = remainder
            }
        }
        return (timestamp, level, source, message, detail)
    }

    @MainActor
    func pruneOldEntries(olderThan days: Int = 30) {
        guard let container else { return }
        let context = container.mainContext
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = #Predicate<LogEntry> { $0.timestamp < cutoff }
        let descriptor = FetchDescriptor<LogEntry>(predicate: predicate)
        guard let oldEntries = try? context.fetch(descriptor) else { return }
        for entry in oldEntries {
            context.delete(entry)
        }
        try? context.save()
    }
}
