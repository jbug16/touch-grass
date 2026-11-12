import Foundation
import ServiceManagement

enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusMessage: String? {
        message(for: SMAppService.mainApp.status)
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func message(for status: SMAppService.Status) -> String? {
        switch status {
        case .enabled, .notRegistered:
            return nil
        case .requiresApproval:
            return "Allow Touch Grass in System Settings → General → Login Items."
        case .notFound:
            return "Move Touch Grass.app into /Applications, then turn this on again."
        @unknown default:
            return nil
        }
    }
}
