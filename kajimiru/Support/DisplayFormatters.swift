import Foundation
import KajimiruKit

enum DisplayFormatters {
    private static var localizedCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }()

    private static var dateIntervalFormatter: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = localizedCalendar
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func intervalDescription(_ interval: DateInterval) -> String {
        dateIntervalFormatter.string(from: interval.start, to: interval.end)
    }

    static func weightDescription(_ weight: Int) -> String {
        "大変度\(weight)"
    }
}
