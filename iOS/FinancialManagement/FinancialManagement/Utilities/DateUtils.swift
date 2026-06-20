import Foundation

enum DateUtils {
    private static let yearMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let yearMonthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// `YYYY-MM-DD` for writing a Postgres `date` column (no time component).
    static func yearMonthDay(from date: Date) -> String {
        yearMonthDayFormatter.string(from: date)
    }

    static func currentYearMonth() -> String {
        yearMonthFormatter.string(from: Date())
    }

    static func yearMonth(from date: Date) -> String {
        yearMonthFormatter.string(from: date)
    }

    static func navigate(_ yearMonth: String, by months: Int) -> String {
        guard let date = yearMonthFormatter.date(from: yearMonth),
              let result = Calendar.current.date(byAdding: .month, value: months, to: date)
        else { return yearMonth }
        return yearMonthFormatter.string(from: result)
    }

    static func formatYearMonth(_ yearMonth: String) -> String {
        guard let date = yearMonthFormatter.date(from: yearMonth) else { return yearMonth }
        return displayFormatter.string(from: date)
    }
}
