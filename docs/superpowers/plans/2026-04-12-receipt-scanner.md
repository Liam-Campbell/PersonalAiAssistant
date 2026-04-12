# Receipt Scanner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the chat interface with a receipt scanning pipeline that uses Apple Vision OCR + on-device Gemma for structured data extraction, persisted to SwiftData with iCloud sync.

**Architecture:** Receipt Pipeline Coordinator pattern — `ReceiptPipeline` orchestrates OCR → triple-consensus LLM parsing → validation → SwiftData save. Model-agnostic design: `ModelLoader` loads any MLX model, `ReceiptParser` receives it as a dependency. Two SwiftData containers: iCloud-synced for receipt data, local-only for logs.

**Tech Stack:** Swift 5.9, SwiftUI, iOS 17+, Apple Vision (VNRecognizeTextRequest), MLX Swift (MLXLLM), SwiftData + CloudKit, XcodeGen

**Spec:** `docs/superpowers/specs/2026-04-12-receipt-scanner-design.md`

---

## Task 1: Delete Chat Feature

**Files:**
- Delete: `PersonalAiAssistant/Features/Chat/ChatModel.swift`
- Delete: `PersonalAiAssistant/Features/Chat/ChatScreen.swift`
- Modify: `PersonalAiAssistant/Navigation/MainTabView.swift`

- [ ] **Step 1: Delete Chat files**

Delete the entire `PersonalAiAssistant/Features/Chat/` directory and its contents:
- `PersonalAiAssistant/Features/Chat/ChatModel.swift`
- `PersonalAiAssistant/Features/Chat/ChatScreen.swift`

- [ ] **Step 2: Update MainTabView to show a placeholder**

Temporarily replace `ChatScreen()` with a `Text` placeholder so the app still compiles. Replace the full contents of `PersonalAiAssistant/Navigation/MainTabView.swift` with:

```swift
import SwiftUI

struct MainTabView: View {
    var downloadService: ModelDownloadService

    var body: some View {
        if downloadService.downloadState == .completed {
            Text("Receipt Scanner Coming Soon")
        } else {
            ModelDownloadScreen(downloadService: downloadService)
        }
    }
}
```

- [ ] **Step 3: Verify the project compiles**

Run: `cd /Users/LCampbel/source/repos/PersonalAiAssistant && xcodegen generate && xcodebuild -scheme PersonalAiAssistant -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: remove chat feature, prepare for receipt scanner"
```

---

## Task 2: Create SwiftData Models — Store & PaymentCard

**Files:**
- Create: `PersonalAiAssistant/Features/Storage/Models/Store.swift`
- Create: `PersonalAiAssistant/Features/Storage/Models/PaymentCard.swift`

- [ ] **Step 1: Create Store model**

Create `PersonalAiAssistant/Features/Storage/Models/Store.swift`:

```swift
import Foundation
import SwiftData

@Model final class Store {
    @Attribute(.unique) var id: UUID
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Receipt.store) var receipts: [Receipt]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.receipts = []
    }
}
```

- [ ] **Step 2: Create PaymentCard model**

Create `PersonalAiAssistant/Features/Storage/Models/PaymentCard.swift`:

```swift
import Foundation
import SwiftData

@Model final class PaymentCard {
    @Attribute(.unique) var id: UUID
    var label: String
    var lastFourDigits: String?
    @Relationship(deleteRule: .nullify, inverse: \Receipt.paymentCard) var receipts: [Receipt]

    init(label: String, lastFourDigits: String? = nil) {
        self.id = UUID()
        self.label = label
        self.lastFourDigits = lastFourDigits
        self.receipts = []
    }
}
```

Note: These reference `Receipt` which doesn't exist yet — they won't compile until Task 3 is done. This is intentional; they ship together.

---

## Task 3: Create SwiftData Models — Receipt, ReceiptItem, Enums

