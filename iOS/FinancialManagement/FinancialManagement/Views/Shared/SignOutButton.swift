import SwiftUI

/// Sign Out with its confirmation, at the end of the More list.
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
