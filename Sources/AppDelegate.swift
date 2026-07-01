import AppKit
import UniformTypeIdentifiers

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

        // Decide whether to show the first-install welcome BEFORE Preferences.shared
        // initializes — Preferences writes `launchAtLogin` on first launch, so the
        // "clean container" check has to read UserDefaults first.
        let shouldShowWelcome = Self.evaluateFirstInstallWelcome()

        _ = Preferences.shared
        _ = ClipboardHistory.shared
        _ = SnippetManager.shared
        _ = UpdaterManager.shared

        let p = Preferences.shared
        AppLogger.shared.log("Settings — maxItems: \(p.maxHistoryItems), menuStyle: \(p.historyMenuStyle), sortOrder: \(p.historySortOrder), matchStyleModifier: \(p.matchStyleModifier), launchAtLogin: \(p.launchAtLogin), itemsPanelWidth: \(p.itemsPanelWidth), previewLines: \(p.previewLines), excludedApps: \(p.excludedBundleIDs.count)")

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

        if shouldShowWelcome {
            // Defer so the menu bar item and accessibility prompt settle first.
            DispatchQueue.main.async { [weak self] in
                self?.showWelcomePopup()
            }
        }
    }

    // MARK: - First-install welcome

    private static let didShowWelcomeKey = "didShowWelcome"

    /// Returns true only on a genuine first install. Also records that we've made
    /// the determination so the popup is offered at most once, ever.
    private static func evaluateFirstInstallWelcome() -> Bool {
        let ud = UserDefaults.standard
        guard !ud.bool(forKey: didShowWelcomeKey) else { return false }

        // A user upgrading from an earlier build already has stored preferences —
        // don't nag them. Only a clean container counts as a first install.
        let hasPriorFootprint = ud.object(forKey: "launchAtLogin") != nil
            || ud.object(forKey: "maxHistoryItems") != nil

        ud.set(true, forKey: didShowWelcomeKey)
        return !hasPriorFootprint
    }

    private func showWelcomePopup() {
        AppLogger.shared.log("First install — showing welcome popup")
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Welcome to Modern Clipboard"
        alert.informativeText = """
        Modern Clipboard lives in your menu bar. Press ⇧⌘V to open your clipboard history, or ⇧⌘S for snippets.

        New here? The Quick Start Guide walks you through everything in a couple of minutes.
        """
        if let icon = NSImage(named: "AppIcon") { alert.icon = icon }
        alert.addButton(withTitle: "Download Quick Start Guide")
        alert.addButton(withTitle: "Maybe Later")

        if alert.runModal() == .alertFirstButtonReturn {
            saveQuickStartGuide()
        }
    }

    /// Presents a save panel (defaulting to ~/Downloads) and copies the bundled
    /// Quick Start PDF there — mirrors the Help-tab download button.
    private func saveQuickStartGuide() {
        let resource = "Modern Clipboard Quick Start v1.1"
        guard let src = Bundle.main.url(forResource: resource, withExtension: "pdf") else {
            AppLogger.shared.log("Welcome: Quick Start PDF not found in bundle")
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(resource).pdf"
        panel.allowedContentTypes = [.pdf]
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let dest = panel.url else { return }

        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: src, to: dest)
        } catch {
            AppLogger.shared.log("Welcome: failed to save Quick Start PDF — \(error.localizedDescription)")
        }
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
