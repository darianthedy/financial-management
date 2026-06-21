import Foundation

enum AppConfig {
    static let supabaseURL: URL = {
        let value = infoValue("SUPABASE_URL")
        guard let url = URL(string: value) else {
            fatalError(configError("SUPABASE_URL", detail: "value \"\(value)\" is not a valid URL"))
        }
        return url
    }()

    static let supabaseAnonKey = infoValue("SUPABASE_ANON_KEY")

    private static func infoValue(_ key: String) -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String, !value.isEmpty else {
            fatalError(configError(key, detail: "missing or empty"))
        }
        return value
    }

    private static func configError(_ key: String, detail: String) -> String {
        """
        AppConfig: \(key) is \(detail). The \(key) build setting was not supplied at \
        build time. Set it in Config/Dev.xcconfig / Config/Prod.xcconfig for local \
        builds, or pass it via the CI secret (fastlane xcargs) for TestFlight builds.
        """
    }
}
