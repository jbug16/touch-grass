import Foundation

struct DaySchedule: Codable, Equatable, Sendable {
    var enabled: Bool
    var startMinutes: Int
    var endMinutes: Int

    var isValid: Bool {
        enabled && endMinutes > startMinutes
    }
}

struct WeeklySchedule: Codable, Equatable, Sendable {
    static let storageKey = "weeklySchedule"

    /// Index 0 is Sunday, matching `Calendar` weekday numbers.
    var days: [DaySchedule]

    static var standard: WeeklySchedule {
        let workday = DaySchedule(enabled: true, startMinutes: 9 * 60, endMinutes: 17 * 60)
        let dayOff = DaySchedule(enabled: false, startMinutes: 9 * 60, endMinutes: 17 * 60)
        return WeeklySchedule(days: [
            dayOff,
            workday,
            workday,
            workday,
            workday,
            workday,
            dayOff
        ])
    }

    func day(for weekday: Int) -> DaySchedule? {
        guard (1...7).contains(weekday) else { return nil }
        return days[weekday - 1]
    }

    static func load(from defaults: UserDefaults) -> WeeklySchedule {
        guard let data = defaults.data(forKey: storageKey),
              let schedule = try? JSONDecoder().decode(WeeklySchedule.self, from: data),
              schedule.days.count == 7
        else {
            return .standard
        }
        return schedule
    }

    func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
