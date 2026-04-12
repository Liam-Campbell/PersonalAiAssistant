import Foundation
import SwiftData

@Observable final class AppLogger {
    static let shared = AppLogger()

    private(set) var container: ModelContainer?

    var logContainer: ModelContainer? { container }

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
