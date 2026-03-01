import Foundation

struct CategorizationResult {
    let category: NoteCategory
    let tags: [String]
    let confidence: Double
}

struct TextCategorizationEngine {
    private static let shoppingKeywords = [
        "buy", "purchase", "grocery", "groceries", "store", "shop",
        "milk", "bread", "eggs", "chicken", "rice", "vegetables",
        "fruit", "meat", "cheese", "butter", "cereal", "snacks",
        "detergent", "soap", "shampoo", "toothpaste",
        "shopping list", "pick up", "need to get"
    ]

    private static let taskKeywords = [
        "todo", "to do", "to-do", "finish", "complete", "submit",
        "send", "call", "email", "schedule", "book", "fix",
        "update", "review", "clean", "organize", "prepare",
        "do", "make", "write", "today", "deadline", "urgent",
        "by tomorrow", "due", "asap", "priority"
    ]

    private static let projectKeywords = [
        "project", "milestone", "phase", "sprint", "plan",
        "roadmap", "initiative", "strategy", "design",
        "develop", "build", "implement", "research",
        "long term", "long-term", "ongoing", "quarterly"
    ]

    private static let reminderKeywords = [
        "remind", "reminder", "don't forget", "remember",
        "appointment", "meeting", "event", "birthday",
        "anniversary", "at", "on", "tomorrow", "next week",
        "next month", "alarm", "notification"
    ]

    func categorize(_ text: String) -> CategorizationResult {
        let lowercased = text.lowercased()

        let scores: [(NoteCategory, Double)] = [
            (.shopping, calculateScore(for: lowercased, keywords: Self.shoppingKeywords)),
            (.task, calculateScore(for: lowercased, keywords: Self.taskKeywords)),
            (.project, calculateScore(for: lowercased, keywords: Self.projectKeywords)),
            (.reminder, calculateScore(for: lowercased, keywords: Self.reminderKeywords))
        ]

        let best = scores.max(by: { $0.1 < $1.1 }) ?? (.task, 0.0)
        let tags = extractTags(from: lowercased)

        return CategorizationResult(
            category: best.1 > 0 ? best.0 : .task,
            tags: tags,
            confidence: best.1
        )
    }

    func extractTags(from text: String) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 3 }

        let stopWords: Set<String> = [
            "this", "that", "with", "from", "have", "will",
            "been", "were", "they", "their", "about", "would",
            "there", "could", "other", "than", "then", "when",
            "what", "which", "these", "those", "your", "some",
            "them", "into", "just", "also", "very", "need"
        ]

        let meaningful = words.filter { !stopWords.contains($0.lowercased()) }
        let unique = Array(Set(meaningful))
        return Array(unique.prefix(5))
    }

    private func calculateScore(for text: String, keywords: [String]) -> Double {
        let matchCount = keywords.filter { text.contains($0) }.count
        return Double(matchCount) / Double(max(keywords.count, 1))
    }
}
