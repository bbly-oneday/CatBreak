import AppKit
import Combine

class ActiveAppMonitor {
    private let timerManager: TimerManager
    private var pollTimer: Timer?
    private var lastAppBundleId: String?

    // Apps to monitor (all apps by default)
    private let monitoredBundleIds: Set<String> = [] // Empty = monitor all

    init(timerManager: TimerManager) {
        self.timerManager = timerManager
    }

    func start() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkFrontmostApp()
        }
        timerManager.startMonitoring()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkFrontmostApp() {
        let workspace = NSWorkspace.shared
        guard let frontApp = workspace.frontmostApplication else {
            timerManager.pause()
            return
        }

        let bundleId = frontApp.bundleIdentifier ?? ""

        // Skip our own app
        if bundleId == Bundle.main.bundleIdentifier {
            return
        }

        // If app changed, reset timer
        if bundleId != lastAppBundleId {
            lastAppBundleId = bundleId
            // Optionally reset on app switch
        }

        // If monitoring all apps or this app is in the monitored list
        if monitoredBundleIds.isEmpty || monitoredBundleIds.contains(bundleId) {
            timerManager.tick()
        }
    }
}
