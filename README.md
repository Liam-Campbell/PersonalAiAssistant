# PersonalAiAssistant

A native iOS app that captures voice input, transcribes it to text, and intelligently categorizes content into actionable items — Tasks, Projects, Reminders, and Shopping Lists.

## Technology Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9 |
| UI | SwiftUI |
| Persistence | SwiftData |
| Audio | AVFoundation |
| Transcription | Speech framework |
| CI/CD | GitHub Actions → Fastlane → TestFlight |
| Project Gen | XcodeGen (`project.yml`) |

## Architecture

Vertical Slice Architecture — files grouped by feature, not by technical layer.

```
PersonalAiAssistant/
├── App/
│   └── PersonalAiAssistantApp.swift          # @main entry point
├── Features/
│   ├── VoiceCapture/
│   │   ├── AudioRecorder.swift               # AVFoundation recording
│   │   ├── SpeechTranscriber.swift           # Speech framework transcription
│   │   ├── VoiceCaptureViewModel.swift       # @Observable view model
│   │   └── VoiceCaptureView.swift            # SwiftUI recording UI
│   ├── NoteProcessing/
│   │   ├── TextCategorizationEngine.swift    # Keyword-based categorizer
│   │   └── NoteProcessor.swift               # Orchestrates save from text
│   ├── Dashboard/
│   │   ├── DashboardView.swift               # All notes with search
│   │   ├── TaskListView.swift                # Tasks for the day
│   │   ├── ProjectListView.swift             # Ongoing projects
│   │   └── ReminderListView.swift            # Reminders
│   ├── ShoppingList/
│   │   └── ShoppingListView.swift            # Checklist-style shopping
│   └── Storage/
│       └── Models/
│           ├── Note.swift                    # @Model — core entity
│           ├── NoteCategory.swift            # Enum with display props
│           └── Tag.swift                     # @Model — tag entity
├── Navigation/
│   └── MainTabView.swift                     # TabView root navigation
├── Shared/
│   └── NoteRowView.swift                     # Reusable note row
└── Resources/
    ├── Info.plist
    └── PersonalAiAssistant.entitlements

PersonalAiAssistantTests/
├── TextCategorizationEngineTests.swift
└── NoteProcessorTests.swift

.github/workflows/
└── ios-deploy.yml                            # Build → Test → TestFlight
```

## Setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Generate the Xcode project: `xcodegen generate`
3. Open `PersonalAiAssistant.xcodeproj` and run on an iPhone simulator (iOS 17+)

## CI/CD

The GitHub Actions workflow (`.github/workflows/ios-deploy.yml`) triggers on pushes to `main`:

1. Generates the Xcode project via XcodeGen
2. Builds and runs unit tests on an iOS Simulator
3. Signs and uploads to TestFlight via Fastlane

### Required GitHub Secrets

| Secret | Purpose |
|---|---|
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | API issuer ID |
| `APP_STORE_CONNECT_KEY_CONTENT` | Base64-encoded `.p8` key |
| `MATCH_GIT_URL` | Fastlane Match certificates repo |
| `MATCH_PASSWORD` | Match encryption password |
| `DEVELOPMENT_TEAM` | Apple Developer Team ID |

## Testing

Unit tests cover the core categorization engine and note processor logic:

```bash
xcodebuild test \
  -project PersonalAiAssistant.xcodeproj \
  -scheme PersonalAiAssistantTests \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'
```
