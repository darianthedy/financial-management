import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class AppState {
    var isAuthenticated = false
    var currentUser: User?
    var defaultCurrency: String = "USD"
    var currencies: [Currency] = []

    private let supabase = SupabaseService.shared.client
    private let currencyRepo = CurrencyRepository()

    func observeAuthState() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .tokenRefreshed:
                if let session {
                    isAuthenticated = true
                    currentUser = session.user
                } else {
                    isAuthenticated = false
                    currentUser = nil
                }
            case .signedOut:
                isAuthenticated = false
                currentUser = nil
                defaultCurrency = "USD"
                currencies = []
            default:
                break
            }
        }
    }

    func loadCurrencyData() async {
        do {
            currencies = try await currencyRepo.getAllCurrencies()
            CurrencyUtils.configure(with: currencies)
            if let settings = try await currencyRepo.getUserSettings() {
                defaultCurrency = settings.defaultCurrency
            }
        } catch {
            // Non-fatal: fall back to "USD"
        }
    }

    func updateDefaultCurrency(_ code: String) async {
        do {
            let settings = try await currencyRepo.upsertDefaultCurrency(code)
            defaultCurrency = settings.defaultCurrency
        } catch {
            // Non-fatal
        }
    }

    func currency(for code: String) -> Currency? {
        currencies.first { $0.code == code }
    }
}
