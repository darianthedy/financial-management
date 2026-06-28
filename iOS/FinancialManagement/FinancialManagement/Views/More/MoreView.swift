import SwiftUI

struct MoreView: View {
    @State private var showingSignOutConfirm = false

    var body: some View {
        // Secondary destinations mirror web's nav-config.ts non-primary items.
        // Categories and Tags also live there, but their management screens are
        // not yet implemented on iOS (only the form pickers exist), so they are
        // intentionally omitted here until those screens land.
        List {
            Section("Management") {
                NavigationLink {
                    FixedExpenseListView()
                } label: {
                    // web Receipt
                    Label("Fixed Expenses", systemImage: "receipt")
                }

                NavigationLink {
                    ScheduledListView()
                } label: {
                    // web CalendarClock; label matches nav-config ("Scheduled")
                    Label("Scheduled", systemImage: "calendar.badge.clock")
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
                    showingSignOutConfirm = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("More")
        .confirmationDialog(
            "Sign out?",
            isPresented: $showingSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task {
                    let vm = AuthViewModel()
                    await vm.signOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access your accounts.")
        }
    }
}
