# Copilot Instructions — PersonalAiAssistant

## Keeping This File Up to Date

Whenever you make changes to the codebase — adding features, modifying architecture, changing conventions, updating CI/CD, or altering the technology stack — you **must** update this instructions file to reflect those changes. This file is the single source of truth for how the project works and how code should be written. Outdated instructions lead to inconsistent code.

## Project Overview

PersonalAiAssistant is a native iOS app that captures voice input, transcribes it, and categorizes content into actionable items (Tasks, Projects, Reminders, Shopping Lists). Built with Swift 5.9, SwiftUI, and SwiftData targeting iOS 17.0+.

## Technology Stack

- **Language:** Swift 5.9
- **UI:** SwiftUI (declarative, modern syntax)
- **State:** `@Observable` macro (not `@StateObject`/`@ObservableObject`)
- **Persistence:** SwiftData (`@Model` entities, no CoreData)
- **Audio:** AVFoundation (`AVAudioRecorder`)
- **Transcription:** Apple Speech framework
- **Project Generation:** XcodeGen (`project.yml`)
- **CI/CD:** GitHub Actions → Fastlane → TestFlight
- **Testing:** XCTest (unit tests only)
- **Dependencies:** No external Swift packages; only Fastlane for automation

## Architecture

This project follows **Vertical Slice Architecture** — code is organized by feature, not by technical layer.

```
PersonalAiAssistant/
├── App/                    # @main entry point, SwiftData container setup
├── Features/
│   ├── VoiceCapture/       # Audio recording + speech transcription
│   ├── NoteProcessing/     # Categorization engine + save orchestration
│   ├── Dashboard/          # All notes view, filtered list views
│   ├── ShoppingList/       # Shopping checklist UI
│   └── Storage/Models/     # SwiftData @Model entities (Note, Tag, NoteCategory)
├── Navigation/             # MainTabView (root TabView)
├── Shared/                 # Reusable UI components (NoteRowView)
└── Resources/              # Info.plist, entitlements
```

### Key Rules

- **New features** go in `Features/<FeatureName>/` with their own views, view models, and logic self-contained.
- **Shared UI components** go in `Shared/`.
- **Data models** go in `Features/Storage/Models/`.
- **Do not create** flat technical-layer folders like `Controllers/`, `Services/`, or `ViewModels/` at the root.

## Coding Conventions

### No Comments

Code must be self-documenting. Do not add comments to Swift source files. Instead use:

- Descriptive variable names: `transcribedText`, `hasPermission`, `recordingURL`
- Descriptive function names: `startRecording()`, `requestPermissions()`, `processAndSave()`
- Clear, readable control flow

### Swift & SwiftUI Patterns

- Use `@Observable final class` for view models and stateful services — never `ObservableObject`/`@Published`.
- Use `@Model` for SwiftData entities.
- Use `.task { }` for async work in SwiftUI views.
- Use `NavigationStack` for navigation.
- Keep view models as `@Observable` classes that compose dependencies (e.g., `AudioRecorder`, `SpeechTranscriber`).
- Domain logic classes (e.g., `TextCategorizationEngine`) should be stateless and pure where possible.

### Naming

- Types: `PascalCase` (e.g., `VoiceCaptureViewModel`, `NoteCategory`)
- Properties/methods: `camelCase` (e.g., `isRecording`, `startRecording()`)
- Files: match the primary type name (e.g., `VoiceCaptureViewModel.swift`)

## SwiftData Models

- `Note` — core entity with title, content, category, timestamps, and cascading relationship to `Tag`.
- `Tag` — lightweight entity with a name string.
- `NoteCategory` — enum (`.task`, `.project`, `.reminder`, `.shopping`) stored via raw value on `Note`.
- Use in-memory `ModelConfiguration` for tests: `ModelConfiguration(isStoredInMemoryOnly: true)`.

## Testing

- **Framework:** XCTest
- **Location:** `PersonalAiAssistantTests/`
- **Focus:** Domain logic unit tests (categorization, note processing). No UI tests.
- Tests use `@MainActor` and in-memory SwiftData containers.
- Test methods follow the pattern: `test<Behavior>` (e.g., `testShoppingCategorization`, `testEmptyTextDefaultsToTask`).

### Running Tests

```bash
xcodebuild test \
  -project PersonalAiAssistant.xcodeproj \
  -scheme PersonalAiAssistantTests \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'
```

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

- **`ios-deploy.yml`** — Triggers on push to `main`. Generates project → builds → tests → deploys to TestFlight via `fastlane ios beta`.
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