**Files:**
- Create: `PersonalAiAssistant/Features/Storage/Models/Receipt.swift`
- Create: `PersonalAiAssistant/Features/Storage/Models/ReceiptItem.swift`
- Create: `PersonalAiAssistant/Features/Storage/Models/ReceiptStatus.swift`
- Create: `PersonalAiAssistant/Features/Storage/Models/TransactionType.swift`

- [ ] **Step 1: Create ReceiptStatus enum**

Create `PersonalAiAssistant/Features/Storage/Models/ReceiptStatus.swift`:

```swift
import Foundation

enum ReceiptStatus: String, Codable {
    case verified
    case pendingReview
}
```

- [ ] **Step 2: Create TransactionType enum**

Create `PersonalAiAssistant/Features/Storage/Models/TransactionType.swift`:

```swift
import Foundation

enum TransactionType: String, Codable, CaseIterable {
    case contactless
    case chipAndPin
    case cash
    case online
    case other
}
```

- [ ] **Step 3: Create Receipt model**

Create `PersonalAiAssistant/Features/Storage/Models/Receipt.swift`:

```swift
import Foundation
import SwiftData

@Model final class Receipt {
    @Attribute(.unique) var id: UUID
    var store: Store
    var paymentCard: PaymentCard?
    var transactionTypeRaw: String
    var purchaseDate: Date
    var scannedDate: Date
    var subtotal: Decimal?
    var tax: Decimal?
    var total: Decimal
    var currency: String
    var rawOCRText: String
    var statusRaw: String
    @Relationship(deleteRule: .cascade, inverse: \ReceiptItem.receipt) var items: [ReceiptItem]

    var transactionType: TransactionType {
        get { TransactionType(rawValue: transactionTypeRaw) ?? .other }
        set { transactionTypeRaw = newValue.rawValue }
    }

    var status: ReceiptStatus {
        get { ReceiptStatus(rawValue: statusRaw) ?? .pendingReview }
        set { statusRaw = newValue.rawValue }
    }

    init(
        store: Store,
        paymentCard: PaymentCard? = nil,
        transactionType: TransactionType,
        purchaseDate: Date,
        subtotal: Decimal? = nil,
        tax: Decimal? = nil,
        total: Decimal,
        currency: String,
        rawOCRText: String,
        status: ReceiptStatus,
        items: [ReceiptItem] = []
    ) {
        self.id = UUID()
        self.store = store
        self.paymentCard = paymentCard
        self.transactionTypeRaw = transactionType.rawValue
        self.purchaseDate = purchaseDate
        self.scannedDate = Date()
        self.subtotal = subtotal
        self.tax = tax
        self.total = total
        self.currency = currency
        self.rawOCRText = rawOCRText
        self.statusRaw = status.rawValue
        self.items = items
    }
}
```

Note: Enums are stored as raw strings because SwiftData + CloudKit requires primitive-backed properties for reliable sync.

- [ ] **Step 4: Create ReceiptItem model**

Create `PersonalAiAssistant/Features/Storage/Models/ReceiptItem.swift`:

```swift
import Foundation
import SwiftData

@Model final class ReceiptItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Int
    var unitPrice: Decimal
    var lineTotal: Decimal
    var receipt: Receipt?

    init(name: String, quantity: Int = 1, unitPrice: Decimal, lineTotal: Decimal) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.lineTotal = lineTotal
    }
}
```

- [ ] **Step 5: Verify all models compile**

Run: `xcodegen generate && xcodebuild -scheme PersonalAiAssistant -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add SwiftData models — Store, PaymentCard, Receipt, ReceiptItem"
```

---

## Task 4: Create LogEntry Model & AppLogger

**Files:**
- Create: `PersonalAiAssistant/Features/Logging/LogEntry.swift`
- Create: `PersonalAiAssistant/Features/Logging/AppLogger.swift`

- [ ] **Step 1: Create LogEntry SwiftData model**

