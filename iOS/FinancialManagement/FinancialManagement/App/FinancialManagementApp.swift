import SwiftUI
import UIKit

@main
struct FinancialManagementApp: App {
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager()

    init() {
        Self.configureNavigationBarAppearance()
    }

    /// Makes the navigation bar opaque **once scrolled** so list rows don't show
    /// through it (iOS 26's default Liquid Glass bar is translucent), while
    /// keeping the **scroll-edge** (top) state transparent so the large title
    /// still renders there. Forcing the scroll-edge opaque suppresses the large
    /// title — it only reappears after scrolling — so the two states are
    /// configured separately. At the very top there is no content under the bar
    /// to bleed through, so a transparent edge is safe.
    private static func configureNavigationBarAppearance() {
        // Scrolled / standard state: opaque, keyed to the app background token so
        // it matches the app's solid surfaces and carries the system hairline.
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithOpaqueBackground()
        scrolled.backgroundColor = UIColor(named: "AppBackground")

        // Scroll-edge (top) state: transparent, so the large title sits on the
        // plain background as usual.
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = scrolled
        bar.compactAppearance = scrolled
        bar.scrollEdgeAppearance = edge
        bar.compactScrollEdgeAppearance = edge
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch appState.authStatus {
                case .loading:
                    SplashView()
                case .authenticated:
                    ContentRootView()
                case .unauthenticated:
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
