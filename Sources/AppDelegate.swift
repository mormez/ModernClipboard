import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private var prefsObserver: NSObjectProtocol?
    private var hotkeyObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        AppLogger.shared.log("App launching — version \(version) (\(build)), macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        AppLogger.shared.log("Accessibility permission granted: \(AXIsProcessTrustedWithOptions(nil))")

        _ = Preferences.shared
        _ = ClipboardHistory.shared
        _ = SnippetManager.shared
        _ = UpdaterManager.shared

        menuBarManager = MenuBarManager()
        ClipboardMonitor.shared.start()
        registerHotkeys()

        // Rebuild menus when non-hotkey preferences change
        prefsObserver = NotificationCenter.default.addObserver(
            forName: .preferencesChanged, object: nil, queue: .main) { [weak self] _ in
            self?.menuBarManager?.buildMenu()
        }

        // Re-register hotkey ONLY when the hotkey preferences change
        hotkeyObserver = NotificationCenter.default.addObserver(
            forName: .hotkeyChanged, object: nil, queue: .main) { [weak self] _ in
            self?.registerHotkeys()
        }

        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppLogger.shared.log("App terminating")
        ClipboardMonitor.shared.stop()
        HotkeyManager.shared.unregisterAll()
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    private func registerHotkeys() {
        HotkeyManager.shared.unregisterAll()
        let p = Preferences.shared
        HotkeyManager.shared.register(
            keyCode: p.mainMenuKeyCode,
            modifiers: p.mainMenuModifiers
        ) {
            ClipboardPopupController.shared.toggle()
        }
        HotkeyManager.shared.register(
            keyCode: p.snippetsMenuKeyCode,
            modifiers: p.snippetsMenuModifiers
        ) {
            SnippetsPopupController.shared.toggle()
        }
    }
}
