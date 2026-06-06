import AppKit
import SwiftUI

class BreakOverlayWindow {
    private var windows: [NSWindow] = []
    private weak var timerManager: TimerManager?
    private var countdownTimer: Timer?
    private var breakCount: Int = 0

    /// 共享状态：所有屏幕的 CatOverlayView 观察同一个实例
    /// 这样倒计时更新时，SwiftUI 自动刷新视图，不需要重建 NSHostingView
    private let overlayState = BreakOverlayState()

    /// 屏幕配置变化通知观察者
    private var screenChangeObserver: Any?

    init(timerManager: TimerManager) {
        self.timerManager = timerManager
    }

    func show() {
        breakCount += 1
        let currentBreakCount = breakCount

        // 每次休息随机选一条语录
        let quote = QuoteStore.random()

        // 设置共享状态
        overlayState.remainingSeconds = timerManager?.currentBreakRemaining ?? 0
        overlayState.breakCount = currentBreakCount
        overlayState.quote = quote

        // 为每个屏幕创建遮罩窗口
        for screen in NSScreen.screens {
            let window = makeOverlayWindow(for: screen)
            windows.append(window)
            // orderFrontRegardless 比 makeKeyAndOrderFront 更可靠
            // 确保overlay在所有屏幕上都显示，不会被系统窗口管理干扰
            window.orderFrontRegardless()
        }

        // 监听屏幕配置变化（热插拔显示器）
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }

        startCountdown()
    }

    func hide() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        // 移除屏幕变化监听
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            screenChangeObserver = nil
        }

        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
    }

    private func makeOverlayWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.setFrame(screen.frame, display: true)

        // 使用 CGShieldingWindowLevel 确保遮罩在所有窗口之上
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false

        // 所有屏幕共享同一个 overlayState 实例
        // SwiftUI 会自动观察 @Published 属性变化并刷新视图
        let catView = CatOverlayView(state: overlayState)
        window.contentView = NSHostingView(rootView: catView)

        return window
    }

    /// 屏幕配置变化时（热插拔显示器），重建窗口以适应新布局
    private func handleScreenChange() {
        // 记住当前窗口对应的屏幕
        let oldScreenCount = windows.count
        let newScreenCount = NSScreen.screens.count

        guard oldScreenCount != newScreenCount else { return }

        // 移除旧窗口
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()

        // 为当前所有屏幕重新创建窗口
        for screen in NSScreen.screens {
            let window = makeOverlayWindow(for: screen)
            windows.append(window)
            window.orderFrontRegardless()
        }
    }

    /// 倒计时：只更新共享状态，不替换 contentView
    /// SwiftUI 自动根据 @Published 属性变化刷新所有屏幕上的视图
    private func startCountdown() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, let tm = self.timerManager else {
                timer.invalidate()
                return
            }

            let remaining = tm.currentBreakRemaining

            if remaining <= 0 {
                timer.invalidate()
                self.hide()
            } else {
                // 只更新共享状态，SwiftUI 自动刷新
                self.overlayState.remainingSeconds = remaining
            }
        }
    }
}
