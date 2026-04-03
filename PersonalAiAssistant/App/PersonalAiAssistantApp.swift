import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
    let downloadService = ModelDownloadService()

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        downloadService.setBackgroundCompletionHandler(completionHandler)
    }
}

@main
struct PersonalAiAssistantApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainTabView(downloadService: appDelegate.downloadService)
        }
    }
}
