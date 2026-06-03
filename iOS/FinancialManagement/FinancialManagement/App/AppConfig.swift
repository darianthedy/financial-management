import Foundation

enum AppConfig {
    static let supabaseURL = URL(string: Bundle.main.infoDictionary!["SUPABASE_URL"] as! String)!
    static let supabaseAnonKey = Bundle.main.infoDictionary!["SUPABASE_ANON_KEY"] as! String
}
