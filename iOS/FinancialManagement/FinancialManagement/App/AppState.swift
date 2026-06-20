import Foundation
import Observation
import Supabase

/// Global app state: auth status plus the single-currency context (default
/// currency, its decimal places, the full currencies list, and the default
/// account) that every formatter and form reads. See iOS Tech Plan §4.3.
@Observable
@MainActor
final class AppState {
    var isAuthenticated = false
    var currentUser: User?

    // Single-currency context, loaded once after sign-in.
    var defaultCurrency = "USD"
    var defaultAccountId: UUID?
    var currencies: [Currency] = []

    /// decimal_places for the active default currency (drives minor-unit scaling).
    var decimalPlaces: Int {
        currencies.first { $0.code == defaultCurrency }?.decimalPlaces ?? 2
    }

    private let supabase = SupabaseService.shared.client
    private let currencyRepo = CurrencyRepository()

    func observeAuthState() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .tokenRefreshed:
                if let session {
                    isAuthenticated = true
                    currentUser = session.user
                    await loadCurrencyData()
                } else {
                    isAuthenticated = false
                    currentUser = nil
                }
            case .signedOut:
                isAuthenticated = false
                currentUser = nil
                defaultCurrency = "USD"
                defaultAccountId = nil
                currencies = []
            default:
                break
            }
        }
    }

    func loadCurrencyData() async {
        currencies = (try? await currencyRepo.getAllCurrencies()) ?? []
        CurrencyUtils.configure(with: currencies)
        if let settings = try? await currencyRepo.getUserSettings() {
            defaultCurrency = settings.defaultCurrency
            defaultAccountId = settings.defaultAccountId
        }
    }

    /// Updates the default currency (the picker lives in Settings, P10). Reloads
    /// `defaultCurrency` so every formatter picks up the new `decimalPlaces`.
    func updateDefaultCurrency(_ code: String) async {
        if let settings = try? await currencyRepo.upsertDefaultCurrency(code) {
            defaultCurrency = settings.defaultCurrency
        }
    }

    /// Sets (or clears, with `nil`) the default account on
    /// `user_settings.default_account_id` — one at a time. Mirrors the new value
    /// back into `defaultAccountId` so the UI updates immediately.
    func setDefaultAccount(_ accountId: UUID?) async throws {
        let settings = try await currencyRepo.updateDefaultAccountId(accountId)
        defaultAccountId = settings.defaultAccountId
    }

    func currency(for code: String) -> Currency? {
        currencies.first { $0.code == code }
    }
}
