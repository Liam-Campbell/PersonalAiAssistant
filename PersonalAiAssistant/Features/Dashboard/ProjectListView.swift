import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Query(
        filter: #Predicate<Note> { $0.categoryRawValue == "project" },
        sort: \Note.createdAt,
        order: .reverse
    ) private var projects: [Note]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(projects, id: \.id) { project in
                    NoteRowView(note: project)
                }
                .onDelete(perform: deleteProjects)
            }
            .navigationTitle("Ongoing Projects")
            .overlay {
                if projects.isEmpty {
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder.fill",
                        description: Text("Project-related notes will appear here.")
                    )
                }
            }
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(projects[index])
        }
    }
}
