import SwiftUI

struct NoteRowView: View {
    let note: Note

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: note.category.systemImage)
                .foregroundStyle(categoryColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.content)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(note.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(note.tags, id: \.id) { tag in
                        Text(tag.name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            if note.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private var categoryColor: Color {
        switch note.category {
        case .task: .blue
        case .project: .purple
        case .reminder: .orange
        case .shopping: .green
        }
    }
}
