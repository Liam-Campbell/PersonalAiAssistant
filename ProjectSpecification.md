iOS Voice Note & Categorization App - Project Specification

1. Project Overview

A native iOS application designed for iPhone that captures voice input, transcribes it to text, and intelligently categorizes the content into actionable items (e.g., Tasks, Projects, Reminders, Shopping Lists).

2. Technology Stack

Language: Swift

UI Framework: SwiftUI

Local Storage: SwiftData

Frameworks: Speech (Transcription), AVFoundation (Audio Capture)

IDE: VS Code (Windows) via GitHub Copilot (Opus 4.6)

CI/CD: GitHub Actions (macOS runner) to TestFlight

3. Architecture & Code Quality (Strict Rules for AI)

Pattern: Vertical Slice Architecture combined with Clean Architecture principles. Group files by feature (e.g., Features/VoiceCapture, Features/Categorization), not by technical layer.

Code Style: Highly readable and self-documenting.

Comments: STRICTLY NO COMMENTS in the generated code. Use descriptive variable and function names instead.

UI: Use modern SwiftUI declarative syntax.

State Management: Use @Observable macros and standard SwiftUI state property wrappers.

4. Core Features & Vertical Slices

4.1. Voice Capture & Transcription (Features/VoiceCapture)

Microphone permission handling.

Real-time audio recording using AVFoundation.

Speech-to-text conversion using the Apple Speech framework.

4.2. Note Processing & Categorization (Features/NoteProcessing)

Domain logic to analyze transcribed text.

Keyword/context extraction to automatically assign categories (Task, Project, Reminder, Shopping).

Tagging system for easy correlation and search.

4.3. Data Persistence (Features/Storage)

SwiftData models for Note, Category, and Tag.

CRUD operations for the transcribed and categorized items.

4.4. Dynamic Dashboards (Features/Dashboard)

Dedicated SwiftUI views filtered by category:

Tasks for the Day

Ongoing Projects

Reminders

Shopping Lists

Global search functionality across all notes and tags.

5. Testing Strategy

Implement XCTest for core domain logic.

Focus testing specifically on the Categorization and Text Processing engines to establish a baseline for test coverage.

Do not write UI tests at this stage.

6. CI/CD Pipeline (.github/workflows/ios-deploy.yml)

Generate a GitHub Actions workflow using macos-latest.

Pipeline must resolve dependencies, build the .ipa, sign it using injected GitHub Secrets (Certificates and Provisioning Profiles), and upload to App Store Connect (TestFlight) using Fastlane.