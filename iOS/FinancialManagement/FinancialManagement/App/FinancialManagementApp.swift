import SwiftUI

@main
struct FinancialManagementApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated {
                    ContentRootView()
                } else {
                    LoginView()
                }
            }
            .environment(appState)
            .task {
                await appState.observeAuthState()
            }
        }
    }
}
