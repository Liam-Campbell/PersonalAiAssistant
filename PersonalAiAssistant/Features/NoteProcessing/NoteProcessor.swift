import SwiftData

struct NoteProcessor {
    private let engine = TextCategorizationEngine()

    func processAndSave(text: String, context: ModelContext) {
        let result = engine.categorize(text)
        let note = Note(content: text, category: result.category)

        for tagName in result.tags {
            note.tags.append(Tag(name: tagName))
        }

        context.insert(note)
    }

    func recategorize(note: Note) -> CategorizationResult {
        engine.categorize(note.content)
    }
}
