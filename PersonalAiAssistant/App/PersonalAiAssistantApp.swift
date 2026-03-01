import SwiftUI
import SwiftData

@main
struct PersonalAiAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: Note.self)
    }
}
