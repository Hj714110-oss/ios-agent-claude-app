import SwiftUI

@main
struct AgentIDEAppMain: App {
    @StateObject private var container = AppContainer.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(container)
        }
    }
}
