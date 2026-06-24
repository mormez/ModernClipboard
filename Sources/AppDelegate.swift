import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private var prefsObserver: NSObjectProtocol?
    private var hotkeyObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        AppLogger.shared.log("──────── New Session ────────")
        AppLogger.shared.log("App launching — version \(version) (\(build)), macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        AppLogger.shared.log("Accessibility permission granted: \(AXIsProcessTrustedWithOptions(nil))")

        NSSetUncaughtExceptionHandler { exception in
            AppLogger.shared.log("UNCAUGHT EXCEPTION: \(exception.name.rawValue) — \(exception.reason ?? "no reason"); stack: \(exception.callStackSymbols.joined(separator: " | "))")
        }

        _ = Preferences.shared
        _ = ClipboardHistory.shared
        _ = SnippetManager.shared
        _ = UpdaterManager.shared

        let p = Preferences.shared
        AppLogger.shared.log("Settings — maxItems: \(p.maxHistoryItems), menuStyle: \(p.historyMenuStyle), sortOrder: \(p.historySortOrder), preserveFormatting: \(p.preserveFormatting), matchStyleModifier: \(p.matchStyleModifier), launchAtLogin: \(p.launchAtLogin), itemsPanelWidth: \(p.itemsPanelWidth), previewLines: \(p.previewLines), excludedApps: \(p.excludedBundleIDs.count)")

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
