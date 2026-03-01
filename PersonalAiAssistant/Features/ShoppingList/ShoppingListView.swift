import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Query(
        filter: #Predicate<Note> { $0.categoryRawValue == "shopping" },
        sort: \Note.createdAt,
        order: .reverse
    ) private var items: [Note]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(items, id: \.id) { item in
                    HStack {
                        Image(systemName: item.isCompleted
                              ? "checkmark.circle.fill"
                              : "circle")
                            .foregroundStyle(item.isCompleted ? .green : .secondary)
                            .onTapGesture { item.isCompleted.toggle() }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.content)
                                .strikethrough(item.isCompleted)
                                .foregroundStyle(item.isCompleted ? .secondary : .primary)

                            if !item.tags.isEmpty {
                                HStack {
                                    ForEach(item.tags, id: \.id) { tag in
                                        Text(tag.name)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.green.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Shopping List")
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: "cart.fill",
                        description: Text("Shopping items will appear here.")
                    )
                }
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}
