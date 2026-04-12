# Receipt Scanner — Design Spec

**Date:** 2026-04-12
**Status:** Approved (pending final review)

## Overview

Transform the PersonalAiAssistant iOS app from a chat interface into a receipt scanning tool. Users photograph shop receipts, the app extracts text via Apple Vision OCR, passes it through the on-device Gemma model for structured data extraction with triple-consensus validation, and persists the results to SwiftData with iCloud sync. The chat interface is removed entirely.

## Goals

- Scan a receipt photo and extract structured data (store, items, prices, totals, payment info) entirely on-device
- Triple-consensus model extraction with total validation for high-confidence results
- Persist receipt data to SwiftData with iCloud sync across devices
- App-wide logging system with an in-app log viewer
- Model-agnostic design — swapping Gemma 3 for Gemma 4 or another model is a config change, not an architecture change

## Non-Goals (v1)

- Live camera viewfinder with receipt framing guide (future)
- Setting to keep/discard receipt photos (future — v1 always discards)
- Editable extraction review/correction page (future)
- Product catalog normalization for cross-store comparison (future)
- Insights dashboards — price comparisons, purchase frequency, price fluctuations (future, enabled by the data model)

---

## 1. Feature Structure

Follows the existing vertical slice architecture:

```
PersonalAiAssistant/
├── App/
│   ├── PersonalAiAssistantApp.swift   # Updated — two SwiftData containers
│   ├── AppDelegate.swift              # Unchanged
│   └── ModelLoader.swift              # NEW — model-agnostic model loading
├── Features/
│   ├── Chat/                          # REMOVED
│   ├── ModelManager/                  # Unchanged
│   ├── ReceiptScanner/                # NEW
│   │   ├── ReceiptScanScreen.swift
│   │   ├── ReceiptListScreen.swift
│   │   ├── ReceiptDetailScreen.swift
│   │   ├── ReceiptPipeline.swift
│   │   ├── OCRService.swift
│   │   └── ReceiptParser.swift
│   ├── Logging/                       # NEW
│   │   ├── AppLogger.swift
│   │   ├── LogEntry.swift
│   │   └── LogViewerScreen.swift
│   ├── Settings/                      # NEW
│   │   └── SettingsScreen.swift
│   ├── PhotoCapture/                  # Placeholder (future live camera)
│   └── Storage/
│       └── Models/
│           ├── Receipt.swift
│           ├── ReceiptItem.swift
│           ├── Store.swift
│           └── PaymentCard.swift
├── Navigation/
│   └── MainTabView.swift              # Updated — gates to ReceiptListScreen
├── Resources/                         # Updated — iCloud entitlements
└── Shared/
```

---

## 2. SwiftData Models

### Store

| Property | Type | Purpose |
|----------|------|---------|
| `id` | `UUID` | Primary key |
| `name` | `String` | Store name (extracted, user-editable) |
| `receipts` | `[Receipt]` | Inverse relationship |

When extracting a store name, check if a `Store` with that name already exists — link to it if so, create one if not. Exact string match for v1.

### PaymentCard

| Property | Type | Purpose |
|----------|------|---------|
| `id` | `UUID` | Primary key |
| `label` | `String` | User-chosen name, e.g. "Amex Gold", "Monzo" |
| `lastFourDigits` | `String?` | Optional — for auto-matching from receipt text |
| `receipts` | `[Receipt]` | Inverse relationship |

User-managed. For v1, the user picks the card manually. If the receipt prints last 4 digits and a matching card exists, auto-select it.

### Receipt

| Property | Type | Purpose |
|----------|------|---------|
| `id` | `UUID` | Primary key |
| `store` | `Store` | Relationship |
| `paymentCard` | `PaymentCard?` | Relationship — optional (cash has no card) |
| `transactionType` | `TransactionType` | How it was paid |
| `purchaseDate` | `Date` | Date on the receipt |
| `scannedDate` | `Date` | When the user scanned it |
| `subtotal` | `Decimal?` | Before tax |
| `tax` | `Decimal?` | Tax amount |
| `total` | `Decimal` | Receipt total |
| `currency` | `String` | Currency code, e.g. "GBP" — default from locale |
| `rawOCRText` | `String` | Full Vision-extracted text |
| `status` | `ReceiptStatus` | `.verified` / `.pendingReview` |
| `items` | `[ReceiptItem]` | Line items |

### ReceiptItem

