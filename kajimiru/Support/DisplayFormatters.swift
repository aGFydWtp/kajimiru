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

    static func frequencyDescription(_ frequency: ChoreFrequency) -> String {
        switch frequency {
        case .onDemand:
            return "必要なとき"
        case let .recurring(rule):
            let base: String
            switch rule.period {
            case .daily:
                base = rule.interval == 1 ? "毎日" : "\(rule.interval)日ごと"
            case .weekly:
                base = rule.interval == 1 ? "毎週" : "\(rule.interval)週間ごと"
            case .monthly:
                base = rule.interval == 1 ? "毎月" : "\(rule.interval)か月ごと"
            }

            if let weekdays = weekdayListDescription(rule.weekdays) {
                return "\(base) (\(weekdays))"
            }
            return base
        case let .custom(description):
            return description
        }
    }

    static func categoryDescription(_ category: ChoreCategory) -> String {
        switch category {
        case .cleaning:
            return "掃除"
        case .laundry:
            return "洗濯"
        case .cooking:
            return "料理"
        case .shopping:
            return "買い物"
        case .maintenance:
            return "メンテナンス"
        case .other:
            return "その他"
        default:
            return category.rawValue.capitalized
        }
    }

    static func formattedDuration(optionalMinutes minutes: Int?) -> String? {
        guard let minutes else { return nil }
        return formattedDuration(minutes: minutes)
    }

    static func formattedDuration(minutes: Int) -> String {
        guard minutes > 0 else { return "0分" }
        let hours = minutes / 60
        let remaining = minutes % 60
        if hours > 0 {
            if remaining == 0 {
                return "\(hours)時間"
            }
            return "\(hours)時間\(remaining)分"
        }
        return "\(minutes)分"
    }

    private static func weekdayListDescription(_ weekdays: Set<Int>) -> String? {
        guard weekdays.isEmpty == false else { return nil }
        let symbols = localizedCalendar.shortWeekdaySymbols
        let items = weekdays
            .sorted()
            .compactMap { index -> String? in
                guard (1...7).contains(index) else { return nil }
                return symbols[index - 1]
            }
        guard items.isEmpty == false else { return nil }
        return items.joined(separator: "・")
    }
}
