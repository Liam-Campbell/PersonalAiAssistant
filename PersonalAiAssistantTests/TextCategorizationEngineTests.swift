import XCTest
@testable import PersonalAiAssistant

final class TextCategorizationEngineTests: XCTestCase {
    private var engine: TextCategorizationEngine!

    override func setUp() {
        super.setUp()
        engine = TextCategorizationEngine()
    }

    func testShoppingCategorization() {
        let result = engine.categorize("I need to buy milk and eggs from the grocery store")
        XCTAssertEqual(result.category, .shopping)
    }

    func testTaskCategorization() {
        let result = engine.categorize("I need to finish the report and submit it by tomorrow")
        XCTAssertEqual(result.category, .task)
    }

    func testProjectCategorization() {
        let result = engine.categorize("The project roadmap needs a new milestone for the sprint")
        XCTAssertEqual(result.category, .project)
    }

    func testReminderCategorization() {
        let result = engine.categorize("Remind me about the meeting appointment tomorrow")
        XCTAssertEqual(result.category, .reminder)
    }

    func testDefaultCategoryForAmbiguousText() {
        let result = engine.categorize("hello world")
        XCTAssertEqual(result.category, .task)
    }

    func testTagExtraction() {
        let result = engine.categorize("Buy fresh vegetables and chicken for dinner tonight")
        XCTAssertFalse(result.tags.isEmpty)
    }

    func testEmptyTextDefaultsToTask() {
        let result = engine.categorize("")
        XCTAssertEqual(result.category, .task)
    }

    func testConfidenceIsNonNegative() {
        let result = engine.categorize("Some random text about anything")
        XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
    }

    func testShoppingKeywordsProduceHigherConfidenceThanTask() {
        let shoppingResult = engine.categorize("buy groceries at the store and get milk bread eggs")
        let taskResult = engine.categorize("a simple note with no keywords")
        XCTAssertGreaterThan(shoppingResult.confidence, taskResult.confidence)
    }

    func testExtractTagsRemovesStopWords() {
        let tags = engine.extractTags(from: "this is about their project with some details")
        let stopWords = ["this", "about", "their", "with", "some"]
        for tag in tags {
            XCTAssertFalse(stopWords.contains(tag.lowercased()))
        }
    }
}
