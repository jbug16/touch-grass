import Foundation
import Testing
@testable import TouchGrassCore

struct BreakSchedulerTests {
    private let calendar: Calendar

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        self.calendar = calendar
    }

    @Test func referenceMonday() {
        let weekday = calendar.component(.weekday, from: date(2026, 11, 9, 9, 0))
        #expect(weekday == 2)
    }

    @Test func breaksEveryFifteenMinutesFromShiftStart() {
        let items = workdayBreaks()
        #expect(items.count == 31)
        #expect(items[0].start == date(2026, 11, 9, 9, 15))
        #expect(items[0].kind == .short)
        #expect(items[0].duration == 15)
        #expect(items[1].start == date(2026, 11, 9, 9, 30))
        #expect(items[2].start == date(2026, 11, 9, 9, 45))
    }

    @Test func fourthBreakIsLong() {
        let items = workdayBreaks()
        #expect(items[3].start == date(2026, 11, 9, 10, 0))
        #expect(items[3].kind == .long)
        #expect(items[3].duration == 5 * 60)
        #expect(items[7].kind == .long)
        #expect(items[4].kind == .short)
    }

    @Test func noBreakAtOrAfterShiftEnd() {
        let items = workdayBreaks()
        let startsAtShiftEnd = items.contains { item in
            calendar.component(.hour, from: item.start) == 17
                && calendar.component(.minute, from: item.start) == 0
        }
        #expect(!startsAtShiftEnd)

        let exactEnd = BreakScheduler.breaks(
            for: date(2026, 11, 9, 0, 0),
            schedule: DaySchedule(enabled: true, startMinutes: 9 * 60, endMinutes: 9 * 60 + 15),
            calendar: calendar
        )
        #expect(exactEnd.isEmpty)

        let oneMinutePast = BreakScheduler.breaks(
            for: date(2026, 11, 9, 0, 0),
            schedule: DaySchedule(enabled: true, startMinutes: 9 * 60, endMinutes: 9 * 60 + 16),
            calendar: calendar
        )
        #expect(oneMinutePast.map(\.start) == [date(2026, 11, 9, 9, 15)])
    }

    @Test func lastBreakIs1645() {
        let items = workdayBreaks()
        #expect(items.last?.start == date(2026, 11, 9, 16, 45))
        #expect(items.last?.kind == .short)
    }

    @Test func disabledDayHasNoBreaks() {
        let items = BreakScheduler.breaks(
            for: date(2026, 11, 14, 12, 0),
            schedule: DaySchedule(enabled: false, startMinutes: 9 * 60, endMinutes: 17 * 60),
            calendar: calendar
        )
        #expect(items.isEmpty)
    }

    @Test func endBeforeStartHasNoBreaks() {
        let items = BreakScheduler.breaks(
            for: date(2026, 11, 9, 12, 0),
            schedule: DaySchedule(enabled: true, startMinutes: 17 * 60, endMinutes: 9 * 60),
            calendar: calendar
        )
        #expect(items.isEmpty)
    }

    @Test func nextAndActiveAround920() {
        let now = date(2026, 11, 9, 9, 20)
        let weekly = standardWeek()
        #expect(BreakScheduler.activeBreak(at: now, weekly: weekly, calendar: calendar) == nil)
        let next = BreakScheduler.nextBreak(after: now, weekly: weekly, calendar: calendar)
        #expect(next?.start == date(2026, 11, 9, 9, 30))
        #expect(next?.kind == .short)
    }

    @Test func activeShortBreak() {
        let now = date(2026, 11, 9, 9, 15, 5)
        let active = BreakScheduler.activeBreak(at: now, weekly: standardWeek(), calendar: calendar)
        #expect(active?.kind == .short)
        #expect(abs((active?.end.timeIntervalSince(now) ?? 0) - 10) < 0.001)
    }

    @Test func activeLongBreak() {
        let now = date(2026, 11, 9, 10, 2)
        let active = BreakScheduler.activeBreak(at: now, weekly: standardWeek(), calendar: calendar)
        #expect(active?.kind == .long)
        #expect(active?.start == date(2026, 11, 9, 10, 0))
    }

    @Test func skippedBreakAdvancesToNextSlot() {
        let now = date(2026, 11, 9, 9, 15, 5)
        let skippedStart = date(2026, 11, 9, 9, 15)
        let skipped: Set<Int> = [Int(skippedStart.timeIntervalSince1970.rounded())]
        #expect(BreakScheduler.activeBreak(at: now, weekly: standardWeek(), calendar: calendar, skipped: skipped) == nil)
        let next = BreakScheduler.nextBreak(after: now, weekly: standardWeek(), calendar: calendar, skipped: skipped)
        #expect(next?.start == date(2026, 11, 9, 9, 30))
    }

    @Test func wakeAfterShortBreakLooksAhead() {
        let now = date(2026, 11, 9, 9, 16)
        let weekly = standardWeek()
        #expect(BreakScheduler.activeBreak(at: now, weekly: weekly, calendar: calendar) == nil)
        #expect(BreakScheduler.nextBreak(after: now, weekly: weekly, calendar: calendar)?.start == date(2026, 11, 9, 9, 30))
    }

    @Test func shiftStartingOffTheHour() {
        let items = BreakScheduler.breaks(
            for: date(2026, 11, 9, 0, 0),
            schedule: DaySchedule(enabled: true, startMinutes: 9 * 60 + 7, endMinutes: 17 * 60),
            calendar: calendar
        )
        #expect(items[0].start == date(2026, 11, 9, 9, 22))
        #expect(items[0].kind == .short)
        #expect(items[3].start == date(2026, 11, 9, 10, 7))
        #expect(items[3].kind == .long)
    }

    @Test func saturdayLooksAheadToMonday() {
        let now = date(2026, 11, 14, 10, 0)
        let next = BreakScheduler.nextBreak(after: now, weekly: standardWeek(), calendar: calendar)
        #expect(next?.start == date(2026, 11, 16, 9, 15))
    }

    @Test func countdownFormat() {
        #expect(BreakFormatting.countdown(15) == "0:15")
        #expect(BreakFormatting.countdown(90) == "1:30")
        #expect(BreakFormatting.countdown(3661) == "1:01:01")
        #expect(BreakFormatting.countdown(0) == "0:00")
        #expect(BreakFormatting.countdown(-3) == "0:00")
        #expect(BreakFormatting.minutes(15) == "1m")
        #expect(BreakFormatting.minutes(90) == "2m")
        #expect(BreakFormatting.minutes(60) == "1m")
        #expect(BreakFormatting.minutes(0) == "0m")
    }

    @Test func afterShiftEndThereIsNoBreakToday() {
        let now = date(2026, 11, 9, 17, 5)
        let weekly = standardWeek()
        #expect(BreakScheduler.nextBreak(after: now, weekly: weekly, calendar: calendar)?.start == date(2026, 11, 10, 9, 15))
        #expect(BreakScheduler.upcomingBreakToday(after: now, weekly: weekly, calendar: calendar) == nil)
    }

    @Test func duringShiftTheNextBreakIsToday() {
        let now = date(2026, 11, 9, 9, 20)
        let next = BreakScheduler.upcomingBreakToday(after: now, weekly: standardWeek(), calendar: calendar)
        #expect(next?.start == date(2026, 11, 9, 9, 30))
    }

    @Test func scheduleRoundTrip() {
        let suite = "TouchGrassTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        var schedule = WeeklySchedule.standard
        schedule.days[2].enabled = true
        schedule.days[2].startMinutes = 10 * 60
        schedule.days[2].endMinutes = 18 * 60
        schedule.save(to: defaults)

        #expect(WeeklySchedule.load(from: defaults) == schedule)

        defaults.set(Data("nope".utf8), forKey: WeeklySchedule.storageKey)
        #expect(WeeklySchedule.load(from: defaults) == .standard)
    }

    @Test func skippedTokensPruneAndRoundTrip() {
        let now = date(2026, 11, 9, 12, 0)
        let recent = Int(now.addingTimeInterval(-3600).timeIntervalSince1970)
        let old = Int(now.addingTimeInterval(-50 * 3600).timeIntervalSince1970)
        #expect(SkippedBreaks.prune([recent, old], now: now) == [recent])

        let suite = "TouchGrassTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        SkippedBreaks.save([recent, old], to: defaults)
        #expect(SkippedBreaks.load(from: defaults, now: now) == [recent])
    }

    private func workdayBreaks() -> [ScheduledBreak] {
        BreakScheduler.breaks(
            for: date(2026, 11, 9, 12, 0),
            schedule: DaySchedule(enabled: true, startMinutes: 9 * 60, endMinutes: 17 * 60),
            calendar: calendar
        )
    }

    private func standardWeek() -> WeeklySchedule {
        let workday = DaySchedule(enabled: true, startMinutes: 9 * 60, endMinutes: 17 * 60)
        let dayOff = DaySchedule(enabled: false, startMinutes: 9 * 60, endMinutes: 17 * 60)
        return WeeklySchedule(days: [dayOff, workday, workday, workday, workday, workday, dayOff])
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return calendar.date(from: components)!
    }
}
