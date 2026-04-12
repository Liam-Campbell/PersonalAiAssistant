import SwiftUI
import SwiftData
import MLXLMCommon

struct ReceiptListScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.scannedDate, order: .reverse) private var receipts: [Receipt]
    let modelContainer: MLXLMCommon.ModelContainer

    @State private var showingScan = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if receipts.isEmpty {
                    emptyState
                } else {
                    receiptList
                }
            }
            .navigationTitle("Receipts")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingScan = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(isPresented: $showingScan) {
                ReceiptScanScreen(modelContainer: modelContainer)
            }
            .navigationDestination(isPresented: $showingSettings) {
                SettingsScreen()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Receipts", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Tap + to scan your first receipt.")
        }
    }

    private var receiptList: some View {
        List(receipts) { receipt in
            NavigationLink(destination: ReceiptDetailScreen(receipt: receipt, modelContainer: modelContainer)) {
                ReceiptRow(receipt: receipt)
            }
        }
    }
}

private struct ReceiptRow: View {
    let receipt: Receipt

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.store.name)
                    .font(.headline)
                Text(receipt.purchaseDate, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatTotal(receipt.total, currency: receipt.currency))
                .font(.headline)
            Image(systemName: receipt.status == .verified ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(receipt.status == .verified ? .green : .orange)
        }
        .padding(.vertical, 4)
    }

    private func formatTotal(_ total: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: total as NSDecimalNumber) ?? "\(total)"
    }
}
