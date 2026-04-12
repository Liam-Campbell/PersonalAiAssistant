import SwiftUI

struct SettingsScreen: View {
    var body: some View {
        List {
            Section {
                NavigationLink("View Logs", destination: LogViewerScreen())
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
