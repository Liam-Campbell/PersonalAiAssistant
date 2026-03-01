import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            VoiceCaptureView()
                .tabItem {
                    Label("Capture", systemImage: "mic.fill")
                }

            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "rectangle.grid.2x2")
                }

            TaskListView()
                .tabItem {
                    Label("Tasks", systemImage: "checkmark.circle")
                }

            ShoppingListView()
                .tabItem {
                    Label("Shopping", systemImage: "cart.fill")
                }
        }
    }
}
