# Copilot Instructions — PersonalAiAssistant

## Keeping This File Up to Date

Whenever you make changes to the codebase — adding features, modifying architecture, changing conventions, updating CI/CD, or altering the technology stack — you **must** update this instructions file to reflect those changes. This file is the single source of truth for how the project works and how code should be written. Outdated instructions lead to inconsistent code.

## Project Overview

PersonalAiAssistant is a native iOS app built with Swift 5.9 and SwiftUI targeting iOS 17.0+. The app provides an on-device AI chat experience powered by Google's Gemma 3 4B model running locally via Apple's MLX framework. On first launch, the user downloads the ~3.4 GB model (via iOS background URLSession), then chats with it entirely offline.

## Technology Stack

- **Language:** Swift 5.9
- **UI:** SwiftUI (declarative, modern syntax)
- **Project Generation:** XcodeGen (`project.yml`)
- **CI/CD:** GitHub Actions → Fastlane → TestFlight
- **On-device AI:** MLX Swift (Apple's ML framework) + Gemma 3 4B (Google, Gemma license)
- **Dependencies:** `mlx-swift-lm` (branch: main), `swift-tokenizers-mlx` (≥ 0.1.0) via SPM; Fastlane for CI automation

## Architecture

This project follows **Vertical Slice Architecture** — code is organized by feature, not by technical layer.

```
PersonalAiAssistant/
├── App/                    # @main entry point + AppDelegate for background URLSession
├── Features/
│   ├── Chat/               # ChatModel (MLX inference) + ChatScreen (chat UI)
│   └── ModelManager/       # ModelDownloadService (background download) + ModelDownloadScreen
├── Navigation/             # MainTabView (gates between download screen and chat)
├── Resources/              # Info.plist, entitlements
└── Shared/                 # Reusable UI (currently empty)
```

### Key Rules

- **New features** should be added only when needed and kept self-contained under `Features/<FeatureName>/`.
- **Shared UI components** should go in `Shared/` if the app grows beyond the current single-screen shell.
- **Data models** should go in `Features/Storage/Models/` if persistence is reintroduced.
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

- **Model:** `mlx-community/gemma-3-4b-it-4bit` (~3.4 GB, 4-bit quantized, text-only)
- **Download:** iOS `URLSession.background` — survives backgrounding and app termination. Files stored in `Application Support/Models/gemma-3-4B/`. Model is permanent (no delete option).
- **Inference:** `loadModelContainer(directory:)` loads from local files. `ChatSession` manages multi-turn conversation history with streaming via `streamResponse(to:)`.
- **Target device:** iPhone 15 Pro Max (A17 Pro, 8 GB RAM). Expect ~20–45 tok/s.

## SwiftData Models

No SwiftData models are currently present.

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