| Property | Type | Purpose |
|----------|------|---------|
| `id` | `UUID` | Primary key |
| `name` | `String` | Product name as extracted |
| `quantity` | `Int` | Defaults to 1 |
| `unitPrice` | `Decimal` | Price per unit |
| `lineTotal` | `Decimal` | quantity × unitPrice |
| `receipt` | `Receipt` | Inverse relationship |

### TransactionType (enum, raw String for SwiftData)

- `.contactless`
- `.chipAndPin`
- `.cash`
- `.online`
- `.other`

Note: SwiftData requires raw-value enums for persistence. `.other` is a plain case (no associated value). If the receipt text contains a non-standard payment method, it maps to `.other` and the original text is preserved in `rawOCRText`.

### ReceiptStatus (enum)

- `.verified` — triple consensus + totals matched exactly
- `.pendingReview` — consensus failed or totals mismatched

### Design Notes

- `Decimal` for all money values — never `Double`
- `rawOCRText` kept even though photo is discarded — tiny storage, invaluable for debugging or re-processing
- `currency` is a string code — simple and sufficient

---

## 3. Receipt Pipeline

### Architecture

`ReceiptPipeline` is an `@Observable` class that coordinates the full flow. The view calls `pipeline.process(image:)` and reacts to state changes.

### Pipeline Steps

**Step 1 — OCR (`OCRService`)**
- Takes a `UIImage`
- Runs `VNRecognizeTextRequest` with `.accurate` recognition level, `.revision3`
- Returns the full recognized text as a single `String`

**Step 2 — Triple Consensus Parse (`ReceiptParser`)**
- Runs the same structured prompt 3 times against the loaded model
- Each run produces a `ParsedReceipt` intermediate struct
- All 3 raw model outputs (JSON strings) are logged via `AppLogger` at `.debug` level
- Consensus check: all 3 parsed results must be identical (same store, items, prices, totals)
- If any of the 3 differ → `status = .pendingReview` immediately

**Prompt template:**
```
You are a receipt parser. Extract structured data from this receipt text.
Return ONLY valid JSON with this exact structure:
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
<raw OCR text here>
```

**Step 3 — Validate**
- Sum all `item.line_total` values
- Compare against extracted `total`
- Exact match (±0.00 tolerance): `status = .verified`
- Any mismatch: `status = .pendingReview`

**Step 4 — Save**
- Look up or create `Store` by name
- Optionally match `PaymentCard` by last four digits
- Create `Receipt` and `ReceiptItem` SwiftData objects
- Save to model context

### Retry Flow

When status is `.pendingReview` and user provides a second photo:
1. OCR runs on the new image
2. Triple consensus runs with the new OCR text + context of the original text for comparison
3. Validate again
4. If verified → **update the existing Receipt row** — overwrite extracted data, change status to `.verified`
5. If still fails → keep as `.pendingReview`
6. All retry attempts logged via `AppLogger`

### Pipeline State

```swift
enum ProcessingState {
    case idle
    case extractingText
    case parsingAttempt(Int) // 1, 2, or 3
    case validating
    case saving
    case completed(Receipt)
    case failed(Error)
}
```

### Intermediate Type

`ParsedReceipt` is a plain struct (Codable, Equatable) used between parsing and saving. Not a SwiftData model. Decoded from the model's JSON output.

---

## 4. App Logging System

### AppLogger

Singleton service. All features log through `AppLogger.shared`.

```swift
AppLogger.shared.log(.info, source: "ReceiptPipeline", message: "Starting extraction run 1")
AppLogger.shared.log(.debug, source: "ReceiptParser", message: "Model attempt 1 of 3", detail: rawJSONOutput)
AppLogger.shared.log(.warning, source: "ReceiptPipeline", message: "Consensus not reached", relatedEntityId: receipt.id)
AppLogger.shared.log(.error, source: "OCRService", message: "Vision request failed", detail: error.localizedDescription)
```

### LogEntry (SwiftData @Model)

| Property | Type | Purpose |
|----------|------|---------|
| `id` | `UUID` | Primary key |
| `timestamp` | `Date` | When the event occurred |
| `level` | `LogLevel` | Severity |
| `source` | `String` | Feature/service name |
| `message` | `String` | Human-readable description |
| `detail` | `String?` | Optional payload — raw model output, OCR text, error info |
| `relatedEntityId` | `UUID?` | Links to a receipt, store, etc. |

### LogLevel (enum)

- `.debug` — granular diagnostics
- `.info` — normal operations
- `.warning` — non-fatal issues
- `.error` — failures

### LogViewerScreen

