import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var timerManager: TimerManager!
    private var monitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize core services
        let settingsStore = SettingsStore()
        timerManager = TimerManager(settingsStore: settingsStore)

        // Setup status bar item
        setupStatusBar()

        // Setup popover for settings
        setupPopover()

        // Start monitoring
        monitor = ActiveAppMonitor(timerManager: timerManager)
        monitor?.start()

        // Observe break state for overlay
        timerManager.onBreakStarted = { [weak self] in
            self?.showBreakOverlay()
        }
        timerManager.onBreakEnded = { [weak self] in
            self?.hideBreakOverlay()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "CatBreak")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Right-click menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Settings", action: #selector(togglePopover), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit CatBreak", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 280)
        popover.behavior = .transient
        popover.animates = true

        let settingsStore = timerManager.settingsStore
        let contentView = ContentView(timerManager: timerManager, settingsStore: settingsStore)
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Break Overlay

    private var breakWindow: BreakOverlayWindow?

    private func showBreakOverlay() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let remaining = self.timerManager.breakDuration
            self.breakWindow = BreakOverlayWindow(breakDuration: remaining)
            self.breakWindow?.show()
        }
    }

    private func hideBreakOverlay() {
        DispatchQueue.main.async { [weak self] in
            self?.breakWindow?.hide()
            self?.breakWindow = nil
        }
    }
}