Create `PersonalAiAssistant/Features/Logging/LogEntry.swift`:

```swift
import Foundation
import SwiftData

enum LogLevel: String, Codable, CaseIterable {
    case debug
    case info
    case warning
    case error
}

@Model final class LogEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var levelRaw: String
    var source: String
    var message: String
    var detail: String?
    var relatedEntityId: UUID?

    var level: LogLevel {
        get { LogLevel(rawValue: levelRaw) ?? .info }
        set { levelRaw = newValue.rawValue }
    }

    init(level: LogLevel, source: String, message: String, detail: String? = nil, relatedEntityId: UUID? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.levelRaw = level.rawValue
        self.source = source
        self.message = message
        self.detail = detail
        self.relatedEntityId = relatedEntityId
    }
}
```

- [ ] **Step 2: Create AppLogger singleton**

Create `PersonalAiAssistant/Features/Logging/AppLogger.swift`:

```swift
import Foundation
import SwiftData

@Observable final class AppLogger {
    static let shared = AppLogger()

    private var container: ModelContainer?

    private init() {}

    func configure(container: ModelContainer) {
        self.container = container
    }

    @MainActor
    func log(_ level: LogLevel, source: String, message: String, detail: String? = nil, relatedEntityId: UUID? = nil) {
        guard let container else { return }
        let context = container.mainContext
        let entry = LogEntry(level: level, source: source, message: message, detail: detail, relatedEntityId: relatedEntityId)
        context.insert(entry)
        try? context.save()
    }

    @MainActor
    func pruneOldEntries(olderThan days: Int = 30) {
        guard let container else { return }
        let context = container.mainContext
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = #Predicate<LogEntry> { $0.timestamp < cutoff }
        let descriptor = FetchDescriptor<LogEntry>(predicate: predicate)
        guard let oldEntries = try? context.fetch(descriptor) else { return }
        for entry in oldEntries {
            context.delete(entry)
        }
        try? context.save()
    }
}
```

- [ ] **Step 3: Verify compilation**

Run: `xcodegen generate && xcodebuild -scheme PersonalAiAssistant -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add AppLogger with LogEntry SwiftData model (local-only store)"
```

---

## Task 5: Configure SwiftData Containers & iCloud Entitlements

**Files:**
- Modify: `PersonalAiAssistant/App/PersonalAiAssistantApp.swift`
- Modify: `PersonalAiAssistant/Resources/PersonalAiAssistant.entitlements`

- [ ] **Step 1: Update entitlements for iCloud + CloudKit**

Replace the full contents of `PersonalAiAssistant/Resources/PersonalAiAssistant.entitlements` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.personalai.assistant</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Update PersonalAiAssistantApp with two SwiftData containers**

Replace the full contents of `PersonalAiAssistant/App/PersonalAiAssistantApp.swift` with:

```swift
import SwiftUI
import SwiftData

final class AppDelegate: NSObject, UIApplicationDelegate {
    let downloadService = ModelDownloadService()

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        downloadService.setBackgroundCompletionHandler(completionHandler)
    }
}

@main
struct PersonalAiAssistantApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let syncedContainer: ModelContainer
    let logContainer: ModelContainer

    init() {
        let syncedConfig = ModelConfiguration(
            "ReceiptStore",
            schema: Schema([Receipt.self, ReceiptItem.self, Store.self, PaymentCard.self]),
            cloudKitDatabase: .automatic
        )
        let logConfig = ModelConfiguration(
            "LogStore",
            schema: Schema([LogEntry.self]),
            cloudKitDatabase: .none
        )

        do {
            syncedContainer = try ModelContainer(
                for: Receipt.self, ReceiptItem.self, Store.self, PaymentCard.self,
                configurations: syncedConfig
            )
            logContainer = try ModelContainer(
                for: LogEntry.self,
                configurations: logConfig
            )
        } catch {
            fatalError("Failed to create model containers: \(error)")
        }

        AppLogger.shared.configure(container: logContainer)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(downloadService: appDelegate.downloadService)
                .modelContainer(syncedContainer)
                .task {
                    await AppLogger.shared.pruneOldEntries()
                }
        }
    }
}
```

