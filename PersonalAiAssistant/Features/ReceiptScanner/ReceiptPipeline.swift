import Foundation
import UIKit
import Observation
import SwiftData
import MLXLMCommon

enum ProcessingState: Equatable {
    case idle
    case extractingText
    case parsingAttempt(Int)
    case validating
    case saving
    case completed(ReceiptStatus)
    case failed(String)

    static func == (lhs: ProcessingState, rhs: ProcessingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.extractingText, .extractingText),
             (.validating, .validating), (.saving, .saving):
            return true
        case (.parsingAttempt(let a), .parsingAttempt(let b)):
            return a == b
        case (.completed(let a), .completed(let b)):
            return a == b
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

@Observable final class ReceiptPipeline {
    private(set) var processingState: ProcessingState = .idle
    private(set) var lastSavedReceiptId: UUID?

    private let ocrService = OCRService()
    private let parser = ReceiptParser()
    private let modelContainer: MLXLMCommon.ModelContainer
    private let modelContext: SwiftData.ModelContext

    init(modelContainer: MLXLMCommon.ModelContainer, modelContext: SwiftData.ModelContext) {
        self.modelContainer = modelContainer
        self.modelContext = modelContext
    }

    @MainActor
    func extractText(from image: UIImage) async throws -> String {
        processingState = .extractingText
        await AppLogger.shared.log(.info, source: "ReceiptPipeline", message: "Starting receipt extraction")
        do {
            let downsized = downsizeForOCR(image)
            let ocrText = try await ocrService.extractText(from: downsized)
            await AppLogger.shared.log(.info, source: "ReceiptPipeline", message: "OCR extracted \(ocrText.count) characters")
            return ocrText
        } catch {
            await AppLogger.shared.log(.error, source: "ReceiptPipeline", message: "OCR failed", detail: error.localizedDescription)
            processingState = .failed(error.localizedDescription)
            throw error
        }
    }

