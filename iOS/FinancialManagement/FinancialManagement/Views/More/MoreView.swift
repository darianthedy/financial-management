import SwiftUI

/// The More tab (compact width only). Its rows push `MoreDestination`s onto
/// the root's More stack, so the root can map them to sidebar tabs and back
/// when the size class changes (ContentRootView).
struct MoreView: View {
    var body: some View {
        // Secondary destinations mirror web's nav-config.ts non-primary items.
        List {
            Section("Management") {
                ForEach(MoreDestination.managementCases, id: \.self) { destination in
                    NavigationLink(value: destination) {
                        Label(destination.title, systemImage: destination.systemImage)
                    }
                }
            }

            Section("Settings") {
                NavigationLink(value: MoreDestination.settings) {
                    Label(MoreDestination.settings.title, systemImage: MoreDestination.settings.systemImage)
                }
            }

            Section {
                SignOutButton()
            }
        }
        .navigationTitle("More")
    }
}

/// Sign Out with its confirmation. Lives in More on compact width and in the
/// sidebar footer on regular width.
struct SignOutButton: View {
    @State private var showingConfirm = false

    var body: some View {
        Button(role: .destructive) {
            showingConfirm = true
        } label: {
            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
        }
        .confirmationDialog(
            "Sign out?",
            isPresented: $showingConfirm,
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