- [ ] **Step 3: Verify compilation**

Run: `xcodegen generate && xcodebuild -scheme PersonalAiAssistant -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: configure dual SwiftData containers — iCloud sync + local logs"
```

---

## Task 6: Create ModelLoader (extract from ChatModel)

**Files:**
- Create: `PersonalAiAssistant/App/ModelLoader.swift`

- [ ] **Step 1: Create ModelLoader**

Create `PersonalAiAssistant/App/ModelLoader.swift`:

```swift
import Foundation
import Observation
import MLXLLM
import MLXLMCommon

@Observable final class ModelLoader {
    private(set) var isLoading = true
    private(set) var loadError: String?
    private(set) var modelContainer: ModelContainer?

    func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            patchConfigIfNeeded()
            let container = try await loadModelContainer(
                directory: ModelDownloadService.modelDirectory
            )
            modelContainer = container
            await AppLogger.shared.log(.info, source: "ModelLoader", message: "Model loaded successfully")
        } catch {
            loadError = error.localizedDescription
            await AppLogger.shared.log(.error, source: "ModelLoader", message: "Failed to load model", detail: error.localizedDescription)
        }
    }

    func dismissLoadError() {
        loadError = nil
    }

    private func patchConfigIfNeeded() {
        let configURL = ModelDownloadService.modelDirectory.appendingPathComponent("config.json")
        guard let data = try? Data(contentsOf: configURL),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var textConfig = json["text_config"] as? [String: Any] else { return }

        let requiredFields: [String: Int] = [
            "num_attention_heads": 8,
            "num_key_value_heads": 4,
            "head_dim": 256
        ]

        var patched = false
        for (key, value) in requiredFields {
            let existingValue = (textConfig[key] as? NSNumber)?.intValue
            if existingValue != value {
                textConfig[key] = value
                patched = true
            }
        }

        guard patched else { return }
        json["text_config"] = textConfig
        if let updatedData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? updatedData.write(to: configURL)
        }
    }
}
```

Note: `ModelContainer` here refers to `MLXLMCommon.ModelContainer` (the MLX type), not `SwiftData.ModelContainer`. The `loadModelContainer` function is from the MLXLLM package.

- [ ] **Step 2: Verify compilation**

Run: `xcodegen generate && xcodebuild -scheme PersonalAiAssistant -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add ModelLoader — model-agnostic loading with config patching"
```

---

## Task 7: Create OCRService

**Files:**
- Create: `PersonalAiAssistant/Features/ReceiptScanner/OCRService.swift`

- [ ] **Step 1: Create OCRService**

Create `PersonalAiAssistant/Features/ReceiptScanner/OCRService.swift`:

```swift
import UIKit
import Vision

enum OCRServiceError: Error {
    case noTextFound
    case recognitionFailed(String)
}

struct OCRService {
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRServiceError.recognitionFailed("Failed to get CGImage from UIImage")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: OCRServiceError.recognitionFailed(error.localizedDescription))
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRServiceError.noTextFound)
                    return
                }
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                if text.isEmpty {
                    continuation.resume(throwing: OCRServiceError.noTextFound)
                } else {
                    continuation.resume(returning: text)
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRServiceError.recognitionFailed(error.localizedDescription))
            }
        }
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `xcodegen generate && xcodebuild -scheme PersonalAiAssistant -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add OCRService — Apple Vision text extraction"
```

---

## Task 8: Create ReceiptParser (LLM structured extraction)

**Files:**
- Create: `PersonalAiAssistant/Features/ReceiptScanner/ReceiptParser.swift`

- [ ] **Step 1: Create ParsedReceipt intermediate type and ReceiptParser**

Create `PersonalAiAssistant/Features/ReceiptScanner/ReceiptParser.swift`:

```swift
import Foundation
import MLXLLM
import MLXLMCommon

