import AppKit
import Combine
import os.log

class ActivityMonitor {
    private let timerManager: TimerManager
    private var pollTimer: Timer?
    private var eventMonitor: Any?

    // All event types that indicate user activity
    private let activityEventTypes: NSEvent.EventTypeMask = [
        .mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel
    ]

    init(timerManager: TimerManager) {
        self.timerManager = timerManager

        // Subscribe to system-wide events for activity detection
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: activityEventTypes) { [weak self] _ in
            Logger.app.debug("User activity detected")
            DispatchQueue.main.async {
                self?.timerManager.recordUserActivity()
            }
        }
    }

    func start() {
        Logger.app.info("ActivityMonitor started")
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.timerManager.tick()
            }
        }
        Task { @MainActor in
            timerManager.startMonitoring()
        }
    }

    func stop() {
        Logger.app.info("ActivityMonitor stopped")
        pollTimer?.invalidate()
        pollTimer = nil
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    deinit {
        stop()
    }
}
