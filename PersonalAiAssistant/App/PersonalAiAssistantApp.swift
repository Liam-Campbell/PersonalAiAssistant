import SwiftUI
import SwiftData

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

    let syncedContainer: ModelContainer
    let logContainer: ModelContainer

    init() {
        let syncedConfig = ModelConfiguration(
            "ReceiptStore",
            schema: Schema([Receipt.self, ReceiptItem.self, Store.self, PaymentCard.self]),
            cloudKitDatabase: .automatic
        )
        let logConfig = ModelConfiguration(
            "LogStore",
            schema: Schema([LogEntry.self]),
            cloudKitDatabase: .none
        )

        do {
            syncedContainer = try ModelContainer(
                for: Receipt.self, ReceiptItem.self, Store.self, PaymentCard.self,
                configurations: syncedConfig
            )
            logContainer = try ModelContainer(
                for: LogEntry.self,
                configurations: logConfig
            )
        } catch {
            fatalError("Failed to create model containers: \(error)")
        }

        AppLogger.shared.configure(container: logContainer)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(downloadService: appDelegate.downloadService)
                .modelContainer(syncedContainer)
                .task {
                    await AppLogger.shared.pruneOldEntries()
                }
        }
    }
}
