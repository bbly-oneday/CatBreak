import AppKit
import SwiftUI
import ServiceManagement
import UserNotifications
import CoreAudio
import Combine
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - 常量
    private enum Constants {
        static let settingsWindowWidth: CGFloat = 320
        static let settingsWindowHeight: CGFloat = 680
        static let windowEdgePadding: CGFloat = 10
        static let windowCornerRadius: CGFloat = 12
    }

    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var timerManager: TimerManager!
    private var monitor: ActivityMonitor?
    private var settingsStore: SettingsStore!

    // 静音相关：保存静音前每个输出设备的静音状态
    private var muteStatesBeforeBreak: [AudioObjectID: Bool] = [:]

    // 静音状态持久化键（用于崩溃后恢复，仅 DMG 版）
    private enum MutePersistence {
        static let statesKey = "muteStatesBeforeBreak"
        static let activeKey = "muteRestorePending"
    }

    // 自动隐藏相关
    private var autoHideTimer: Timer?
    private var isMouseInWindow: Bool = false

    // 预警通知是否已发送（避免重复）
    private var warningDelivered: Bool = false

    // Combine 订阅缓存
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 若上次在休息静音中异常退出，先恢复设备静音状态（仅 DMG 版）
        restoreMuteStatesIfCrashed()

        // 请求通知权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                Logger.app.error("Notification authorization failed: \(error)")
            } else if granted {
                Logger.app.debug("Notification authorization granted")
            }
        }

        // Initialize settings store (single instance)
        settingsStore = SettingsStore()

        // Wire up launch at login callback
        settingsStore.onLaunchAtLoginChanged = { [weak self] enabled in
            self?.setLaunchAtLogin(enabled)
        }

        // Initialize timer manager with settings store
        timerManager = TimerManager(settingsStore: settingsStore)

        // Setup status bar
        setupStatusBar()

        // Start monitoring
        monitor = ActivityMonitor(timerManager: timerManager)
        monitor?.start()

        // Observe break state for overlay
        timerManager.onBreakStarted = { [weak self] in
            self?.showBreakOverlay()
        }
        timerManager.onBreakEnded = { [weak self] in
            self?.hideBreakOverlay()
        }

        // Observe warning
        timerManager.onWarning = { [weak self] in
            self?.showWarningNotification()
        }

        // 预警状态清除时（进休息/重置/离开/预警结束）复位通知标志，
        // 使下一轮预警能再次发送通知。替代原先基于固定延时的脆弱复位。
        timerManager.$isWarning
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] isWarning in
                if !isWarning {
                    self?.warningDelivered = false
                }
            }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()

        // 如果正在休息中退出，恢复音量
        if timerManager.state == .breaking && settingsStore.muteOnBreak {
            restoreMuteStates()
        }
    }

    // MARK: - Login Item

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                DispatchQueue.main.async {
                    self.settingsStore.launchAtLogin = !enabled
                    self.showAlert(message: "开机自启动设置失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "设置失败"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "CatBreak")
            button.image?.isTemplate = true
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @MainActor
    @objc private func statusBarButtonClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: L10n.tr("menu.settings"), action: #selector(toggleSettingsWindow), keyEquivalent: ","))
            menu.addItem(NSMenuItem(title: L10n.tr("menu.about"), action: #selector(showAbout), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: L10n.tr("menu.quit"), action: #selector(quitApp), keyEquivalent: "q"))
            statusItem.menu = menu
            DispatchQueue.main.async {
                self.statusItem.menu = nil
            }
        } else {
            toggleSettingsWindow()
        }
    }

    @MainActor
    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func toggleSettingsWindow() {
        // 关闭分支：窗口可见则隐藏，保留实例以便复用（不销毁）
        if let window = settingsWindow, window.isVisible {
            window.orderOut(nil)
            return
        }

        // 获取状态栏按钮在屏幕上的位置
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        // 使用按钮所在的屏幕（多显示器支持）
        let screen = buttonWindow.screen ?? NSScreen.main!

        // 将按钮位置转换为屏幕坐标
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))

        // 复用窗口实例：仅首次打开时创建并配置一次，后续打开直接复用
        if settingsWindow == nil {
            let contentView = ContentView(timerManager: timerManager, settingsStore: settingsStore)
            let hostingView = NSHostingView(rootView: contentView)

            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: Constants.settingsWindowWidth, height: Constants.settingsWindowHeight),
                                  styleMask: [.borderless],
                                  backing: .buffered,
                                  defer: false)
            window.contentView = hostingView
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.backgroundColor = .clear
            window.hasShadow = true

            // 设置窗口圆角
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.cornerRadius = Constants.windowCornerRadius
            window.contentView?.layer?.masksToBounds = true
            window.contentView?.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

            // 添加鼠标进入/离开监听
            setupWindowMouseTracking(window)

            settingsWindow = window
        }

        guard let window = settingsWindow else { return }

        // 计算窗口位置：紧贴菜单栏底部，对齐图标（每次打开重新计算，适配屏幕变化）
        let screenFrame = screen.frame
        let windowWidth: CGFloat = Constants.settingsWindowWidth
        let windowHeight: CGFloat = Constants.settingsWindowHeight

        // 菜单栏高度
        let menuBarHeight = screenFrame.height - screen.visibleFrame.height - screen.visibleFrame.origin.y

        // 窗口位置：居中对齐按钮，顶部紧贴菜单栏底部
        // 默认情况下窗口中心对齐按钮中心
        var x = buttonRect.origin.x + buttonRect.width / 2 - windowWidth / 2

        // 如果右侧空间不足，则向左调整
        let rightEdge = x + windowWidth
        let screenRightEdge = screenFrame.origin.x + screenFrame.width
        if rightEdge > screenRightEdge {
            x = screenRightEdge - windowWidth - Constants.windowEdgePadding
        }

        // 如果左侧空间不足，则从屏幕左侧开始
        if x < screenFrame.origin.x {
            x = screenFrame.origin.x + Constants.windowEdgePadding
        }
        let y = screenFrame.height - menuBarHeight - windowHeight

        // 先设置窗口框架，再显示（避免系统自动调整位置）
        let targetFrame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
        window.setFrame(targetFrame, display: true, animate: false)
        window.makeKeyAndOrderFront(nil)

        // 启动自动隐藏计时器
        startAutoHideTimer()
    }

    // MARK: - Auto-hide Timer

    private func setupWindowMouseTracking(_ window: NSWindow) {
        // 创建跟踪区域
        let trackingArea = NSTrackingArea(
            rect: window.contentView?.bounds ?? .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        window.contentView?.addTrackingArea(trackingArea)
    }

    private func startAutoHideTimer() {
        // 取消之前的计时器
        autoHideTimer?.invalidate()

        // 启动新计时器
        let delay = TimeInterval(settingsStore.autoHideDelaySeconds)
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.hideWindowIfNeeded()
            }
        }
    }

    private func hideWindowIfNeeded() {
        // 如果鼠标在窗口内，不隐藏
        guard !isMouseInWindow else { return }

        // 如果窗口可见，隐藏
        if let window = settingsWindow, window.isVisible {
            window.orderOut(nil)
        }
    }

    // 鼠标进入窗口
    private func mouseEntered() {
        isMouseInWindow = true
        // 暂停自动隐藏
        autoHideTimer?.invalidate()
    }

    // 鼠标离开窗口
    private func mouseExited() {
        isMouseInWindow = false
        // 重新开始计时
        startAutoHideTimer()
    }

    @MainActor
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Warning Notification

    @MainActor
    private func showWarningNotification() {
        guard !warningDelivered else { return }
        warningDelivered = true

        let content = UNMutableNotificationContent()
        content.title = L10n.tr("warning.title")
        content.body = String(format: L10n.tr("warning.body"), timerManager.warningAdvanceSeconds / 60)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "CatBreak.warning",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.app.error("Warning notification error: \(error)")
            }
        }
        // warningDelivered 的复位由 isWarning 状态订阅统一处理（见 applicationDidFinishLaunching）
    }

    // MARK: - Break Overlay

    private var breakWindow: BreakOverlayWindow?

    private func showBreakOverlay() {
        warningDelivered = false

        // 休息时静音（CoreAudio 直接控制）——仅 DMG 版支持
        if settingsStore.muteOnBreak && MuteCapability.isSupported {
            muteAllOutputDevices()
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.breakWindow = BreakOverlayWindow(timerManager: self.timerManager)
            self.breakWindow?.show()
        }
    }

    private func hideBreakOverlay() {
        // 恢复音量
        if settingsStore.muteOnBreak && MuteCapability.isSupported {
            restoreMuteStates()
        }

        DispatchQueue.main.async { [weak self] in
            self?.breakWindow?.hide()
            self?.breakWindow = nil
        }
    }

    // MARK: - Volume Control (CoreAudio)

    /// 获取所有输出设备
    private func getAllOutputDevices() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil, &dataSize
        )
        guard status == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var deviceIDs = [AudioObjectID](repeating: 0, count: count)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize, &deviceIDs
        )
        guard status == noErr else { return [] }

        // 过滤：只保留有输出流的设备
        return deviceIDs.filter { deviceID in
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            let s = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &streamSize)
            return s == noErr && streamSize > 0
        }
    }

    /// 获取设备的静音状态
    private func getDeviceMuteState(_ deviceID: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var isMuted = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &isMuted)
        return status == noErr && isMuted != 0
    }

    /// 设置设备的静音状态
    private func setDeviceMuteState(_ deviceID: AudioObjectID, muted: Bool) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        // 检查该设备是否支持静音设置
        var isSettable = DarwinBoolean(false)
        let settableStatus = AudioObjectIsPropertySettable(deviceID, &address, &isSettable)
        if settableStatus != noErr || !isSettable.boolValue {
            return false
        }

        var muteValue: UInt32 = muted ? 1 : 0
        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0, nil,
            UInt32(MemoryLayout<UInt32>.size),
            &muteValue
        )
        return status == noErr
    }

    /// 静音所有输出设备，并保存原始静音状态
    private func muteAllOutputDevices() {
        muteStatesBeforeBreak.removeAll()
        let devices = getAllOutputDevices()

        for deviceID in devices {
            // 记录原始静音状态
            let wasMuted = getDeviceMuteState(deviceID)
            muteStatesBeforeBreak[deviceID] = wasMuted

            // 如果原本没静音，则静音
            if !wasMuted {
                let success = setDeviceMuteState(deviceID, muted: true)
                if !success {
                    // 某些设备不支持静音，尝试用音量方式
                    // 但大部分设备都支持 kAudioDevicePropertyMute
                }
            }
        }

        // 持久化：若进程在休息中崩溃/被强杀，下次启动可据以恢复静音状态
        persistMuteStates()
    }

    /// 恢复所有输出设备的静音状态
    private func restoreMuteStates() {
        for (deviceID, wasMuted) in muteStatesBeforeBreak {
            // 只恢复原本没静音的设备
            if !wasMuted {
                _ = setDeviceMuteState(deviceID, muted: false)
            }
        }
        muteStatesBeforeBreak.removeAll()

        // 已正常恢复，清除崩溃恢复标记
        clearPersistedMuteStates()
    }

    // MARK: - 静音状态持久化（崩溃恢复，仅 DMG 版有效）

    /// 把静音前状态写入 UserDefaults，并置待恢复标记
    private func persistMuteStates() {
        // [AudioObjectID( UInt32 ): Bool] -> [String: Bool]
        let dict = muteStatesBeforeBreak.reduce(into: [String: Bool]()) { result, entry in
            result[String(entry.key)] = entry.value
        }
        UserDefaults.standard.set(dict, forKey: MutePersistence.statesKey)
        UserDefaults.standard.set(true, forKey: MutePersistence.activeKey)
    }

    /// 清除持久化的静音状态与标记
    private func clearPersistedMuteStates() {
        UserDefaults.standard.removeObject(forKey: MutePersistence.statesKey)
        UserDefaults.standard.removeObject(forKey: MutePersistence.activeKey)
    }

    /// 启动时检测上次是否在休息静音中异常退出，若是则恢复设备静音状态
    /// 仅在支持系统级静音的构建（DMG 版）下执行
    private func restoreMuteStatesIfCrashed() {
        guard MuteCapability.isSupported else { return }
        guard UserDefaults.standard.bool(forKey: MutePersistence.activeKey) else { return }

        Logger.app.info("Detected unfinished mute restore from previous run, restoring device mute states")
        if let dict = UserDefaults.standard.dictionary(forKey: MutePersistence.statesKey) as? [String: Bool] {
            for (key, wasMuted) in dict {
                guard let deviceID = AudioObjectID(key) else { continue }
                if !wasMuted {
                    _ = setDeviceMuteState(deviceID, muted: false)
                }
            }
        }
        clearPersistedMuteStates()
    }
}
