import SwiftUI

struct ContentRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("Dashboard", systemImage: "chart.pie") }

            NavigationStack {
                AccountListView()
            }
            .tabItem { Label("Accounts", systemImage: "creditcard") }

            NavigationStack {
                TransactionListView()
            }
            .tabItem { Label("Transactions", systemImage: "list.bullet") }

            NavigationStack {
                BudgetListView()
            }
            .tabItem { Label("Budgets", systemImage: "target") }

            NavigationStack {
                MoreView()
            }
            .tabItem { Label("More", systemImage: "ellipsis") }
        }
        .task {
            await appState.loadCurrencyData()
        }
    }
}
