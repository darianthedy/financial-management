#if DEBUG
import Foundation

/// Debug-only fixture backend (iPhone Duo plan D0.3).
///
/// With `DUO_FIXTURES=1` in the environment, `SupabaseService` routes every
/// HTTP request through `FixtureURLProtocol` and loads a fake signed-in session,
/// so real screens render with canned data and no network. Used by the layout
/// tests (the test scheme sets it) and the gate screenshot runs.
nonisolated enum FixtureMode {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["DUO_FIXTURES"] == "1"
    }

    /// A `URLSession` whose requests are all answered by `FixtureURLProtocol`.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixtureURLProtocol.self]
        return URLSession(configuration: config)
    }
}

/// Answers Supabase REST, RPC and Auth requests from `FixtureStore`, applying
/// the PostgREST filters the app uses (`eq`, `neq`, `gt(e)`, `lt(e)`, `is`,
/// `in`), plus `order` and `limit`. Writes are accepted and echoed back but not
/// stored. Unknown tables answer `[]` (the screen's empty state).
nonisolated final class FixtureURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme else { return false }
        return scheme == "http" || scheme == "https"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (status, body) = Self.respond(to: request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Content-Range": "0-\(max(Self.lastCount - 1, 0))/\(Self.lastCount)",
            ]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    // MARK: - Routing

    /// Row count of the last REST response, for the `Content-Range` header.
    nonisolated(unsafe) private static var lastCount = 0

    static func respond(to request: URLRequest) -> (Int, Data) {
        guard let url = request.url else { return (400, Data("{}".utf8)) }
        let path = url.path

        if path.hasPrefix("/auth/v1/") {
            return auth(path: String(path.dropFirst("/auth/v1/".count)))
        }
        if path.hasPrefix("/rest/v1/") {
            return rest(request, resource: String(path.dropFirst("/rest/v1/".count)))
        }
        // Storage (account avatars) and anything else: not found, so views
        // fall back to their placeholders.
        return (404, Data(#"{"message":"fixture: not found"}"#.utf8))
    }

    private static func auth(path: String) -> (Int, Data) {
        switch path {
        case "user":
            return (200, json(FixtureStore.user))
        case "token":
            return (200, json(FixtureStore.session))
        case "logout":
            return (204, Data())
        default:
            return (200, Data("{}".utf8))
        }
    }

    private static func rest(_ request: URLRequest, resource: String) -> (Int, Data) {
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let wantsObject = request.value(forHTTPHeaderField: "Accept")?.contains("vnd.pgrst.object") == true
        var rows = FixtureStore.rows(for: resource).filter { row in
            query.allSatisfy { PostgRESTFilter.matches(row, $0) }
        }

        // RPCs are POSTs but reads: their body holds parameters, not a row.
        let method = resource.hasPrefix("rpc/") ? "GET" : (request.httpMethod ?? "GET")
        switch method {
        case "POST", "PATCH", "PUT":
            // Echo the write merged onto the matching (or first) stored row, so
            // `.select().single()` after an upsert decodes a complete object.
            let template = rows.first ?? FixtureStore.rows(for: resource).first ?? [:]
            rows = writtenObjects(request).map { template.merging($0) { _, new in new } }
        case "DELETE":
            break
        default:
            PostgRESTFilter.order(&rows, query)
            PostgRESTFilter.limit(&rows, query)
        }

        lastCount = rows.count
        if wantsObject {
            guard let first = rows.first else {
                return (406, Data(#"{"code":"PGRST116","message":"fixture: no rows"}"#.utf8))
            }
            return (200, json(first))
        }
        return (200, json(rows))
    }

    private static func writtenObjects(_ request: URLRequest) -> [[String: Any]] {
        guard let data = request.httpBody ?? request.httpBodyStream.map(readAll),
              let object = try? JSONSerialization.jsonObject(with: data)
        else { return [[:]] }
        if let array = object as? [[String: Any]] { return array }
        if let dict = object as? [String: Any] { return [dict] }
        return [[:]]
    }

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }

    private static func json(_ object: Any) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data("null".utf8)
    }
}

/// The subset of PostgREST query semantics the app's queries rely on.
nonisolated enum PostgRESTFilter {
    private static let reserved: Set<String> = ["select", "order", "limit", "offset", "on_conflict", "columns"]

    static func matches(_ row: [String: Any], _ item: URLQueryItem) -> Bool {
        guard !reserved.contains(item.name), let raw = item.value,
              let dot = raw.firstIndex(of: ".")
        else { return true }
        let op = String(raw[..<dot])
        let operand = String(raw[raw.index(after: dot)...])
        let value = text(row[item.name])

        switch op {
        // Case-insensitive: Swift encodes UUIDs uppercase, the store holds lowercase.
        case "eq": return value?.lowercased() == operand.lowercased()
        case "neq": return value?.lowercased() != operand.lowercased()
        case "is":
            switch operand {
            case "null": return value == nil
            case "true", "false": return value == operand
            default: return true
            }
        case "in":
            let list = operand.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" ")).lowercased() }
            return value.map { list.contains($0.lowercased()) } ?? false
        case "gt": return compare(value, operand).map { $0 > 0 } ?? false
        case "gte": return compare(value, operand).map { $0 >= 0 } ?? false
        case "lt": return compare(value, operand).map { $0 < 0 } ?? false
        case "lte": return compare(value, operand).map { $0 <= 0 } ?? false
        default: return true // or/and/cs/ilike…: don't filter
        }
    }

    static func order(_ rows: inout [[String: Any]], _ query: [URLQueryItem]) {
        guard let spec = query.first(where: { $0.name == "order" })?.value?
            .split(separator: ",").first
        else { return }
        let parts = spec.split(separator: ".")
        let column = String(parts.first ?? "")
        let descending = parts.contains("desc")
        rows.sort { a, b in
            let order = compare(text(a[column]), text(b[column]) ?? "") ?? 0
            return descending ? order > 0 : order < 0
        }
    }

    static func limit(_ rows: inout [[String: Any]], _ query: [URLQueryItem]) {
        if let limit = query.first(where: { $0.name == "limit" })?.value.flatMap(Int.init) {
            rows = Array(rows.prefix(limit))
        }
    }

    /// Numeric when both sides are numbers, else lexical (dates and
    /// `year_month` strings sort correctly lexically).
    private static func compare(_ lhs: String?, _ rhs: String) -> Int? {
        guard let lhs else { return nil }
        if let l = Double(lhs), let r = Double(rhs) { return l < r ? -1 : (l > r ? 1 : 0) }
        return lhs < rhs ? -1 : (lhs > rhs ? 1 : 0)
    }

    private static func text(_ value: Any?) -> String? {
        switch value {
        case nil, is NSNull: nil
        case let b as Bool: b ? "true" : "false"
        case let s as String: s
        case let n as NSNumber: n.stringValue
        default: String(describing: value!)
        }
    }
}
#endif
