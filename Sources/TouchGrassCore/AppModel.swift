import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class AppModel {
    public private(set) var menuTitle = ""
    public private(set) var statusLine = "No break scheduled"
    public private(set) var launchAtLogin = false
    public private(set) var loginMessage: String?
    private(set) var scheduleVersion = 0

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let panel = BreakPanelController()
    private var scheduleWindow: ScheduleWindowController?
    private var schedule: WeeklySchedule
    private var skippedTokens: Set<Int>
    private var previewBreak: ScheduledBreak?
    private var timer: Timer?
    private var wakeToken: NSObjectProtocol?
    private var clockToken: NSObjectProtocol?

    public init(defaults: UserDefaults = .standard, previewBreakAfter: TimeInterval? = nil) {
        self.defaults = defaults
        self.calendar = .current
        self.schedule = WeeklySchedule.load(from: defaults)
        self.skippedTokens = SkippedBreaks.load(from: defaults, now: Date())
        if let previewBreakAfter {
            previewBreak = ScheduledBreak(
                start: Date().addingTimeInterval(previewBreakAfter),
                kind: .short
            )
        }
        refreshLoginStatus()
        observeSystemChanges()
        tick()
        startTimer()
    }

    private func startTimer() {
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func applicationDidFinishLaunching() {
        if CommandLine.arguments.contains("--show-schedule") {
            showSchedule()
        }
    }

    public func showSchedule() {
        if scheduleWindow == nil {
            let controller = ScheduleWindowController(model: self)
            controller.onClose = { [weak self] in
                self?.scheduleWindow = nil
            }
            scheduleWindow = controller
        }
        scheduleWindow?.show()
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            loginMessage = LoginItem.statusMessage
        } catch {
            loginMessage = error.localizedDescription
        }
        launchAtLogin = LoginItem.isEnabled
    }

    public func refreshLoginStatus() {
        launchAtLogin = LoginItem.isEnabled
        loginMessage = LoginItem.statusMessage
    }

    func updateDay(weekday: Int, mutate: (inout DaySchedule) -> Void) {
        guard (1...7).contains(weekday) else { return }
        var next = schedule
        mutate(&next.days[weekday - 1])
        schedule = next
        schedule.save(to: defaults)
        scheduleVersion += 1
        tick()
    }

    func day(_ weekday: Int) -> DaySchedule {
        schedule.day(for: weekday) ?? DaySchedule(enabled: false, startMinutes: 9 * 60, endMinutes: 17 * 60)
    }

    private func skipCurrent() {
        guard let active = currentActiveBreak() else {
            panel.dismiss()
            return
        }
        skippedTokens.insert(active.startToken)
        skippedTokens = SkippedBreaks.prune(skippedTokens, now: Date())
        SkippedBreaks.save(skippedTokens, to: defaults)
        if previewBreak?.startToken == active.startToken {
            previewBreak = nil
        }
        Task { @MainActor in
            self.panel.dismiss()
            self.tick()
        }
    }

    private func currentActiveBreak() -> ScheduledBreak? {
        let now = Date()
        if let previewBreak, now >= previewBreak.start, now < previewBreak.end,
           !skippedTokens.contains(previewBreak.startToken) {
            return previewBreak
        }
        return BreakScheduler.activeBreak(
            at: now,
            weekly: schedule,
            calendar: calendar,
            skipped: skippedTokens
        )
    }

    private func tick() {
        let now = Date()
        if let preview = previewBreak, skippedTokens.contains(preview.startToken) || now >= preview.end {
            previewBreak = nil
        }

        var active = BreakScheduler.activeBreak(
            at: now,
            weekly: schedule,
            calendar: calendar,
            skipped: skippedTokens
        )
        var upcoming = BreakScheduler.upcomingBreakToday(
            after: now,
            weekly: schedule,
            calendar: calendar,
            skipped: skippedTokens
        )

        if let preview = previewBreak {
            if now >= preview.start && now < preview.end {
                active = preview
            } else if now < preview.start {
                upcoming = preview
                active = nil
            }
        }

        if let active, active.end.timeIntervalSince(now) >= 1 {
            let name = active.kind == .long ? "Long break" : "Short break"
            setMenu(title: "Break", status: name)
            panel.present(active) { [weak self] in
                self?.skipCurrent()
            }
        } else {
            panel.dismiss()
            if let upcoming {
                let time = upcoming.start.formatted(date: .omitted, time: .shortened)
                let name = upcoming.kind == .long ? "long" : "short"
                setMenu(
                    title: BreakFormatting.minutes(upcoming.start.timeIntervalSince(now)),
                    status: "Next break \(time) · \(name)"
                )
            } else {
                setMenu(title: "", status: offStatus(at: now))
            }
        }
    }

    private func setMenu(title: String, status: String) {
        if menuTitle != title { menuTitle = title }
        if statusLine != status { statusLine = status }
    }

    private func offStatus(at now: Date) -> String {
        let weekday = calendar.component(.weekday, from: now)
        guard let day = schedule.day(for: weekday), day.isValid else { return "Off" }
        let dayStart = calendar.startOfDay(for: now)
        guard let shiftEnd = calendar.date(byAdding: .minute, value: day.endMinutes, to: dayStart) else {
            return "Off"
        }
        return now >= shiftEnd ? "Shift's over" : "Off"
    }

    private func observeSystemChanges() {
        wakeToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        clockToken = NotificationCenter.default.addObserver(
            forName: Notification.Name.NSSystemClockDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
}