- List of log entries, newest first
- Filter bar with toggleable level pills: Debug / Info / Warning / Error
- Search by source or message text
- Tap to expand — shows full `detail` payload
- Color coded: debug=gray, info=blue, warning=orange, error=red

### Storage

- Separate `ModelConfiguration` with `cloudKitDatabase: .none` — local only
- Auto-prune: entries older than 30 days deleted on app launch

---

## 5. UI Screens & User Flow

### Screens

1. **Model Download Screen** (existing) — gates everything
2. **Receipt List Screen** — main screen, shows all receipts
3. **Receipt Scan Screen** — image picker + pipeline progress
4. **Receipt Detail Screen** — view one receipt's data
5. **Settings Screen** — minimal, "View Logs" link
6. **Log Viewer Screen** — filter/browse all app logs

### Happy Path

1. User opens app → Receipt List (empty state: "No receipts yet. Tap + to scan.")
2. Taps "+" → system image picker opens
3. Picks/takes photo → picker dismisses, pipeline starts
4. Progress: "Extracting text..." → "Parsing (1/3)..." → "Parsing (2/3)..." → "Parsing (3/3)..." → "Validating..." → "Saving..."
5. Consensus + totals match → saved as `.verified` → success toast → navigate to Receipt Detail
6. Receipt List shows receipt with green checkmark

### Mismatch Path

1. Steps 1–4 same
2. Consensus fails or totals don't match → saved as `.pendingReview`
3. UI: "We couldn't quite catch it all. Try another photo from a different angle?" → **"Try Again"** / **"Save Anyway"**
4. "Try Again" → picker → re-run → if verified, update row to `.verified`
5. "Save Anyway" → Receipt Detail with orange "Pending Review" badge

### Receipt List Screen

- Each row: store name, date, total, status badge (green/orange)
- "+" button → scan flow
- Gear icon → Settings

### Receipt Detail Screen

- Header: store, date, transaction type, payment card
- Item list: name, qty, unit price, line total
- Footer: subtotal, tax, total
- Status badge
- If `.pendingReview`: "Retry Scan" button

### Navigation

All inside a `NavigationStack`. No tab bar. `MainTabView` remains a conditional root switch (download screen vs receipt list).

---

## 6. iCloud Sync & SwiftData Configuration

### Two Containers

**Synced** (`cloudKitDatabase: .automatic`):
- `Receipt`, `ReceiptItem`, `Store`, `PaymentCard`

**Local only** (`cloudKitDatabase: .none`):
- `LogEntry`

### Setup

`PersonalAiAssistantApp.swift` configures both containers:
- Synced container → SwiftUI `.modelContainer()` environment
- Local container → injected into `AppLogger` directly

### Entitlements

Add to `PersonalAiAssistant.entitlements`:
- `com.apple.developer.icloud-container-identifiers`: `iCloud.com.personalai.assistant`
- `com.apple.developer.icloud-services`: `CloudKit`

### Conflict Resolution

Last-writer-wins (SwiftData + CloudKit default). Acceptable for single-user receipt data.

---

## 7. Model Loading (Chat Removal + Model-Agnostic)

### Removed

- `Features/Chat/ChatModel.swift` — deleted
- `Features/Chat/ChatScreen.swift` — deleted
- `Features/Chat/` directory — removed

### ModelLoader (`App/ModelLoader.swift`)

- Loads model from disk, patches config if needed
- Exposes a loaded model container
- Model-agnostic — doesn't know which model it's loading
- `ReceiptParser` receives the container as a dependency

### Config Patching

Existing `patchConfigIfNeeded()` moves from `ChatModel` to `ModelLoader`. When switching models, update or remove the patch in one place.

### MainTabView Update

```
if downloadState == .completed → ReceiptListScreen()  // was ChatScreen()
```

### Unchanged

- `ModelDownloadService` — still handles background download
- `AppDelegate` — still bridges background URLSession
- `ModelDownloadScreen` — still gates until ready

---

## 8. Future Enhancements (Not In Scope)

Tracked for reference, not implemented in v1:

- Live camera viewfinder with receipt framing guide
- Setting to keep/discard receipt photos (v1 always discards)
- Editable extraction review/correction page (data input with all fields editable)
- Product catalog — normalize item names across stores for price comparison
- Insights dashboards — price comparison between stores, purchase frequency, price fluctuations
- Auto-match payment card by last 4 digits with user confirmation
- Store normalization / merge ("TESCO" vs "Tesco Express")
- Switch to Gemma 3 QAT variant or Gemma 4 E4B model
