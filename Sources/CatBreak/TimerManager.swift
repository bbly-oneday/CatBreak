import Foundation
import Combine
import AppKit
import os.log

enum TimerState {
    case idle
    case monitoring
    case paused   // 用户离开，暂停计时
    case warning  // 预警：即将休息
    case breaking
}

@MainActor
class TimerManager: ObservableObject {
    // MARK: - 常量
    private let microphoneCheckInterval: Int = 10  // 麦克风检测间隔（秒）
    private let breakCheckInterval: Int = 5        // 休息期间麦克风检测间隔（秒）

    @Published var state: TimerState = .idle
    @Published var elapsedSeconds: Int = 0
    @Published var isUserAway: Bool = false
    @Published var isInSensitiveApp: Bool = false
    @Published var sensitiveAppReason: String?
    @Published var isWarning: Bool = false  // 预警状态

    let settingsStore: SettingsStore

    var onBreakStarted: (() -> Void)?
    var onBreakEnded: (() -> Void)?
    var onWarning: (() -> Void)?  // 预警回调

    private var breakTimer: Timer?

    /// 休息剩余秒数（单一数据源）。
    /// `@Published`：遮罩窗口订阅它刷新倒计时，无需额外计时器。
    @Published var breakRemainingSeconds: Int = 0

    private var breakTickCounter: Int = 0  // 休息期间检测节流计数

    // 离开阈值：超过 3 分钟无操作视为离开
    private let idleThresholdSeconds: TimeInterval = 180
    // 离开清零阈值：超过 10 分钟无操作，使用时长清零
    private let resetAwayThresholdSeconds: TimeInterval = 600

    // 预警提前秒数（5分钟）
    let warningAdvanceSeconds: Int = 300

    private var lastInputTime: Date = Date()
    private var wentAwayTime: Date?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    /// 检测麦克风是否正在使用
    private func checkMicrophone() -> Bool {
        let result = MicrophoneDetector.checkActive()
        if result.isActive {
            sensitiveAppReason = result.reason
        } else {
            sensitiveAppReason = nil
        }
        return result.isActive
    }

    func recordUserActivity() {
        lastInputTime = Date()
        // 离开超过10分钟后状态变为 idle，用户回来时自动重新开始监控
        if state == .idle {
            startMonitoring()
        }
    }

    func tick() {
        guard state == .monitoring || state == .paused || state == .warning else { return }

        let idleSeconds = Date().timeIntervalSince(lastInputTime)
        let wasAway = isUserAway
        isUserAway = idleSeconds > idleThresholdSeconds

        if !wasAway && isUserAway {
            Logger.timer.info("tick: User went away, pausing monitoring")
            wentAwayTime = Date()
            state = .paused
            isWarning = false
        } else if wasAway && !isUserAway {
            if let awayTime = wentAwayTime, Date().timeIntervalSince(awayTime) > resetAwayThresholdSeconds {
                Logger.timer.info("tick: User returned after extended absence, resetting elapsed time")
                elapsedSeconds = 0
            } else {
                Logger.timer.info("tick: User returned, resuming monitoring")
            }
            wentAwayTime = nil
            state = .monitoring
        }

        // 离开超过10分钟：提前清零并回到待机
        if isUserAway, let awayTime = wentAwayTime, Date().timeIntervalSince(awayTime) > resetAwayThresholdSeconds {
            Logger.timer.info("tick: User away for extended period, returning to idle")
            elapsedSeconds = 0
            isUserAway = false
            wentAwayTime = nil
            isWarning = false
            state = .idle
            return
        }

        if state == .monitoring || state == .warning {
            elapsedSeconds += 1

            // 持续检测麦克风状态（每 microphoneCheckInterval 秒检测一次）
            if elapsedSeconds % microphoneCheckInterval == 0 {
                isInSensitiveApp = checkMicrophone()
                if isInSensitiveApp {
                    Logger.timer.debug("tick: Sensitive app detected - \(self.sensitiveAppReason ?? "unknown")")
                }
            }

            let remainingToLimit = settingsStore.usageLimitSeconds - elapsedSeconds

            // 预警状态更新：根据剩余时间动态调整
            if remainingToLimit <= warningAdvanceSeconds && remainingToLimit > 0 && !isInSensitiveApp {
                // 进入或保持预警状态
                if !isWarning {
                    Logger.timer.info("tick: Warning triggered, \(self.warningAdvanceSeconds) seconds to limit")
                    isWarning = true
                    state = .warning
                    onWarning?()
                }
            } else if isWarning {
                // 剩余时间超过阈值，退出预警状态
                Logger.timer.info("tick: Warning cleared, returning to monitoring")
                isWarning = false
                state = .monitoring
            }

            // 到达限额
            if elapsedSeconds >= settingsStore.usageLimitSeconds {
                if !isInSensitiveApp {
                    startBreak()
                } else {
                    Logger.timer.debug("tick: Limit reached but sensitive app active, deferring break")
                }
                // 麦克风使用中则一直等待，直到空闲再休息
            }
        }
    }

