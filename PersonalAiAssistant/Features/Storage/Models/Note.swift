import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var content: String
    var createdAt: Date
    var categoryRawValue: String
    var isCompleted: Bool
    @Relationship(deleteRule: .cascade) var tags: [Tag]

    var category: NoteCategory {
        get { NoteCategory(rawValue: categoryRawValue) ?? .task }
        set { categoryRawValue = newValue.rawValue }
    }

    init(content: String, category: NoteCategory = .task) {
        self.id = UUID()
        self.content = content
        self.createdAt = Date()
        self.categoryRawValue = category.rawValue
        self.isCompleted = false
        self.tags = []
    }
}
