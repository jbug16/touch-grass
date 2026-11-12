import AppKit
import SwiftUI
import TouchGrassCore

@main
struct TouchGrassApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel

    init() {
        let preview = CommandLine.arguments.contains("--preview-break") ? 3.0 : nil
        let model = AppModel(previewBreakAfter: preview)
        AppDelegate.onLaunch = {
            model.applicationDidFinishLaunching()
        }
        _model = State(initialValue: model)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            MenuLabel(model: model)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var onLaunch: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Self.onLaunch?()
    }
}

struct MenuLabel: View {
    var model: AppModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "tree.fill")
            if !model.menuTitle.isEmpty {
                Text(model.menuTitle)
                    .monospacedDigit()
            }
        }
        .fixedSize()
    }
}

struct MenuContent: View {
    var model: AppModel

    var body: some View {
        Text(model.statusLine)
        Divider()
        Button("Schedule…") {
            model.showSchedule()
        }
        Toggle("Launch at Login", isOn: Binding(
            get: { model.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
        ))
        if let loginMessage = model.loginMessage {
            Text(loginMessage)
        }
        Divider()
        Button("Quit Touch Grass") {
            NSApp.terminate(nil)
        }
        .onAppear {
            model.refreshLoginStatus()
        }
    }
}
