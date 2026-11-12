import AppKit
import SwiftUI

@MainActor
final class BreakPanelController {
    private var panel: NSPanel?
    private var shownToken: Int?
    private var eventMonitor: Any?
    private var onSkip: (() -> Void)?

    func present(_ item: ScheduledBreak, onSkip: @escaping () -> Void) {
        if shownToken == item.startToken, panel?.isVisible == true {
            return
        }
        dismiss()
        self.onSkip = onSkip

        let root = NSView(frame: NSRect(origin: .zero, size: BreakPanelMetrics.windowSize))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.clear.cgColor
        root.layer?.isOpaque = false

        let cardFrame = NSRect(
            x: BreakPanelMetrics.margin,
            y: BreakPanelMetrics.margin,
            width: BreakPanelMetrics.card.width,
            height: BreakPanelMetrics.card.height
        )
        let backdrop = NSVisualEffectView(frame: NSRect(origin: .zero, size: cardFrame.size))
        backdrop.material = .hudWindow
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.wantsLayer = true
        backdrop.layer?.cornerRadius = BreakPanelMetrics.radius
        backdrop.layer?.cornerCurve = .continuous
        backdrop.layer?.masksToBounds = true
        let mask = CAShapeLayer()
        mask.path = CGPath(
            roundedRect: backdrop.bounds,
            cornerWidth: BreakPanelMetrics.radius,
            cornerHeight: BreakPanelMetrics.radius,
            transform: nil
        )
        backdrop.layer?.mask = mask

        let shadowHost = NSView(frame: cardFrame)
        shadowHost.wantsLayer = true
        shadowHost.layer?.shadowColor = NSColor.black.cgColor
        shadowHost.layer?.shadowOpacity = 0.22
        shadowHost.layer?.shadowRadius = 24
        shadowHost.layer?.shadowOffset = CGSize(width: 0, height: -8)
        shadowHost.layer?.shadowPath = CGPath(
            roundedRect: shadowHost.bounds,
            cornerWidth: BreakPanelMetrics.radius,
            cornerHeight: BreakPanelMetrics.radius,
            transform: nil
        )
        shadowHost.addSubview(backdrop)

        let hosting = ClearHostingView(rootView: BreakOverlay(item: item, onSkip: { [weak self] in
            self?.onSkip?()
        }))
        hosting.frame = backdrop.bounds
        hosting.autoresizingMask = [.width, .height]
        backdrop.addSubview(hosting)
        root.addSubview(shadowHost)

        let panel = NSPanel(
            contentRect: root.frame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = root
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.worksWhenModal = true

        self.panel = panel
        self.shownToken = item.startToken
        place(panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
        installEscapeMonitor()
    }

    func dismiss() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
        shownToken = nil
        onSkip = nil
    }

    private func place(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let screen else {
            panel.center()
            return
        }
        let visible = screen.visibleFrame
        var frame = panel.frame
        frame.origin.x = visible.midX - frame.width / 2
        frame.origin.y = visible.midY - frame.height / 2
        panel.setFrame(frame, display: true)
    }

    private func installEscapeMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, self?.panel?.isVisible == true else { return event }
            self?.onSkip?()
            return nil
        }
    }
}

private enum BreakPanelMetrics {
    static let card = NSSize(width: 420, height: 300)
    static let margin: CGFloat = 40
    static let radius: CGFloat = 28
    static var windowSize: NSSize {
        NSSize(width: card.width + margin * 2, height: card.height + margin * 2)
    }
}

private final class ClearHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
    }
}

private struct BreakOverlay: View {
    let item: ScheduledBreak
    let onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            let remaining = max(0, item.end.timeIntervalSince(context.date))
            VStack(spacing: 12) {
                Image(systemName: "tree.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.green)
                Text("Touch grass")
                    .font(.title2.weight(.semibold))
                Text(item.kind == .long ? "Long break" : "Short break")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(BreakFormatting.countdown(remaining))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .padding(.top, 4)
                Button("Skip", action: onSkip)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("skip-break")
            }
            .padding(28)
            .frame(width: BreakPanelMetrics.card.width, height: BreakPanelMetrics.card.height)
            .background(Color.clear)
        }
    }
}
