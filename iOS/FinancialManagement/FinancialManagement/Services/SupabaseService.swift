import Foundation
import Supabase

@MainActor
final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        let db = SupabaseClientOptions.DatabaseOptions(
            encoder: Self.postgrestEncoder(), decoder: Self.postgrestDecoder()
        )
        var options = SupabaseClientOptions(db: db)
        #if DEBUG
        // Layout tests and gate screenshots: canned data + a fake signed-in
        // session, no network (Debug/FixtureURLProtocol.swift).
        if FixtureMode.isEnabled {
            options = SupabaseClientOptions(
                db: db,
                auth: .init(storage: FixtureAuthStorage(), autoRefreshToken: false),
                global: .init(session: FixtureMode.makeSession())
            )
        }
        #endif
        client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey,
            options: options
        )
    }

    private static func postgrestDecoder() -> JSONDecoder {
        let iso8601Fractional: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()
        let iso8601: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f
        }()
        let dateOnly: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let d = iso8601Fractional.date(from: string) { return d }
            if let d = iso8601.date(from: string) { return d }
            if let d = dateOnly.date(from: string) { return d }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(string)"
            )
        }
        return decoder
    }

    private static func postgrestEncoder() -> JSONEncoder {
        let formatter: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }
}
