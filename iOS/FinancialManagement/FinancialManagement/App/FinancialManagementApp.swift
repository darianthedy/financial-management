import SwiftUI
import UIKit

@main
struct FinancialManagementApp: App {
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager()

    init() {
        Self.configureNavigationBarAppearance()
    }

    /// Forces an opaque navigation bar app-wide. iOS 26's default Liquid Glass
    /// nav bar is translucent, so list rows scrolling under it — e.g. the strip
    /// above a pinned section header in the Transactions list — show through.
    /// An opaque background keyed to the `AppBackground` token hides them and
    /// matches the app's solid, web-aligned surfaces; the opaque appearance also
    /// carries the system hairline separator beneath the bar. Applied to every
    /// appearance slot so it holds at the scroll edge (large title) and when
    /// collapsed/compact alike.
    private static func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "AppBackground")

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.compactScrollEdgeAppearance = appearance
    }

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
