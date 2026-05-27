import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            WorkspaceScreen()
                .tabItem {
                    Label("Workspace", systemImage: "folder")
                }
            StudioScreen()
                .tabItem {
                    Label("Studio", systemImage: "sparkles.rectangle.stack")
                }
            AgentScreen()
                .tabItem {
                    Label("Agent", systemImage: "cpu")
                }
            SettingsScreen()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
