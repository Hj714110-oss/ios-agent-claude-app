import SwiftUI

struct WorkspaceScreen: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Workspace path", text: $container.workspaceRoot)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                EditorBridgeView(text: $container.selectedFileContent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal)
            }
            .navigationTitle("Workspace")
        }
    }
}
