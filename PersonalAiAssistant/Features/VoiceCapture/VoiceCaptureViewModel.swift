import SwiftUI
import SwiftData

@Observable
final class VoiceCaptureViewModel {
    let audioRecorder = AudioRecorder()
    let speechTranscriber = SpeechTranscriber()
    var transcribedText = ""
    var errorMessage: String?
    var showError = false
    var isSaving = false

    var isReady: Bool {
        audioRecorder.hasPermission && speechTranscriber.hasPermission
    }

    func requestPermissions() async {
        await audioRecorder.requestPermission()
        await speechTranscriber.requestPermission()
    }

    func toggleRecording() {
        if audioRecorder.isRecording {
            stopAndTranscribe()
        } else {
            startRecording()
        }
    }

    func saveNote(using modelContext: ModelContext) {
        guard !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isSaving = true
        let processor = NoteProcessor()
        processor.processAndSave(text: transcribedText, context: modelContext)
        transcribedText = ""
        isSaving = false
    }

    private func startRecording() {
        do {
            transcribedText = ""
            try audioRecorder.startRecording()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func stopAndTranscribe() {
        audioRecorder.stopRecording()

        Task {
            do {
                transcribedText = try await speechTranscriber.transcribe(
                    audioURL: audioRecorder.recordingURL
                )
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
