import SwiftUI

@main
struct FinancialManagementApp: App {
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager()

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
            .environment(themeManager)
            // Applies the user's Light/Dark/System choice app-wide, the SwiftUI
            // analog of web toggling `<html class="dark">`. `nil` ("System")
            // defers to the device appearance.
            .preferredColorScheme(themeManager.colorScheme)
            .task {
                await appState.observeAuthState()
            }
        }
    }
}
