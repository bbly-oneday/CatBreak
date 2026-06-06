import AppKit
import Combine

class ActiveAppMonitor {
    private let timerManager: TimerManager
    private var pollTimer: Timer?

    // All event types that indicate user activity
    private let activityEventTypes: NSEvent.EventTypeMask = [
        .mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel
    ]

    init(timerManager: TimerManager) {
        self.timerManager = timerManager

        // Subscribe to system-wide events for activity detection
        NSEvent.addGlobalMonitorForEvents(matching: activityEventTypes) { [weak self] _ in
            self?.timerManager.recordUserActivity()
        }
    }

    func start() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.timerManager.tick()
        }
        timerManager.startMonitoring()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
