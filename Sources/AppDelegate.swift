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

        // Decide which launch popup (if any) to show BEFORE Preferences.shared
        // initializes — Preferences writes `launchAtLogin` on first launch, so the
        // "clean container" check has to read UserDefaults first.
        // evaluateWhatsNew() always runs (it records the notified version even for
        // fresh installs) but only returns true for an existing user who just
        // upgraded to a version with release notes.
        let shouldShowWelcome  = Self.evaluateFirstInstallWelcome()
        let shouldShowWhatsNew = Self.evaluateWhatsNew() && !shouldShowWelcome

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
        } else if shouldShowWhatsNew {
            DispatchQueue.main.async { [weak self] in
                self?.showWhatsNewPopup()
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

    // MARK: - "What's New" after an update

    private static let lastNotifiedVersionKey = "lastNotifiedVersion"

    private static var currentShortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// The "What's New" body for a version, or nil if that version has no notes.
    /// Add a case per release that ships a user-facing feature worth surfacing.
    private static func whatsNewMessage(for version: String) -> String? {
        switch version {
        case "1.2.0":
            return "Quick Snippets lets you paste your 10 most-used snippets with a single number key — press ⇧⌘S, then 1–9."
        default:
            return nil
        }
    }

    /// Always records the current version as "notified" (so a fresh install never
    /// sees What's New for the version it was installed at), but only returns true
    /// for an existing user whose version changed to one that has release notes.
    private static func evaluateWhatsNew() -> Bool {
        let ud = UserDefaults.standard
        let current = currentShortVersion
        let last = ud.string(forKey: lastNotifiedVersionKey)
        ud.set(current, forKey: lastNotifiedVersionKey)

        // Read footprint BEFORE Preferences.shared writes it — a clean container
        // is a fresh install, which the welcome popup handles instead.
        let hasPriorFootprint = ud.object(forKey: "launchAtLogin") != nil
            || ud.object(forKey: "maxHistoryItems") != nil

        guard hasPriorFootprint, last != current else { return false }
        return whatsNewMessage(for: current) != nil
    }

    private func showWhatsNewPopup() {
        let version = Self.currentShortVersion
        guard let body = Self.whatsNewMessage(for: version) else { return }
        AppLogger.shared.log("Existing user upgraded to \(version) — showing What's New popup")
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "What's New in Modern Clipboard \(version)"
        alert.informativeText = body
        if let icon = NSImage(named: "AppIcon") { alert.icon = icon }
        alert.addButton(withTitle: "Show Me")
        alert.addButton(withTitle: "Got It")

        if alert.runModal() == .alertFirstButtonReturn {
            // Open the snippets popup so the Quick Snippets folder is right there.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                SnippetsPopupController.shared.show()
            }
        }
    }

    private func showWelcomePopup() {
        AppLogger.shared.log("First install — showing welcome popup")
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Welcome to Modern Clipboard"
        alert.informativeText = """
        Press ⇧⌘V to open your clipboard history, or ⇧⌘S for snippets.

        Tip: Quick Snippets lets you paste your 10 most-used snippets with a single number key — press ⇧⌘S, then 1–9.

        New here? The Quick Start Guide walks you through everything in a couple of minutes.
        """
        if let icon = NSImage(named: "AppIcon") { alert.icon = icon }
        alert.addButton(withTitle: "Download Quick Start")
        alert.addButton(withTitle: "Maybe Later")

        if alert.runModal() == .alertFirstButtonReturn {
            saveQuickStartGuide()
        }
    }

    /// Presents a save panel (defaulting to ~/Downloads) and copies the bundled
    /// Quick Start PDF there — mirrors the Help-tab download button.
    private func saveQuickStartGuide() {
        let resource = "Modern Clipboard Quick Start v1.2"
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