struct ParsedReceipt: Codable, Equatable {
    var storeName: String
    var purchaseDate: String
    var subtotal: Double?
    var tax: Double?
    var total: Double
    var currency: String
    var transactionType: String
    var cardLastFour: String?
    var items: [ParsedItem]

    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case purchaseDate = "purchase_date"
        case subtotal, tax, total, currency
        case transactionType = "transaction_type"
        case cardLastFour = "card_last_four"
        case items
    }
}

struct ParsedItem: Codable, Equatable {
    var name: String
    var quantity: Int
    var unitPrice: Double
    var lineTotal: Double

    enum CodingKeys: String, CodingKey {
        case name, quantity
        case unitPrice = "unit_price"
        case lineTotal = "line_total"
    }
}

enum ReceiptParserError: Error {
    case modelNotAvailable
    case jsonExtractionFailed
    case jsonDecodingFailed(String)
    case consensusNotReached
}

struct ReceiptParser {
    private let promptTemplate = """
    You are a receipt parser. Extract structured data from this receipt text.
    Return ONLY valid JSON with this exact structure, no other text:
    {
      "store_name": "...",
      "purchase_date": "YYYY-MM-DD",
      "subtotal": 0.00,
      "tax": 0.00,
      "total": 0.00,
      "currency": "GBP",
      "transaction_type": "contactless|chip_and_pin|cash|online|other",
      "card_last_four": "1234",
      "items": [
        {"name": "...", "quantity": 1, "unit_price": 0.00, "line_total": 0.00}
      ]
    }

    Receipt text:
    """

    func parseWithConsensus(ocrText: String, modelContainer: MLXLMCommon.ModelContainer) async throws -> ParsedReceipt {
        let prompt = promptTemplate + ocrText
        var results: [ParsedReceipt] = []
        var rawOutputs: [String] = []

        for attempt in 1...3 {
            let rawOutput = try await runModel(prompt: prompt, modelContainer: modelContainer)
            rawOutputs.append(rawOutput)

            await AppLogger.shared.log(
                .debug,
                source: "ReceiptParser",
                message: "Model attempt \(attempt) of 3",
                detail: rawOutput
            )

            let parsed = try decodeReceipt(from: rawOutput)
            results.append(parsed)
        }

        let allMatch = results.dropFirst().allSatisfy { $0 == results[0] }
        if !allMatch {
            await AppLogger.shared.log(
                .warning,
                source: "ReceiptParser",
                message: "Consensus not reached — 3 attempts produced different results",
                detail: rawOutputs.joined(separator: "\n---\n")
            )
            throw ReceiptParserError.consensusNotReached
        }

        await AppLogger.shared.log(.info, source: "ReceiptParser", message: "Consensus reached on all 3 attempts")
        return results[0]
    }

    private func runModel(prompt: String, modelContainer: MLXLMCommon.ModelContainer) async throws -> String {
        let session = ChatSession(modelContainer)
        var fullResponse = ""
        let stream = session.streamResponse(to: prompt)
        for try await chunk in stream {
            fullResponse += chunk
        }
        return fullResponse
    }

    private func decodeReceipt(from rawOutput: String) throws -> ParsedReceipt {
        let jsonString = extractJSON(from: rawOutput)
        guard let data = jsonString.data(using: .utf8) else {
            throw ReceiptParserError.jsonExtractionFailed
        }
        do {
            return try JSONDecoder().decode(ParsedReceipt.self, from: data)
        } catch {
            throw ReceiptParserError.jsonDecodingFailed(error.localizedDescription)
        }
    }

