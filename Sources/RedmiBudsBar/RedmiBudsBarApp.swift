import AppKit
import Observation
import SwiftUI

/// Hosting view that reports ideal-size changes so the panel can follow its SwiftUI content.
private final class SizeReportingHostingView<Content: View>: NSHostingView<Content> {
    var onIntrinsicSizeChange: (() -> Void)?

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        onIntrinsicSizeChange?()
    }
}

/// Borderless floating panel that can take key focus (menus, Escape) without activating the app.
private final class PopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: BudsViewModel!
    private var statusItem: NSStatusItem!
    private var panel: PopupPanel?
    private var hostingView: SizeReportingHostingView<PanelView>?
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var isClosing = false

    private static let gap: CGFloat = 4
    private static let screenMargin: CGFloat = 8

    /// `earbuds` exists on recent SF Symbols versions; fall back to headphones otherwise.
    private static let symbolName: String =
        NSImage(systemSymbolName: "earbuds", accessibilityDescription: nil) != nil ? "earbuds" : "headphones"

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Menu bar only, also when launched outside an app bundle (LSUIElement covers the bundled case).
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = BudsViewModel()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: Self.symbolName, accessibilityDescription: "REDMI Buds")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePanel)
        }
        updateStatusItem()
        observeModel()
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateStatusItem() }
        }
        LaunchAtLogin.applyDefaultOnFirstRun()
    }

    // MARK: Status item

    /// Re-arms an observation of everything the status item shows, so it updates live.
    private func observeModel() {
        withObservationTracking {
            _ = lowestBattery
            _ = model.connection
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateStatusItem()
                self?.observeModel()
            }
        }
    }

    private var lowestBattery: Int? {
        let battery = model.state.battery
        return [battery.left?.percent, battery.right?.percent].compactMap { $0 }.min()
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        let showBattery = UserDefaults.standard.object(forKey: "showBatteryInMenuBar") as? Bool ?? true
        if showBattery, model.connection == .connected, let percent = lowestBattery {
            button.title = " \(percent)%"
        } else {
            button.title = ""
        }
    }

    // MARK: Panel

    @objc private func togglePanel() {
        if panel?.isVisible == true, !isClosing { closePanel() } else { openPanel() }
    }

    private func makePanel() -> PopupPanel {
        let hosting = SizeReportingHostingView(rootView: PanelView(model: model))
        hosting.sizingOptions = [.intrinsicContentSize]
        hosting.autoresizingMask = [.width, .height]
        hosting.onIntrinsicSizeChange = { [weak self] in
            // Deferred: the invalidation can happen in the middle of a layout pass.
            DispatchQueue.main.async { self?.syncPanelSize() }
        }
        hostingView = hosting

        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = Theme.panelCornerRadius
        background.layer?.cornerCurve = .continuous
        background.layer?.masksToBounds = true
        hosting.frame = background.bounds
        background.addSubview(hosting)

        let panel = PopupPanel(
            contentRect: NSRect(x: 0, y: 0, width: Theme.panelWidth, height: 200),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = background
        return panel
    }

    private func openPanel() {
        guard statusItem.button?.window != nil else { return }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        isClosing = false
        syncPanelSize()

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let finalFrame = panel.frame
        if !reduceMotion {
            panel.alphaValue = 0
            panel.setFrame(finalFrame.offsetBy(dx: 0, dy: 6), display: false)
        } else {
            panel.alphaValue = 1
        }
        panel.orderFrontRegardless()
        panel.makeKey()
        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
                panel.animator().setFrame(finalFrame, display: true)
            }
        }
        installMonitors()
    }

    private func closePanel() {
        guard let panel, panel.isVisible, !isClosing else { return }
        removeMonitors()
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.orderOut(nil)
            return
        }
        isClosing = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(panel.frame.offsetBy(dx: 0, dy: 4), display: true)
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.isClosing else { return }
                self.isClosing = false
                panel.orderOut(nil)
            }
        })
    }

    /// Resizes the panel to the SwiftUI ideal size, keeping its top edge pinned under the status item
    /// and the whole panel inside the visible frame of the status item's screen.
    private func syncPanelSize() {
        guard let panel, let hostingView, !isClosing,
              let buttonWindow = statusItem.button?.window, let button = statusItem.button else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? .zero

        let width = Theme.panelWidth
        let maxHeight = min(Theme.maxPanelHeight, visible.height - Self.screenMargin * 2)
        let height = min(max(hostingView.intrinsicContentSize.height, 80), maxHeight)
        let top = min(buttonRect.minY - Self.gap, visible.maxY - Self.screenMargin)
        var x = buttonRect.midX - width / 2
        x = min(max(x, visible.minX + Self.screenMargin), visible.maxX - width - Self.screenMargin)

        let frame = NSRect(x: x, y: top - height, width: width, height: height)
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
    }

    private func installMonitors() {
        removeMonitors()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.closePanel() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }  // Escape
            MainActor.assumeIsolated { self?.closePanel() }
            return nil
        }
    }

    private func removeMonitors() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        clickMonitor = nil
        keyMonitor = nil
    }
}

@main
struct RedmiBudsBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    // The UI lives in an AppKit status item and panel owned by `AppDelegate`; SwiftUI needs at least one scene.
    var body: some Scene {
        Settings { EmptyView() }
    }
}
