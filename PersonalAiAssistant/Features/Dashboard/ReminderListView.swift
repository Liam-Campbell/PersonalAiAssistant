import SwiftUI
import SwiftData

struct ReminderListView: View {
    @Query(
        filter: #Predicate<Note> { $0.categoryRawValue == "reminder" },
        sort: \Note.createdAt,
        order: .reverse
    ) private var reminders: [Note]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(reminders, id: \.id) { reminder in
                    NoteRowView(note: reminder)
                }
                .onDelete(perform: deleteReminders)
            }
            .navigationTitle("Reminders")
            .overlay {
                if reminders.isEmpty {
                    ContentUnavailableView(
                        "No Reminders",
                        systemImage: "bell.fill",
                        description: Text("Reminders will appear here.")
                    )
                }
            }
        }
    }

    private func deleteReminders(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(reminders[index])
        }
    }
}
