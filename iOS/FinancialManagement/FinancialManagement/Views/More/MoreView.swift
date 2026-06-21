import SwiftUI

struct MoreView: View {
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
