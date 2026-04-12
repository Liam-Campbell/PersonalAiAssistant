# Copilot Instructions — PersonalAiAssistant

## Keeping This File Up to Date

Whenever you make changes to the codebase — adding features, modifying architecture, changing conventions, updating CI/CD, or altering the technology stack — you **must** update this instructions file to reflect those changes. This file is the single source of truth for how the project works and how code should be written. Outdated instructions lead to inconsistent code.

## Project Overview

PersonalAiAssistant is a native iOS app built with Swift 5.9 and SwiftUI targeting iOS 17.0+. The app lets users photograph shop receipts, extract structured data using Apple Vision OCR + on-device LLM (Gemma 3 4B via MLX), and persist spending history with iCloud sync. On first launch, the user downloads the ~3.4 GB model (via iOS background URLSession), then scans receipts entirely offline.

## Technology Stack

- **Language:** Swift 5.9
- **UI:** SwiftUI (declarative, modern syntax)
- **Persistence:** SwiftData + CloudKit (iCloud sync for receipt data, local-only for logs)
- **OCR:** Apple Vision Framework (`VNRecognizeTextRequest`, `.accurate` recognition level)
- **Project Generation:** XcodeGen (`project.yml`)
- **CI/CD:** GitHub Actions → Fastlane → TestFlight
- **On-device AI:** MLX Swift (Apple's ML framework) + Gemma 3 4B (Google, Gemma license)
- **Dependencies:** `mlx-swift-lm` (SPM, `from: 2.30.0`) and Fastlane for CI automation

## Architecture

This project follows **Vertical Slice Architecture** — code is organized by feature, not by technical layer.

```
PersonalAiAssistant/
├── App/                    # @main entry point, AppDelegate, ModelLoader
├── Features/
│   ├── Logging/            # AppLogger (singleton), LogEntry (@Model), LogViewerScreen
│   ├── ModelManager/       # ModelDownloadService (background download) + ModelDownloadScreen
│   ├── ReceiptScanner/     # OCRService, ReceiptParser, ReceiptPipeline, scan/list/detail screens
│   ├── Settings/           # SettingsScreen (links to log viewer)
│   └── Storage/Models/     # SwiftData models: Receipt, ReceiptItem, Store, PaymentCard, enums
├── Navigation/             # MainTabView (gates between download, model loading, and receipt list)
├── Resources/              # Info.plist, entitlements, Assets.xcassets
└── Shared/                 # Reusable UI (currently empty)
```

### Key Rules

- **New features** should be added only when needed and kept self-contained under `Features/<FeatureName>/`.
- **Shared UI components** should go in `Shared/` if the app grows beyond the current single-screen shell.
- **Data models** live in `Features/Storage/Models/`. All SwiftData `@Model` types and their supporting enums go here.
- **Do not create** flat technical-layer folders like `Controllers/`, `Services/`, or `ViewModels/` at the root.

## Coding Conventions

### No Comments

Code must be self-documenting. Do not add comments to Swift source files. Instead use:

- Descriptive variable names: `transcribedText`, `hasPermission`, `recordingURL`
- Descriptive function names: `startRecording()`, `requestPermissions()`, `processAndSave()`
- Clear, readable control flow

### Swift & SwiftUI Patterns

- Use `.task { }` for async work in SwiftUI views.
- Use `NavigationStack` for navigation.
- Use `@Observable final class` for view models and stateful services if stateful app logic is added later.
- Keep new domain logic types stateless and pure where possible.

### Naming

- Types: `PascalCase` (e.g., `VoiceCaptureViewModel`, `NoteCategory`)
- Properties/methods: `camelCase` (e.g., `isRecording`, `startRecording()`)
- Files: match the primary type name (e.g., `VoiceCaptureViewModel.swift`)

## AI / MLX Integration

- **Model:** `mlx-community/gemma-3-4b-it-4bit` (~3.4 GB, 4-bit quantized). Design is model-agnostic — switching to Gemma 4 E4B later requires only changing the download URL and updating config repair.
- **Download:** iOS `URLSession.background` — survives backgrounding and app termination. Files stored in `Application Support/Models/gemma-3-4B/`. Model is permanent (no delete option).
- **Loading:** `ModelLoader` (`@Observable`) loads the model from disk, patches the config, and exposes `modelContainer: MLXLMCommon.ModelContainer`.
- **Inference:** `ReceiptParser` uses `MLXLMCommon.ModelContainer` to run structured JSON extraction prompts. No chat session — single-turn prompts only.
- **Triple consensus:** Every receipt is parsed 3 times independently. All 3 runs must produce identical JSON output (exact match) for the receipt to be marked `.verified`. If any differ, the receipt is saved as `.pendingReview` for user retry.
- **Config repair:** `ModelLoader` patches missing Gemma 3 fields (`text_config.num_attention_heads`, `text_config.num_key_value_heads`, `text_config.head_dim`) in the downloaded `config.json` before loading. Do not remove.
- **Target device:** iPhone 15 Pro Max (A17 Pro, 8 GB RAM). Expect ~20–45 tok/s.

## Receipt Scanning Pipeline

1. **Photo selection** via `PhotosPicker` (ImagePicker for v1, live camera planned)
2. **OCR** via Apple Vision — `VNRecognizeTextRequest` at `.accurate` level extracts all text
3. **LLM parsing** — OCR text sent to Gemma 3 times with a structured JSON extraction prompt
4. **Validation** — All 3 parse results must match exactly; line item totals must sum to receipt total (exact `Decimal` comparison, 0.00 tolerance)
5. **Persistence** — On match: saved as `.verified`. On mismatch: saved as `.pendingReview` with retry option
6. **Retry** — Re-runs the full pipeline; updates the existing `Receipt` row if now verified

## Pitfalls & Gotchas

- **Config repair is required.** `ModelLoader` patches missing Gemma 3 fields in the downloaded `config.json` before loading. Do not remove this as "cleanup" — `mlx-swift-lm` will crash without it.
- **AppDelegate bridge is required.** The background `URLSession` download completion handler is forwarded from `AppDelegate` to `ModelDownloadService`. Any refactor that removes `@UIApplicationDelegateAdaptor` will break background download resumption.
- **`MainTabView` is not a tab bar.** Despite the name, it is a conditional root switch between `ModelDownloadScreen`, a model loading spinner, and `ReceiptListScreen` based on download/load state.
- **Dual SwiftData containers.** `PersonalAiAssistantApp` creates two `ModelContainer`s: a synced one (Receipt, ReceiptItem, Store, PaymentCard) with CloudKit, and a local-only one (LogEntry) for logs. Do not merge them — logs must not sync.
- **`MLXLMCommon.ModelContainer` vs `SwiftData.ModelContainer`.** Both types are named `ModelContainer`. Always qualify with the module name to avoid ambiguity.
- **Download progress appears flat at 0%** while small prerequisite files download. Progress is only driven from `model.safetensors`.
- **No model integrity checks.** Model readiness is purely file-existence-based (`requiredFiles` in `Application Support/Models/gemma-3-4B/`). There is no checksum validation or delete flow.
- **CI placeholder icon.** The `ios-deploy.yml` workflow generates a placeholder 1024×1024 app icon PNG during CI if a real icon is missing. This is intentional — do not remove it.
- **Photo is deleted after extraction.** The original receipt image is not retained. The plan includes a future setting to control retention.

## SwiftData Models

All models live in `Features/Storage/Models/`. CloudKit-synced models use raw `String` backing properties for enums (CloudKit cannot serialize custom enum types).

- **`Receipt`** — Primary record: `purchaseDate`, `total`, `subtotal`, `tax`, `currency`, `status` (verified/pendingReview), `transactionType` (card/cash/contactless/other), relationships to `Store`, `PaymentCard`, and `[ReceiptItem]`.
- **`ReceiptItem`** — Line item: `name`, `quantity`, `unitPrice`, `lineTotal`, parent `Receipt`.
- **`Store`** — Deduplicated by name: `name`, `address`.
- **`PaymentCard`** — Deduplicated by last four + network: `lastFourDigits`, `network`, computed `label`.
- **`ReceiptStatus`** — Enum: `.verified`, `.pendingReview`.
- **`TransactionType`** — Enum: `.card`, `.cash`, `.contactless`, `.other`.

## App Logging

- **`AppLogger`** (singleton) writes structured logs to a local-only SwiftData container.
- **`LogEntry`** (`@Model`) stores `timestamp`, `level` (debug/info/warning/error), `source`, `message`, `detail`.
- **`LogViewerScreen`** provides filterable, searchable, expandable log browsing.
- All pipeline steps, model loads, errors, and consensus results are logged.
- Old entries are pruned on app launch (30-day retention).

## Testing

- No automated test target is currently configured in this repository.

## Build & Project Generation

The Xcode project is generated from `project.yml` using XcodeGen. Do not manually edit `*.xcodeproj` files.

App assets live under `PersonalAiAssistant/Resources/Assets.xcassets/`. The iPhone app icon set is `AppIcon.appiconset`, and the target expects its name to remain `AppIcon`.

```bash
xcodegen generate
```

Key project settings:
- Bundle ID: `com.personalai.assistant`
- Deployment target: iOS 17.0
- Swift version: 5.9
- Code signing: Manual (configured via environment variables in CI)

## CI/CD

### Workflows

- **`ios-deploy.yml`** — Triggers on push to `main`. Generates project → builds → deploys to TestFlight via `fastlane ios beta`.
- **`setup-match.yml`** — Manual dispatch to initialize/regenerate Fastlane Match certificates and profiles via `fastlane setup_match`.

### Fastlane

- **`setup_match` lane** — Sets up CI keychain, authenticates with App Store Connect API key, runs `match` to manage certificates/profiles.
- **`beta` lane** — Authenticates, fetches signing assets (readonly), increments build number, builds, and uploads to TestFlight.
- Fastlane version: `~> 2.225` (via Gemfile).

### Required Secrets & Variables

| Name | Type | Purpose |
|------|------|---------|
| `APP_STORE_CONNECT_KEY_CONTENT` | Secret | .p8 API key content |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Secret | Git auth for Match certificate repo |
| `APP_STORE_CONNECT_KEY_ID` | Variable | API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Variable | Issuer ID |
| `MATCH_REPO_URL` | Variable | Match certificate git repo URL |
| `MATCH_PASSWORD` | Variable | Match encryption password |
| `DEVELOPMENT_TEAM` | Variable | Apple Developer Team ID |

## Related Documentation

- **`ProjectSpecification.md`** — Original project specification. Describes the initial "hi" screen shell and is now outdated relative to the current chat + model download implementation. Kept for historical context.
- **`README.md`** — Also outdated (still describes the minimal shell). Should be updated when the app stabilizes.
- **This file** is the authoritative, up-to-date source of truth for how the codebase works.
