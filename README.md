# PersonalAiAssistant

A native iOS app that currently launches into a single screen showing only `hi`.

## Technology Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9 |
| UI | SwiftUI |
| CI/CD | GitHub Actions → Fastlane → TestFlight |
| Project Gen | XcodeGen (`project.yml`) |

## Architecture

Minimal SwiftUI app shell.

```
PersonalAiAssistant/
├── App/
│   └── PersonalAiAssistantApp.swift          # @main entry point
├── Navigation/
│   └── MainTabView.swift                     # Single-screen root view
└── Resources/
    ├── Info.plist
    └── PersonalAiAssistant.entitlements

.github/workflows/
└── ios-deploy.yml                            # Build → TestFlight
```

## Setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Generate the Xcode project: `xcodegen generate`
3. Open `PersonalAiAssistant.xcodeproj` and run on an iPhone simulator (iOS 17+)

## CI/CD

The GitHub Actions workflow (`.github/workflows/ios-deploy.yml`) triggers on pushes to `main`:

1. Generates the Xcode project via XcodeGen
2. Builds the app on an iOS Simulator target
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

There is currently no automated test target configured in this repository.
