import SwiftUI

struct MainTabView: View {
    var downloadService: ModelDownloadService
    @State private var modelLoader = ModelLoader()

    var body: some View {
        if downloadService.downloadState == .completed {
            if modelLoader.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading model…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await modelLoader.load() }
                .alert(
                    "Failed to Load Model",
                    isPresented: Binding(
                        get: { modelLoader.loadError != nil },
                        set: { if !$0 { modelLoader.dismissLoadError() } }
                    )
                ) {
                    Button("Retry") { Task { await modelLoader.load() } }
                    Button("OK", role: .cancel) { modelLoader.dismissLoadError() }
                } message: {
                    Text(modelLoader.loadError ?? "")
                }
            } else if let container = modelLoader.modelContainer {
                ReceiptListScreen(modelContainer: container)
            }
        } else {
            ModelDownloadScreen(downloadService: downloadService)
        }
    }
}
