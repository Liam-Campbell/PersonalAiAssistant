import SwiftUI

struct ModelDownloadScreen: View {
    var downloadService: ModelDownloadService

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("AI Model Required")
                .font(.title2.bold())

            Text("Download the Gemma 3 language model to chat offline. This requires about 3.4 GB of storage.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            downloadContent

            Spacer()
        }
    }

    @ViewBuilder
    private var downloadContent: some View {
        switch downloadService.downloadState {
        case .notStarted:
            Button("Download Model") {
                downloadService.startDownload()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .downloading(let progress):
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .padding(.horizontal, 40)
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("Download continues if you leave the app")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

        case .completed:
            Label("Download Complete", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)

        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button("Retry") {
                    downloadService.startDownload()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
