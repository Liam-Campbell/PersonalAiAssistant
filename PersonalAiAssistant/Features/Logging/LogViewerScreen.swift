import SwiftUI
import SwiftData

struct LogViewerScreen: View {
    @State private var selectedLevels: Set<LogLevel> = Set(LogLevel.allCases)
    @State private var searchText = ""
    @State private var logEntries: [LogEntry] = []
    @State private var selectedEntry: LogEntry?
    @State private var logContext: ModelContext?

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            logList
        }
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search logs...")
        .onAppear { fetchLogs() }
        .onChange(of: selectedLevels) { _, _ in fetchLogs() }
        .onChange(of: searchText) { _, _ in fetchLogs() }
        .sheet(item: $selectedEntry) { entry in
            LogDetailSheet(entry: entry)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    FilterPill(
                        title: level.rawValue.capitalized,
                        color: colorForLevel(level),
                        isSelected: selectedLevels.contains(level)
                    ) {
                        if selectedLevels.contains(level) {
                            selectedLevels.remove(level)
                        } else {
                            selectedLevels.insert(level)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var logList: some View {
        List(logEntries) { entry in
            LogEntryRow(entry: entry) {
                selectedEntry = entry
            }
        }
        .listStyle(.plain)
    }

    private func fetchLogs() {
        if logContext == nil {
            guard let container = AppLogger.shared.logContainer else { return }
            logContext = ModelContext(container)
        }
        guard let context = logContext else { return }
        let levelRaws = selectedLevels.map { $0.rawValue }
        let descriptor = FetchDescriptor<LogEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        logEntries = entries.filter { entry in
            let levelMatch = levelRaws.contains(entry.levelRaw)
            let searchMatch = searchText.isEmpty
                || entry.source.localizedCaseInsensitiveContains(searchText)
                || entry.message.localizedCaseInsensitiveContains(searchText)
            return levelMatch && searchMatch
        }
    }

    private func colorForLevel(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

private struct FilterPill: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.2) : Color(.systemGray6))
                .foregroundStyle(isSelected ? color : .secondary)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? color : .clear, lineWidth: 1))
        }
    }
}

private struct LogEntryRow: View {
    let entry: LogEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(colorForEntry)
                            .frame(width: 8, height: 8)
                        Text(entry.source)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(entry.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.message)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var colorForEntry: Color {
        switch entry.level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

private struct LogDetailSheet: View {
    let entry: LogEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Overview") {
                    LabeledContent("Level") {
                        Text(entry.level.rawValue.capitalized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(colorForEntry)
                    }
                    LabeledContent("Source") {
                        Text(entry.source)
                            .font(.subheadline)
                    }
                    LabeledContent("Time") {
                        Text(entry.timestamp, format: .dateTime.year().month().day().hour().minute().second())
                            .font(.subheadline)
                    }
                }

                Section("Message") {
                    Text(entry.message)
                        .font(.body)
                        .textSelection(.enabled)
                }

                if let detail = entry.detail, !detail.isEmpty {
                    Section("Detail") {
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(detail)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }

                if let relatedId = entry.relatedEntityId {
                    Section("Related Entity") {
                        Text(relatedId.uuidString)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Log Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: formattedLogText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private var formattedLogText: String {
        var text = """
        [\(entry.level.rawValue.uppercased())] \(entry.source)
        Time: \(entry.timestamp)
        Message: \(entry.message)
        """
        if let detail = entry.detail {
            text += "\nDetail: \(detail)"
        }
        if let relatedId = entry.relatedEntityId {
            text += "\nRelated: \(relatedId.uuidString)"
        }
        return text
    }

    private var colorForEntry: Color {
        switch entry.level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}