    private func extractJSON(from text: String) -> String {
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        return text
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `xcodegen generate && xcodebuild -scheme PersonalAiAssistant -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add ReceiptParser — triple-consensus LLM extraction with JSON parsing"
```

---

## Task 9: Create ReceiptPipeline Coordinator

**Files:**
- Create: `PersonalAiAssistant/Features/ReceiptScanner/ReceiptPipeline.swift`

- [ ] **Step 1: Create ReceiptPipeline**

Create `PersonalAiAssistant/Features/ReceiptScanner/ReceiptPipeline.swift`:

```swift
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
    private let modelContext: ModelContext

    init(modelContainer: MLXLMCommon.ModelContainer, modelContext: ModelContext) {
        self.modelContainer = modelContainer
        self.modelContext = modelContext
    }

    @MainActor
    func process(image: UIImage) async {
        processingState = .extractingText
        await AppLogger.shared.log(.info, source: "ReceiptPipeline", message: "Starting receipt extraction")

        do {
            let ocrText = try await ocrService.extractText(from: image)
            await AppLogger.shared.log(.info, source: "ReceiptPipeline", message: "OCR extracted \(ocrText.count) characters")

            processingState = .parsingAttempt(1)
            let parsed = try await parser.parseWithConsensus(ocrText: ocrText, modelContainer: modelContainer)

            processingState = .validating
            let status = validate(parsed: parsed)

            processingState = .saving
            let receipt = try save(parsed: parsed, ocrText: ocrText, status: status)
            lastSavedReceiptId = receipt.id

            await AppLogger.shared.log(.info, source: "ReceiptPipeline", message: "Receipt saved", relatedEntityId: receipt.id)
            processingState = .completed(status)
        } catch let error as ReceiptParserError where error == .consensusNotReached {
            await handleConsensusFailure(error: error)
        } catch {
            await AppLogger.shared.log(.error, source: "ReceiptPipeline", message: "Pipeline failed", detail: error.localizedDescription)
            processingState = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func retry(image: UIImage, existingReceiptId: UUID) async {
        processingState = .extractingText
        await AppLogger.shared.log(.info, source: "ReceiptPipeline", message: "Retrying extraction for receipt", relatedEntityId: existingReceiptId)

        do {
            let ocrText = try await ocrService.extractText(from: image)

            processingState = .parsingAttempt(1)
            let parsed = try await parser.parseWithConsensus(ocrText: ocrText, modelContainer: modelContainer)

            processingState = .validating
            let status = validate(parsed: parsed)

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

    private func validate(parsed: ParsedReceipt) -> ReceiptStatus {
        let itemsTotal = parsed.items.reduce(0.0) { $0 + $1.lineTotal }
        let match = itemsTotal == parsed.total
        let status: ReceiptStatus = match ? .verified : .pendingReview
        Task { @MainActor in
            if match {
                await AppLogger.shared.log(.info, source: "ReceiptPipeline", message: "Validation passed — totals match exactly")
            } else {
                await AppLogger.shared.log(.warning, source: "ReceiptPipeline", message: "Validation failed — items sum \(itemsTotal) vs total \(parsed.total)")
            }
        }
        return status
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

    @MainActor
    private func handleConsensusFailure(error: Error) async {
        await AppLogger.shared.log(.warning, source: "ReceiptPipeline", message: "Pipeline completed with pending review — consensus not reached")
        processingState = .failed("Could not get consistent results. Please try again with a clearer photo.")
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `xcodegen generate && xcodebuild -scheme PersonalAiAssistant -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add ReceiptPipeline — coordinator for OCR → parse → validate → save"
```

---

## Task 10: Create ReceiptScanScreen (image picker + pipeline progress)

**Files:**
- Create: `PersonalAiAssistant/Features/ReceiptScanner/ReceiptScanScreen.swift`

- [ ] **Step 1: Create ReceiptScanScreen**

Create `PersonalAiAssistant/Features/ReceiptScanner/ReceiptScanScreen.swift`:

```swift
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
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }
        if let existingId = existingReceiptId {
            await pipeline?.retry(image: image, existingReceiptId: existingId)
        } else {
            await pipeline?.process(image: image)
        }
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `xcodegen generate && xcodebuild -scheme PersonalAiAssistant -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add ReceiptScanScreen — image picker + pipeline progress UI"
```

---

## Task 11: Create ReceiptListScreen

**Files:**
- Create: `PersonalAiAssistant/Features/ReceiptScanner/ReceiptListScreen.swift`

- [ ] **Step 1: Create ReceiptListScreen**

Create `PersonalAiAssistant/Features/ReceiptScanner/ReceiptListScreen.swift`:

```swift
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
```

- [ ] **Step 2: Verify compilation**

Run: `xcodegen generate && xcodebuild -scheme PersonalAiAssistant -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add ReceiptListScreen — main screen with receipt list and status badges"
```

---

## Task 12: Create ReceiptDetailScreen

**Files:**
- Create: `PersonalAiAssistant/Features/ReceiptScanner/ReceiptDetailScreen.swift`

- [ ] **Step 1: Create ReceiptDetailScreen**

Create `PersonalAiAssistant/Features/ReceiptScanner/ReceiptDetailScreen.swift`:

```swift
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
```

- [ ] **Step 2: Verify compilation**

Run: `xcodegen generate && xcodebuild -scheme PersonalAiAssistant -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add ReceiptDetailScreen — view receipt header, items, totals, retry"
```

---

## Task 13: Create LogViewerScreen

**Files:**
- Create: `PersonalAiAssistant/Features/Logging/LogViewerScreen.swift`

- [ ] **Step 1: Create LogViewerScreen**

Create `PersonalAiAssistant/Features/Logging/LogViewerScreen.swift`:

```swift
import SwiftUI
import SwiftData

struct LogViewerScreen: View {
    @State private var selectedLevels: Set<LogLevel> = Set(LogLevel.allCases)
    @State private var searchText = ""
    @State private var logEntries: [LogEntry] = []
    @State private var expandedEntryId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            logList
        }
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search logs...")
        .onAppear { fetchLogs() }
        .onChange(of: selectedLevels) { _, _ in fetchLogs() }
        .onChange(of: searchText) { _, _ in fetchLogs() }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    FilterPill(
                        title: level.rawValue.capitalized,
                        color: colorForLevel(level),
                        isSelected: selectedLevels.contains(level)
                    ) {
                        if selectedLevels.contains(level) {
                            selectedLevels.remove(level)
                        } else {
                            selectedLevels.insert(level)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var logList: some View {
        List(logEntries) { entry in
            LogEntryRow(entry: entry, isExpanded: expandedEntryId == entry.id) {
                withAnimation {
                    expandedEntryId = expandedEntryId == entry.id ? nil : entry.id
                }
            }
        }
        .listStyle(.plain)
    }

    private func fetchLogs() {
        guard let container = AppLogger.shared.logContainer else { return }
        let context = ModelContext(container)
        let levelRaws = selectedLevels.map { $0.rawValue }
        var descriptor = FetchDescriptor<LogEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        logEntries = entries.filter { entry in
            let levelMatch = levelRaws.contains(entry.levelRaw)
            let searchMatch = searchText.isEmpty
                || entry.source.localizedCaseInsensitiveContains(searchText)
                || entry.message.localizedCaseInsensitiveContains(searchText)
            return levelMatch && searchMatch
        }
    }

    private func colorForLevel(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

private struct FilterPill: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.2) : Color(.systemGray6))
                .foregroundStyle(isSelected ? color : .secondary)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? color : .clear, lineWidth: 1))
        }
    }
}

private struct LogEntryRow: View {
    let entry: LogEntry
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(colorForEntry)
                        .frame(width: 8, height: 8)
                    Text(entry.source)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(entry.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(entry.message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(isExpanded ? nil : 2)

                if isExpanded, let detail = entry.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var colorForEntry: Color {
        switch entry.level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}
```

- [ ] **Step 2: Expose logContainer on AppLogger**

The `LogViewerScreen` needs access to the log container to fetch entries. Add a public computed property to `AppLogger`. In `PersonalAiAssistant/Features/Logging/AppLogger.swift`, change:

```swift
private var container: ModelContainer?
```

to:

```swift
private(set) var container: ModelContainer?

var logContainer: ModelContainer? { container }
```

- [ ] **Step 3: Verify compilation**

Run: `xcodegen generate && xcodebuild -scheme PersonalAiAssistant -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add LogViewerScreen — filterable log browser with level pills and detail expansion"
```

---

## Task 14: Create SettingsScreen

**Files:**
- Create: `PersonalAiAssistant/Features/Settings/SettingsScreen.swift`

- [ ] **Step 1: Create SettingsScreen**

Create `PersonalAiAssistant/Features/Settings/SettingsScreen.swift`:

```swift
import SwiftUI

struct SettingsScreen: View {
    @State private var showingLogs = false

    var body: some View {
        List {
            Section {
                NavigationLink("View Logs", destination: LogViewerScreen())
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `xcodegen generate && xcodebuild -scheme PersonalAiAssistant -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add SettingsScreen with View Logs link"
```

---

## Task 15: Wire Everything Together — MainTabView & ModelLoader Integration

**Files:**
- Modify: `PersonalAiAssistant/Navigation/MainTabView.swift`
- Modify: `PersonalAiAssistant/App/PersonalAiAssistantApp.swift`

- [ ] **Step 1: Update MainTabView to load model and show ReceiptListScreen**

Replace the full contents of `PersonalAiAssistant/Navigation/MainTabView.swift` with:

```swift
import SwiftUI

struct MainTabView: View {
    var downloadService: ModelDownloadService
    @State private var modelLoader = ModelLoader()

