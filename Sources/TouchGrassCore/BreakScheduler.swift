import Foundation

enum BreakKind: Equatable, Sendable {
    case short
    case long

    var duration: TimeInterval {
        switch self {
        case .short:
            return BreakScheduler.shortDuration
        case .long:
            return BreakScheduler.longDuration
        }
    }
}

struct ScheduledBreak: Equatable, Sendable {
    let start: Date
    let kind: BreakKind

    var duration: TimeInterval { kind.duration }
    var end: Date { start.addingTimeInterval(duration) }
    var startToken: Int { Int(start.timeIntervalSince1970.rounded()) }
}

enum BreakScheduler {
    static let interval: TimeInterval = 15 * 60
    static let shortDuration: TimeInterval = 15
    static let longDuration: TimeInterval = 5 * 60
    static let longEvery = 4

    static func breaks(for day: Date, schedule: DaySchedule, calendar: Calendar) -> [ScheduledBreak] {
        guard schedule.isValid else { return [] }
        guard (0...24 * 60).contains(schedule.startMinutes),
              (0...24 * 60).contains(schedule.endMinutes)
        else {
            return []
        }

        let dayStart = calendar.startOfDay(for: day)
        guard let shiftStart = calendar.date(byAdding: .minute, value: schedule.startMinutes, to: dayStart),
              let shiftEnd = calendar.date(byAdding: .minute, value: schedule.endMinutes, to: dayStart)
        else {
            return []
        }

        var items: [ScheduledBreak] = []
        var cursor = shiftStart
        var index = 1
        while index <= 24 * 4,
              let next = calendar.date(byAdding: .minute, value: 15, to: cursor) {
            if next >= shiftEnd { break }
            let kind: BreakKind = index.isMultiple(of: longEvery) ? .long : .short
            items.append(ScheduledBreak(start: next, kind: kind))
            cursor = next
            index += 1
        }
        return items
    }

    static func activeBreak(
        at date: Date,
        weekly: WeeklySchedule,
        calendar: Calendar,
        skipped: Set<Int> = []
    ) -> ScheduledBreak? {
        let days = [-1, 0].compactMap { calendar.date(byAdding: .day, value: $0, to: date) }
        for day in days {
            let weekday = calendar.component(.weekday, from: day)
            guard let schedule = weekly.day(for: weekday) else { continue }
            for item in breaks(for: day, schedule: schedule, calendar: calendar) {
                if skipped.contains(item.startToken) { continue }
                if item.start <= date && date < item.end {
                    return item
                }
            }
        }
        return nil
    }

    static func nextBreak(
        after date: Date,
        weekly: WeeklySchedule,
        calendar: Calendar,
        skipped: Set<Int> = []
    ) -> ScheduledBreak? {
        for offset in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            guard let schedule = weekly.day(for: weekday) else { continue }
            for item in breaks(for: day, schedule: schedule, calendar: calendar) {
                if item.start <= date { continue }
                if skipped.contains(item.startToken) { continue }
                return item
            }
        }
        return nil
    }

    /// The next break only counts while it is still later today. After the shift ends, the next one is another day.
    static func upcomingBreakToday(
        after date: Date,
        weekly: WeeklySchedule,
        calendar: Calendar,
        skipped: Set<Int> = []
    ) -> ScheduledBreak? {
        guard let next = nextBreak(after: date, weekly: weekly, calendar: calendar, skipped: skipped),
              calendar.isDate(next.start, inSameDayAs: date)
        else {
            return nil
        }
        return next
    }
}

enum BreakFormatting {
    static func countdown(_ interval: TimeInterval) -> String {
        let remaining = max(0, Int(interval.rounded(.down)))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Whole minutes for the menu bar. A partial minute still shows as 1m so the label does not tick every second.
    static func minutes(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "0m" }
        let rounded = Int((interval / 60).rounded(.up))
        return "\(max(rounded, 1))m"
    }
}

enum SkippedBreaks {
    static let storageKey = "skippedBreakStarts"
    static let retention: TimeInterval = 48 * 60 * 60

    static func prune(_ tokens: Set<Int>, now: Date, keeping: TimeInterval = retention) -> Set<Int> {
        let cutoff = Int(now.addingTimeInterval(-keeping).timeIntervalSince1970)
        return tokens.filter { $0 >= cutoff }
    }

    static func load(from defaults: UserDefaults, now: Date) -> Set<Int> {
        let stored = defaults.array(forKey: storageKey) as? [Int] ?? []
        return prune(Set(stored), now: now)
    }

    static func save(_ tokens: Set<Int>, to defaults: UserDefaults) {
        defaults.set(Array(tokens).sorted(), forKey: storageKey)
    }
}
