import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Menu bar only, also when launched outside an app bundle (LSUIElement covers the bundled case).
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LaunchAtLogin.applyDefaultOnFirstRun()
    }
}

@main
struct RedmiBudsBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = BudsViewModel()
    @AppStorage("showBatteryInMenuBar") private var showBattery = true

    var body: some Scene {
        MenuBarExtra {
            PanelView(model: model)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: Self.symbolName)
                if showBattery, model.connection == .connected, let percent = lowestBattery {
                    Text("\(percent)%")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    /// `earbuds` exists on recent SF Symbols versions; fall back to headphones otherwise.
    private static let symbolName: String =
        NSImage(systemSymbolName: "earbuds", accessibilityDescription: nil) != nil ? "earbuds" : "headphones"

    private var lowestBattery: Int? {
        let battery = model.state.battery
        return [battery.left?.percent, battery.right?.percent].compactMap { $0 }.min()
    }
}
