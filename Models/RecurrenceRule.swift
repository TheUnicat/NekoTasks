//
//  RecurrenceRule.swift
//  NekoTasks
//
//  Created by TheUnicat on 1/24/26.
//
//  CLAUDE NOTES:
//  Recurrence rule engine. Three main types:
//  - Weekday enum (Sun=1..Sat=7, matches Calendar.component(.weekday))
//  - RecurrenceContext: wraps a Date and provides weekday, dayOfMonth, weekOfMonth, weekOfYear, isLastWeekOfMonth
//  - AnyRule (indirect enum, Codable): composite pattern with .weekdays, .daysOfMonth, .weekOfMonth,
//    .everyOtherWeek, .dateRange, .and/.or/.not. Has matches(context:), toJSON(), operator overloads (&&, ||, !).
//  WeekOfMonthRule is a helper struct for .weekOfMonth case.
//  Rules are serialized to JSON and stored in TaskItem.recurrenceRuleString.
//

import Foundation

// MARK: - Weekday

enum Weekday: Int, Codable, CaseIterable, Identifiable, Equatable, Hashable, CustomStringConvertible {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var description: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    static var weekdays: Set<Weekday> {
        [.monday, .tuesday, .wednesday, .thursday, .friday]
    }
}

// MARK: - Recurrence Context

struct RecurrenceContext {
    let date: Date
    let calendar: Calendar

    init(date: Date, calendar: Calendar = .current) {
        self.date = date
        self.calendar = calendar
    }

    var weekday: Weekday? {
        let component = calendar.component(.weekday, from: date)
        return Weekday(rawValue: component)
    }

    var dayOfMonth: Int {
        calendar.component(.day, from: date)
    }

    var weekOfMonth: Int {
        calendar.component(.weekOfMonth, from: date)
    }

    var weekOfYear: Int {
        calendar.component(.weekOfYear, from: date)
    }

    var isLastWeekOfMonth: Bool {
        guard let nextWeek = calendar.date(byAdding: .weekOfMonth, value: 1, to: date) else {
            return false
        }
        return calendar.component(.month, from: nextWeek) != calendar.component(.month, from: date)
    }
}

// MARK: - Any Rule (Composite Pattern)

indirect enum AnyRule: Codable, Equatable {
    case weekdays(Set<Weekday>)
    case daysOfMonth([Int])
    case weekOfMonth(WeekOfMonthRule)
    case everyOtherWeek(startingWeek: Int)
    case dateRange(start: Date, end: Date)
    case and(AnyRule, AnyRule)
    case or(AnyRule, AnyRule)
    case not(AnyRule)

    func matches(context: RecurrenceContext) -> Bool {
        switch self {
        case .weekdays(let days):
            guard let weekday = context.weekday else { return false }
            return days.contains(weekday)

        case .daysOfMonth(let days):
            return days.contains(context.dayOfMonth)

        case .weekOfMonth(let rule):
            if rule.weeks.contains(context.weekOfMonth) {
                return true
            }
            if rule.includesLast && context.isLastWeekOfMonth {
                return true
            }
            return false

        case .everyOtherWeek(let startingWeek):
            let weekNumber = context.weekOfYear
            return (weekNumber - startingWeek) % 2 == 0

        case .dateRange(let start, let end):
            let startOfDay = context.calendar.startOfDay(for: context.date)
            let startOfStart = context.calendar.startOfDay(for: start)
            let startOfEnd = context.calendar.startOfDay(for: end)
            return startOfDay >= startOfStart && startOfDay <= startOfEnd

        case .and(let left, let right):
            return left.matches(context: context) && right.matches(context: context)

        case .or(let left, let right):
            return left.matches(context: context) || right.matches(context: context)

        case .not(let rule):
            return !rule.matches(context: context)
        }
    }

    func toJSON() -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // Convenience constructors
    static func on(_ weekdays: Set<Weekday>) -> AnyRule {
        .weekdays(weekdays)
    }

    static func on(_ weekday: Weekday) -> AnyRule {
        .weekdays([weekday])
    }

    static func onDays(_ days: Int...) -> AnyRule {
        .daysOfMonth(days)
    }

    static func inWeeks(_ weeks: Int...) -> AnyRule {
        .weekOfMonth(WeekOfMonthRule(weeks: weeks, includesLast: false))
    }

    static func between(start: Date, end: Date) -> AnyRule {
        .dateRange(start: start, end: end)
    }

    static func && (lhs: AnyRule, rhs: AnyRule) -> AnyRule {
        .and(lhs, rhs)
    }

    static func || (lhs: AnyRule, rhs: AnyRule) -> AnyRule {
        .or(lhs, rhs)
    }

    static prefix func ! (rule: AnyRule) -> AnyRule {
        .not(rule)
    }
}

// MARK: - Week of Month Rule

struct WeekOfMonthRule: Codable, Equatable {
    let weeks: [Int]
    let includesLast: Bool

    init(weeks: [Int], includesLast: Bool = false) {
        self.weeks = weeks
        self.includesLast = includesLast
    }
}
