import AppKit
import SwiftUI

@MainActor
final class ScheduleWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let model: AppModel
    var onClose: (() -> Void)?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: ScheduleView(model: model))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Schedule"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 520, height: 620))
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        }
        window?.center()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        let close = onClose
        Task { @MainActor in
            close?()
        }
    }
}

struct ScheduleView: View {
    var model: AppModel

    private let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        let _ = model.scheduleVersion
        VStack(alignment: .leading, spacing: 16) {
            Text("Work schedule")
                .font(.title2.weight(.semibold))
            Text("A short break is 15 seconds, every 15 minutes from the start of your shift. Every fourth break is 5 minutes. Breaks do not start at or after the shift ends.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(weekdayOrder, id: \.self) { weekday in
                dayRow(weekday)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 520, alignment: .leading)
    }

    @ViewBuilder
    private func dayRow(_ weekday: Int) -> some View {
        let day = model.day(weekday)
        VStack(alignment: .leading, spacing: 6) {
            Toggle(weekdayName(weekday), isOn: enabledBinding(weekday))
            HStack(spacing: 8) {
                DatePicker(
                    "Starts",
                    selection: timeBinding(weekday, keyPath: \.startMinutes),
                    displayedComponents: .hourAndMinute
                )
                DatePicker(
                    "Ends",
                    selection: timeBinding(weekday, keyPath: \.endMinutes),
                    displayedComponents: .hourAndMinute
                )
            }
            if day.enabled && day.endMinutes <= day.startMinutes {
                Text("End time has to be after the start time.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func weekdayName(_ weekday: Int) -> String {
        Calendar.current.weekdaySymbols[weekday - 1]
    }

    private func enabledBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { model.day(weekday).enabled },
            set: { enabled in
                model.updateDay(weekday: weekday) { $0.enabled = enabled }
            }
        )
    }

    private func timeBinding(_ weekday: Int, keyPath: WritableKeyPath<DaySchedule, Int>) -> Binding<Date> {
        Binding(
            get: { date(fromMinutes: model.day(weekday)[keyPath: keyPath]) },
            set: { newDate in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                let minutes = min(23 * 60 + 59, max(0, (parts.hour ?? 0) * 60 + (parts.minute ?? 0)))
                model.updateDay(weekday: weekday) { day in
                    day[keyPath: keyPath] = minutes
                }
            }
        )
    }

    private func date(fromMinutes minutes: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = minutes / 60
        components.minute = minutes % 60
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}
