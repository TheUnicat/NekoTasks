//
//  CalendarFormatting.swift
//  NekoTasks
//
//  ── PURPOSE ──
//  Centralized date formatting utilities for the calendar feature. Extracted from
//  DateNavigator where formatters were being created inside computed properties
//  (which re-execute on every SwiftUI render pass).
//
//  ── WHY THIS EXISTS ──
//  DateFormatter is expensive to allocate. The original code created new formatters
//  on every call to `dateTitle` and `dateSubtitle`, which are evaluated on every
//  re-render. By using static cached formatters, we avoid repeated allocations.
//
//  ── USAGE ──
//  Called by DateNavigator, WeekHeaderRow, and TimeGutter for consistent formatting.
//  All methods are static — no instantiation needed.
//
//  ── AI CONTEXT ──
//  If you need a new date format anywhere in the calendar feature, add it here
//  rather than creating a new DateFormatter inline. Keep formatters as static lets.
//

import Foundation

enum CalendarFormatting {

    // MARK: - Cached Formatters

    private static let weekdayMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let dayOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private static let yearOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f
    }()

    private static let shortWeekday: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private static let hourPeriod: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h a"
        return f
    }()

    // MARK: - Public API

    /// Full weekday + abbreviated month + day, e.g. "Friday, Jan 24"
    static func weekdayMonthDayString(from date: Date) -> String {
        weekdayMonthDay.string(from: date)
    }

    /// Abbreviated month + day, e.g. "Jan 24"
    static func monthDayString(from date: Date) -> String {
        monthDay.string(from: date)
    }

    /// Day number only, e.g. "24"
    static func dayString(from date: Date) -> String {
        dayOnly.string(from: date)
    }

    /// Four-digit year, e.g. "2026"
    static func yearString(from date: Date) -> String {
        yearOnly.string(from: date)
    }

    /// Short weekday name uppercased, e.g. "MON"
    static func shortWeekdayString(from date: Date) -> String {
        shortWeekday.string(from: date).uppercased()
    }

    /// Hour with AM/PM, e.g. "9 AM"
    static func hourLabel(for hour: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return hourPeriod.string(from: date)
    }

    /// Formats a week range title, e.g. "Jan 20 – 26" or "Jan 28 – Feb 3"
    /// Collapses the month name when both dates share the same month.
    static func weekRangeTitle(start: Date, end: Date) -> String {
        let calendar = Calendar.current
        let startStr = monthDayString(from: start)
        if calendar.component(.month, from: start) == calendar.component(.month, from: end) {
            return "\(startStr) – \(dayString(from: end))"
        } else {
            return "\(startStr) – \(monthDayString(from: end))"
        }
    }

    /// Returns a relative label for dates near today, or the year for distant dates.
    static func relativeLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return yearString(from: date)
    }
}
