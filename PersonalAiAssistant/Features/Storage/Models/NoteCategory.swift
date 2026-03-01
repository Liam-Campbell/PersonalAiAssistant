import Foundation

enum NoteCategory: String, Codable, CaseIterable, Identifiable {
    case task
    case project
    case reminder
    case shopping

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .task: "Task"
        case .project: "Project"
        case .reminder: "Reminder"
        case .shopping: "Shopping"
        }
    }

    var systemImage: String {
        switch self {
        case .task: "checkmark.circle"
        case .project: "folder.fill"
        case .reminder: "bell.fill"
        case .shopping: "cart.fill"
        }
    }

    var tintColor: String {
        switch self {
        case .task: "blue"
        case .project: "purple"
        case .reminder: "orange"
        case .shopping: "green"
        }
    }
}
