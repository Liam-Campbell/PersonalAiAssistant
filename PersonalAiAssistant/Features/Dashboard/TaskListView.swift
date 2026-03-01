import SwiftUI
import SwiftData

struct TaskListView: View {
    @Query(
        filter: #Predicate<Note> { $0.categoryRawValue == "task" },
        sort: \Note.createdAt,
        order: .reverse
    ) private var tasks: [Note]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(tasks, id: \.id) { task in
                    NoteRowView(note: task)
                        .swipeActions(edge: .leading) {
                            Button {
                                task.isCompleted.toggle()
                            } label: {
                                Label(
                                    task.isCompleted ? "Undo" : "Complete",
                                    systemImage: task.isCompleted
                                        ? "arrow.uturn.backward"
                                        : "checkmark"
                                )
                            }
                            .tint(.green)
                        }
                }
                .onDelete(perform: deleteTasks)
            }
            .navigationTitle("Tasks for the Day")
            .overlay {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks",
                        systemImage: "checkmark.circle",
                        description: Text("Voice-captured tasks will appear here.")
                    )
                }
            }
        }
    }

    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(tasks[index])
        }
    }
}
