import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var allNotes: [Note]
    @State private var searchText = ""

    private var filteredNotes: [Note] {
        guard !searchText.isEmpty else { return allNotes }
        return allNotes.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(NoteCategory.allCases) { category in
                    let notes = filteredNotes.filter { $0.category == category }
                    if !notes.isEmpty {
                        Section(category.displayName) {
                            ForEach(notes, id: \.id) { note in
                                NoteRowView(note: note)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search notes...")
            .navigationTitle("Dashboard")
            .overlay {
                if allNotes.isEmpty {
                    ContentUnavailableView(
                        "No Notes Yet",
                        systemImage: "note.text",
                        description: Text("Record a voice note to get started.")
                    )
                }
            }
        }
    }
}