    func startMonitoring() {
        guard state == .idle else { return }
        Logger.timer.info("startMonitoring: Starting monitoring from idle state")
        state = .monitoring
        elapsedSeconds = 0
        isUserAway = false
        isInSensitiveApp = false
        isWarning = false
        lastInputTime = Date()
    }

    private func startBreak() {
        Logger.timer.info("startBreak: Starting break, elapsedSeconds=\(self.elapsedSeconds)")

        state = .breaking
        isWarning = false
        breakRemainingSeconds = settingsStore.breakDurationSeconds

        onBreakStarted?()

        breakTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.breakCountdownTick()
            }
        }
    }

    private func breakCountdownTick() {
        guard state == .breaking else { return }
        breakRemainingSeconds -= 1
        breakTickCounter += 1
        if breakRemainingSeconds <= 0 {
            endBreak()
            return
        }

        // 休息期间每 breakCheckInterval 秒检测一次麦克风
        if breakTickCounter % breakCheckInterval == 0 {
            let result = MicrophoneDetector.checkActive()
            if result.isActive {
                sensitiveAppReason = result.reason
                endBreak()
            }
        }
    }

    /// 供 BreakOverlayWindow 查询当前剩余秒数（单一数据源）
    var currentBreakRemaining: Int {
        return breakRemainingSeconds
    }
    /// `@Published` 投影，供遮罩窗口 Combine 订阅倒计时刷新
    var breakRemainingPublisher: Published<Int>.Publisher { $breakRemainingSeconds }

    private func endBreak() {
        guard state == .breaking else { return }  // 防止重复调用

        Logger.timer.info("endBreak: Break ended, returning to monitoring")
        breakTimer?.invalidate()
        breakTimer = nil

        state = .monitoring
        elapsedSeconds = 0
        isUserAway = false
        isInSensitiveApp = false
        isWarning = false
        lastInputTime = Date()

        onBreakEnded?()
    }

    func reset() {
        // 如果正在休息中，先结束休息
        if state == .breaking {
            breakTimer?.invalidate()
            breakTimer = nil
            onBreakEnded?()
        }

        state = .idle
        elapsedSeconds = 0
        isUserAway = false
        isInSensitiveApp = false
        isWarning = false
        lastInputTime = Date()
        wentAwayTime = nil  // 确保清理
    }

    deinit {
        breakTimer?.invalidate()
        breakTimer = nil

        // 清理回调闭包
        onBreakStarted = nil
        onBreakEnded = nil
        onWarning = nil
    }

    // MARK: - 距限额剩余秒数（用于预警显示）
    var secondsToLimit: Int {
        return max(0, settingsStore.usageLimitSeconds - elapsedSeconds)
    }
}
