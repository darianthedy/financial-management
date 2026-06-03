import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class AuthViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    private let supabase = SupabaseService.shared.client

    func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase.auth.signIn(
                email: email,
                password: password
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase.auth.signUp(
                email: email,
                password: password
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
