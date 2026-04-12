import SwiftUI
import PhotosUI
import SwiftData
import MLXLMCommon

struct ReceiptScanScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let modelContainer: MLXLMCommon.ModelContainer
    var existingReceiptId: UUID?

    @State private var pipeline: ReceiptPipeline?
    @State private var selectedItem: PhotosPickerItem?
    @State private var showPicker = true

    var body: some View {
        VStack(spacing: 24) {
            if let pipeline {
                processingView(pipeline: pipeline)
            }
        }
        .navigationTitle("Scan Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $showPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task { await handleImageSelection(item: item) }
        }
        .onChange(of: showPicker) { _, isPresented in
            if !isPresented && pipeline == nil {
                dismiss()
            }
        }
        .onAppear {
            pipeline = ReceiptPipeline(modelContainer: modelContainer, modelContext: modelContext)
        }
    }

    @ViewBuilder
    private func processingView(pipeline: ReceiptPipeline) -> some View {
        switch pipeline.processingState {
        case .idle:
            Text("Select a receipt photo to begin")
                .foregroundStyle(.secondary)

        case .extractingText:
            ProgressView("Extracting text...")

        case .parsingAttempt(let attempt):
            ProgressView("Parsing (\(attempt)/3)...")

        case .validating:
            ProgressView("Validating...")

        case .saving:
            ProgressView("Saving...")

        case .completed(let status):
            completedView(status: status)

        case .failed(let message):
            failedView(message: message)
        }
    }

    private func completedView(status: ReceiptStatus) -> some View {
        VStack(spacing: 16) {
            Image(systemName: status == .verified ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(status == .verified ? .green : .orange)

            Text(status == .verified ? "Receipt saved successfully!" : "Receipt saved for review")
                .font(.headline)

            if status == .pendingReview {
                Text("We couldn't quite catch it all. You can retry with another photo from a different angle.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Try Again") {
                    selectedItem = nil
                    showPicker = true
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Done") { dismiss() }
                .buttonStyle(.bordered)
        }
    }

    private func failedView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Extraction Failed")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                pipeline?.reset()
                selectedItem = nil
                showPicker = true
            }
            .buttonStyle(.borderedProminent)

            Button("Cancel") { dismiss() }
                .buttonStyle(.bordered)
        }
    }

    private func handleImageSelection(item: PhotosPickerItem) async {
        guard let pipeline else { return }
        selectedItem = nil

        let ocrText: String
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            ocrText = try await pipeline.extractText(from: image)
        } catch {
            return
        }

        if let existingId = existingReceiptId ?? pipeline.lastSavedReceiptId {
            await pipeline.retryWithText(ocrText: ocrText, existingReceiptId: existingId)
        } else {
            await pipeline.processWithText(ocrText: ocrText)
        }
    }
}
