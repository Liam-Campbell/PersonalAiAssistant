import Foundation
import SwiftData

enum LogLevel: String, Codable, CaseIterable {
    case debug
    case info
    case warning
    case error
}

@Model final class LogEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var levelRaw: String
    var source: String
    var message: String
    var detail: String?
    var relatedEntityId: UUID?

    var level: LogLevel {
        get { LogLevel(rawValue: levelRaw) ?? .info }
        set { levelRaw = newValue.rawValue }
    }

    init(level: LogLevel, source: String, message: String, detail: String? = nil, relatedEntityId: UUID? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.levelRaw = level.rawValue
        self.source = source
        self.message = message
        self.detail = detail
        self.relatedEntityId = relatedEntityId
    }
}
