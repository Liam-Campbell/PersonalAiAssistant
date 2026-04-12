import SwiftUI
import SwiftData
import MLXLMCommon

struct ReceiptDetailScreen: View {
    let receipt: Receipt
    let modelContainer: MLXLMCommon.ModelContainer

    @State private var showingRetry = false

    var body: some View {
        List {
            headerSection
            itemsSection
            totalsSection
            if receipt.status == .pendingReview {
                retrySection
            }
        }
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingRetry) {
            ReceiptScanScreen(modelContainer: modelContainer, existingReceiptId: receipt.id)
        }
    }

    private var headerSection: some View {
        Section {
            LabeledContent("Store", value: receipt.store.name)
            LabeledContent("Date") {
                Text(receipt.purchaseDate, style: .date)
            }
            LabeledContent("Payment", value: receipt.transactionType.rawValue.capitalized)
            if let card = receipt.paymentCard {
                LabeledContent("Card", value: card.label)
            }
            LabeledContent("Status") {
                HStack {
                    Text(receipt.status == .verified ? "Verified" : "Pending Review")
                    Image(systemName: receipt.status == .verified ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(receipt.status == .verified ? .green : .orange)
                }
            }
        }
    }

    private var itemsSection: some View {
        Section("Items") {
            ForEach(receipt.items) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .font(.body)
                        if item.quantity > 1 {
                            Text("\(item.quantity) × \(formatDecimal(item.unitPrice, currency: receipt.currency))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(formatDecimal(item.lineTotal, currency: receipt.currency))
                        .font(.body)
                }
            }
        }
    }

    private var totalsSection: some View {
        Section {
            if let subtotal = receipt.subtotal {
                LabeledContent("Subtotal", value: formatDecimal(subtotal, currency: receipt.currency))
            }
            if let tax = receipt.tax {
                LabeledContent("Tax", value: formatDecimal(tax, currency: receipt.currency))
            }
            LabeledContent("Total", value: formatDecimal(receipt.total, currency: receipt.currency))
                .font(.headline)
        }
    }

    private var retrySection: some View {
        Section {
            Button("Retry Scan") {
                showingRetry = true
            }
            .frame(maxWidth: .infinity, alignment: .center)
        } footer: {
            Text("Try scanning the receipt again from a different angle for better results.")
        }
    }

    private func formatDecimal(_ value: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