    @MainActor
    func processWithText(ocrText: String) async {
        do {
            await AppLogger.shared.log(.info, source: "ReceiptPipeline", message: "Starting LLM parsing (3 consensus attempts)")
            await AppLogger.shared.flush()

            let (parsed, consensusReached) = try await parseWithConsensus(ocrText: ocrText)

            processingState = .validating
            let totalsMatch = validateTotals(parsed: parsed)
            let status: ReceiptStatus = (consensusReached && totalsMatch) ? .verified : .pendingReview

            processingState = .saving
            let receipt = try save(parsed: parsed, ocrText: ocrText, status: status)
            lastSavedReceiptId = receipt.id

            await AppLogger.shared.log(.info, source: "ReceiptPipeline", message: "Receipt saved with status: \(status.rawValue)", relatedEntityId: receipt.id)
            processingState = .completed(status)
        } catch {
            await AppLogger.shared.log(.error, source: "ReceiptPipeline", message: "Pipeline failed", detail: error.localizedDescription)
            processingState = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func retryWithText(ocrText: String, existingReceiptId: UUID) async {
        do {
            await AppLogger.shared.log(.info, source: "ReceiptPipeline", message: "Starting LLM parsing (3 consensus attempts)")
            await AppLogger.shared.flush()

            let (parsed, consensusReached) = try await parseWithConsensus(ocrText: ocrText)

            processingState = .validating
            let totalsMatch = validateTotals(parsed: parsed)
            let status: ReceiptStatus = (consensusReached && totalsMatch) ? .verified : .pendingReview

            processingState = .saving
            try updateExistingReceipt(id: existingReceiptId, parsed: parsed, ocrText: ocrText, status: status)
            lastSavedReceiptId = existingReceiptId

            await AppLogger.shared.log(.info, source: "ReceiptPipeline", message: "Receipt updated after retry", relatedEntityId: existingReceiptId)
            processingState = .completed(status)
        } catch {
            await AppLogger.shared.log(.error, source: "ReceiptPipeline", message: "Retry failed", detail: error.localizedDescription, relatedEntityId: existingReceiptId)
            processingState = .failed(error.localizedDescription)
        }
    }

    func reset() {
        processingState = .idle
        lastSavedReceiptId = nil
    }

    @MainActor
    private func parseWithConsensus(ocrText: String) async throws -> (ParsedReceipt, Bool) {
        var results: [ParsedReceipt] = []
        var rawOutputs: [String] = []

        for attempt in 1...3 {
            processingState = .parsingAttempt(attempt)
            await AppLogger.shared.log(.debug, source: "ReceiptPipeline", message: "Starting model inference attempt \(attempt) of 3")
            await AppLogger.shared.flush()

            let (parsed, rawOutput) = try await parser.parseSingleAttempt(ocrText: ocrText, modelContainer: modelContainer)
            results.append(parsed)
            rawOutputs.append(rawOutput)

            await AppLogger.shared.log(
                .debug,
                source: "ReceiptPipeline",
                message: "Model attempt \(attempt) of 3 completed",
                detail: rawOutput
            )
        }

        let allMatch = results.dropFirst().allSatisfy { $0 == results[0] }
        if allMatch {
            await AppLogger.shared.log(.info, source: "ReceiptPipeline", message: "Consensus reached on all 3 attempts")
        } else {
            await AppLogger.shared.log(
                .warning,
                source: "ReceiptPipeline",
                message: "Consensus not reached — 3 attempts produced different results",
                detail: rawOutputs.joined(separator: "\n---\n")
            )
        }
        return (results[0], allMatch)
    }

    private func validateTotals(parsed: ParsedReceipt) -> Bool {
        let decimalItemsTotal = parsed.items.reduce(Decimal.zero) { sum, item in
            sum + (Decimal(string: String(item.lineTotal)) ?? Decimal(item.lineTotal))
        }
        let decimalTotal = Decimal(string: String(parsed.total)) ?? Decimal(parsed.total)
        let match = decimalItemsTotal == decimalTotal
        Task { @MainActor in
            if match {
                await AppLogger.shared.log(.info, source: "ReceiptPipeline", message: "Validation passed — totals match exactly")
            } else {
                await AppLogger.shared.log(.warning, source: "ReceiptPipeline", message: "Validation failed — items sum \(decimalItemsTotal) vs total \(decimalTotal)")
            }
        }
        return match
    }

    @MainActor
    private func save(parsed: ParsedReceipt, ocrText: String, status: ReceiptStatus) throws -> Receipt {
        let store = findOrCreateStore(name: parsed.storeName)
        let card = findPaymentCard(lastFour: parsed.cardLastFour)

        let receipt = Receipt(
            store: store,
            paymentCard: card,
            transactionType: TransactionType(rawValue: parsed.transactionType) ?? .other,
            purchaseDate: parseDate(parsed.purchaseDate),
            subtotal: parsed.subtotal.map { Decimal($0) },
            tax: parsed.tax.map { Decimal($0) },
            total: Decimal(parsed.total),
            currency: parsed.currency,
            rawOCRText: ocrText,
            status: status
        )

        modelContext.insert(receipt)

        for parsedItem in parsed.items {
            let item = ReceiptItem(
                name: parsedItem.name,
                quantity: parsedItem.quantity,
                unitPrice: Decimal(parsedItem.unitPrice),
                lineTotal: Decimal(parsedItem.lineTotal)
            )
            item.receipt = receipt
            modelContext.insert(item)
        }

        try modelContext.save()
        return receipt
    }

    @MainActor
    private func updateExistingReceipt(id: UUID, parsed: ParsedReceipt, ocrText: String, status: ReceiptStatus) throws {
        let predicate = #Predicate<Receipt> { $0.id == id }
        let descriptor = FetchDescriptor<Receipt>(predicate: predicate)
        guard let receipt = try modelContext.fetch(descriptor).first else { return }

        let store = findOrCreateStore(name: parsed.storeName)
        receipt.store = store
        receipt.paymentCard = findPaymentCard(lastFour: parsed.cardLastFour)
        receipt.transactionType = TransactionType(rawValue: parsed.transactionType) ?? .other
        receipt.purchaseDate = parseDate(parsed.purchaseDate)
        receipt.subtotal = parsed.subtotal.map { Decimal($0) }
        receipt.tax = parsed.tax.map { Decimal($0) }
        receipt.total = Decimal(parsed.total)
        receipt.currency = parsed.currency
        receipt.rawOCRText = ocrText
        receipt.status = status

        for item in receipt.items {
            modelContext.delete(item)
        }

        for parsedItem in parsed.items {
            let item = ReceiptItem(
                name: parsedItem.name,
                quantity: parsedItem.quantity,
                unitPrice: Decimal(parsedItem.unitPrice),
                lineTotal: Decimal(parsedItem.lineTotal)
            )
            item.receipt = receipt
            modelContext.insert(item)
        }

        try modelContext.save()
    }

    @MainActor
    private func findOrCreateStore(name: String) -> Store {
        let predicate = #Predicate<Store> { $0.name == name }
        let descriptor = FetchDescriptor<Store>(predicate: predicate)
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let store = Store(name: name)
        modelContext.insert(store)
        return store
    }

    @MainActor
    private func findPaymentCard(lastFour: String?) -> PaymentCard? {
        guard let lastFour, !lastFour.isEmpty else { return nil }
        let predicate = #Predicate<PaymentCard> { $0.lastFourDigits == lastFour }
        let descriptor = FetchDescriptor<PaymentCard>(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }

    private func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString) ?? Date()
    }

    private func downsizeForOCR(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 2048
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
