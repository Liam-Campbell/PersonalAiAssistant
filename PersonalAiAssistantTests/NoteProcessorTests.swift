import XCTest
import SwiftData
@testable import PersonalAiAssistant

final class NoteProcessorTests: XCTestCase {
    private var processor: NoteProcessor!
    private var container: ModelContainer!
    private var context: ModelContext!

    @MainActor
    override func setUp() {
        super.setUp()
        processor = NoteProcessor()

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: Note.self, Tag.self, configurations: config)
        context = container.mainContext
    }

    @MainActor
    func testProcessAndSaveCreatesNote() {
        processor.processAndSave(text: "Buy groceries from the store", context: context)

        let descriptor = FetchDescriptor<Note>()
        let notes = try! context.fetch(descriptor)
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.content, "Buy groceries from the store")
    }

    @MainActor
    func testProcessAndSaveAssignsShoppingCategory() {
        processor.processAndSave(text: "Buy groceries from the store", context: context)

        let descriptor = FetchDescriptor<Note>()
        let notes = try! context.fetch(descriptor)
        XCTAssertEqual(notes.first?.category, .shopping)
    }

    @MainActor
    func testProcessAndSaveAssignsTags() {
        processor.processAndSave(
            text: "Finish the quarterly project roadmap milestone",
            context: context
        )

        let descriptor = FetchDescriptor<Note>()
        let notes = try! context.fetch(descriptor)
        XCTAssertFalse(notes.first?.tags.isEmpty ?? true)
    }

    @MainActor
    func testRecategorizeReturnsCorrectCategory() {
        let note = Note(content: "Remind me about the meeting tomorrow", category: .task)
        let result = processor.recategorize(note: note)
        XCTAssertEqual(result.category, .reminder)
    }

    @MainActor
    func testMultipleNotesAreSavedIndependently() {
        processor.processAndSave(text: "Buy milk and eggs", context: context)
        processor.processAndSave(text: "Finish the sprint review", context: context)

        let descriptor = FetchDescriptor<Note>()
        let notes = try! context.fetch(descriptor)
        XCTAssertEqual(notes.count, 2)
    }
}
