import SwiftUI

struct MainTabView: View {
    var downloadService: ModelDownloadService

    var body: some View {
        if downloadService.downloadState == .completed {
            ChatScreen()
        } else {
            ModelDownloadScreen(downloadService: downloadService)
        }
    }
}
