import Foundation

/// JSON coders mirroring `SupabaseService`'s PostgREST encoder/decoder so the
/// model round-trip tests exercise the same date handling the live client uses:
/// ISO-8601 (with or without fractional seconds) and bare `yyyy-MM-dd` dates.
enum TestCoders {
    static let decoder: JSONDecoder = {
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
    }()

    static let encoder: JSONEncoder = {
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
    }()
}
