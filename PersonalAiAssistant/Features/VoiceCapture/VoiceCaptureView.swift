import SwiftUI

struct VoiceCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = VoiceCaptureViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                transcriptionDisplay
                recordButton
                if !viewModel.transcribedText.isEmpty {
                    saveButton
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Voice Capture")
            .task { await viewModel.requestPermissions() }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
        }
    }

    private var transcriptionDisplay: some View {
        GroupBox {
            if viewModel.speechTranscriber.isTranscribing {
                ProgressView("Transcribing...")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if viewModel.transcribedText.isEmpty {
                Text(viewModel.audioRecorder.isRecording
                     ? "Listening..."
                     : "Tap the microphone to start recording")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Text(viewModel.transcribedText)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            }
        }
    }

    private var recordButton: some View {
        Button {
            viewModel.toggleRecording()
        } label: {
            Image(systemName: viewModel.audioRecorder.isRecording
                  ? "stop.circle.fill"
                  : "mic.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(viewModel.audioRecorder.isRecording ? .red : .blue)
                .symbolEffect(.pulse, isActive: viewModel.audioRecorder.isRecording)
        }
        .disabled(!viewModel.isReady || viewModel.speechTranscriber.isTranscribing)
    }

    private var saveButton: some View {
        Button {
            viewModel.saveNote(using: modelContext)
        } label: {
            Label("Save & Categorize", systemImage: "square.and.arrow.down")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(viewModel.isSaving)
    }
}
