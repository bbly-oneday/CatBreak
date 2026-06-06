import Foundation
import Combine

enum TimerState {
    case idle
    case monitoring
    case breaking
}

class TimerManager: ObservableObject {
    @Published var state: TimerState = .idle
    @Published var elapsedSeconds: Int = 0

    let settingsStore: SettingsStore

    var onBreakStarted: (() -> Void)?
    var onBreakEnded: (() -> Void)?

    private var usageTimer: Timer?
    private var breakTimer: Timer?
    private var breakRemainingSeconds: Int = 0

    var breakDuration: Int {
        return settingsStore.breakDurationMinutes * 60
    }

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    // Called by ActiveAppMonitor every second when front app is monitored
    func tick() {
        guard state == .monitoring else { return }

        elapsedSeconds += 1

        if elapsedSeconds >= settingsStore.usageLimitSeconds {
            startBreak()
        }
    }

    func startMonitoring() {
        guard state == .idle else { return }
        state = .monitoring
        elapsedSeconds = 0
    }

    func pause() {
        // Called when user switches away from monitored app
    }

    private func startBreak() {
        state = .breaking
        breakRemainingSeconds = settingsStore.breakDurationMinutes * 60
        usageTimer?.invalidate()
        usageTimer = nil

        onBreakStarted?()

        // Start break countdown
        breakTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.breakCountdownTick()
        }
    }

    private func breakCountdownTick() {
        breakRemainingSeconds -= 1

        if breakRemainingSeconds <= 0 {
            endBreak()
        }
    }

    private func endBreak() {
        breakTimer?.invalidate()
        breakTimer = nil

        state = .idle
        elapsedSeconds = 0

        onBreakEnded?()
    }

    // Reset timer manually
    func reset() {
        usageTimer?.invalidate()
        usageTimer = nil
        breakTimer?.invalidate()
        breakTimer = nil

        state = .idle
        elapsedSeconds = 0
    }
}
