import SwiftUI

struct MoreView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section("Management") {
                NavigationLink {
                    FixedExpenseListView()
                } label: {
                    Label("Fixed Expenses", systemImage: "calendar.badge.clock")
                }

                NavigationLink {
                    ScheduledListView()
                } label: {
                    Label("Scheduled Transactions", systemImage: "clock.arrow.2.circlepath")
                }
            }

            Section("Settings") {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }

            Section {
                Button(role: .destructive) {
                    Task {
                        let vm = AuthViewModel()
                        await vm.signOut()
                    }
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("More")
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var defaultCurrency = "USD"

    var body: some View {
        @Bindable var state = appState

        List {
            Section("Currency") {
                CurrencyPicker(label: "Default Currency", selectedCode: $defaultCurrency)
            }

            Section("Preferences") {
                NavigationLink("Categories") {
                    Text("Category management coming soon")
                }
                NavigationLink("Tags") {
                    Text("Tag management coming soon")
                }
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            defaultCurrency = appState.defaultCurrency
        }
        .onChange(of: defaultCurrency) { _, newValue in
            guard newValue != appState.defaultCurrency else { return }
            Task {
                await appState.updateDefaultCurrency(newValue)
            }
        }
    }
}
