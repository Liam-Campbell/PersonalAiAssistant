iOS Voice Note & Categorization App - Project Specification

1. Project Overview

A native iOS application designed for iPhone. The current implementation is intentionally reduced to a single SwiftUI screen that displays only hi.

2. Technology Stack

Language: Swift

UI Framework: SwiftUI

IDE: VS Code (Windows) via GitHub Copilot (Opus 4.6)

CI/CD: GitHub Actions (macOS runner) to TestFlight

3. Architecture & Code Quality (Strict Rules for AI)

Pattern: Minimal app shell. Keep the entry point in App and the current root screen in Navigation. Add feature folders only when the app needs more than the single-screen shell.

Code Style: Highly readable and self-documenting.

Comments: STRICTLY NO COMMENTS in the generated code. Use descriptive variable and function names instead.

UI: Use modern SwiftUI declarative syntax.

State Management: Use standard SwiftUI state property wrappers. Use @Observable only if app state grows beyond the current minimal screen.

4. Core Features & Vertical Slices

4.1. Root Screen

Launch the app into a single SwiftUI view.

Render only the text hi.

5. Testing Strategy

No automated test target is required at this stage.

Do not add UI tests at this stage.

6. CI/CD Pipeline (.github/workflows/ios-deploy.yml)

Generate a GitHub Actions workflow using macos-latest.

Pipeline must resolve dependencies, build the .ipa, sign it using injected GitHub Secrets (Certificates and Provisioning Profiles), and upload to App Store Connect (TestFlight) using Fastlane.