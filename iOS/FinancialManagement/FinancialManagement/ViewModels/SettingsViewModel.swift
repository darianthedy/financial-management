import Foundation
import Observation

/// Backs the Settings screen (iOS Tech Plan §8.6). The selected default
/// currency and default account live in `AppState` (the single source of truth
/// every formatter and form reads), so writes route through `AppState`. This
/// view model only loads the list of accounts shown in the default-account
/// picker.
@Observable
@MainActor
final class SettingsViewModel {
    var accounts: [Account] = []
    var isLoading = false
    var errorMessage: String?

    private let accountRepository = AccountRepository()

    func loadAccounts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            accounts = try await accountRepository.getAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