    var body: some View {
        if downloadService.downloadState == .completed {
            if modelLoader.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading model…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await modelLoader.load() }
                .alert(
                    "Failed to Load Model",
                    isPresented: Binding(
                        get: { modelLoader.loadError != nil },
                        set: { if !$0 { modelLoader.dismissLoadError() } }
                    )
                ) {
                    Button("Retry") { Task { await modelLoader.load() } }
                    Button("OK", role: .cancel) { modelLoader.dismissLoadError() }
                } message: {
                    Text(modelLoader.loadError ?? "")
                }
            } else if let container = modelLoader.modelContainer {
                ReceiptListScreen(modelContainer: container)
            }
        } else {
            ModelDownloadScreen(downloadService: downloadService)
        }
    }
}
```

- [ ] **Step 2: Verify full app compilation**

Run: `xcodegen generate && xcodebuild -scheme PersonalAiAssistant -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: wire MainTabView to ModelLoader + ReceiptListScreen — full flow connected"
```

---

## Task 16: Update copilot-instructions.md

**Files:**
- Modify: `.github/copilot-instructions.md`

- [ ] **Step 1: Update the instructions file to reflect the new architecture**

Key updates needed:
- Project Overview: change from "AI chat experience" to "receipt scanning tool"
- Architecture tree: update to show new feature structure (ReceiptScanner, Logging, Settings, Storage/Models)
- Remove Chat references
- Add ReceiptScanner pipeline description
- Add SwiftData Models section listing the 4 models + LogEntry
- Add iCloud sync notes
- Update Pitfalls & Gotchas with new gotchas (dual SwiftData containers, Decimal for money, etc.)
- Update Navigation section — MainTabView now switches between download and receipt list

- [ ] **Step 2: Verify no broken references**

Read through the updated file and confirm all file paths and type names match the actual codebase.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "docs: update copilot-instructions.md for receipt scanner architecture"
```
