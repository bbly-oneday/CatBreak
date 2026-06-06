import AppKit
import SwiftUI
import ServiceManagement
import UserNotifications
import CoreAudio
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
    private var monitor: ActiveAppMonitor?
    private var settingsStore: SettingsStore!

    // 静音相关：保存静音前每个输出设备的静音状态
    private var muteStatesBeforeBreak: [AudioObjectID: Bool] = [:]

    // 预警通知是否已发送（避免重复）
    private var warningDelivered: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        monitor = ActiveAppMonitor(timerManager: timerManager)
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

    @objc private func statusBarButtonClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "打开设置", action: #selector(toggleSettingsWindow), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))
            statusItem.menu = menu
            DispatchQueue.main.async {
                self.statusItem.menu = nil
            }
        } else {
            toggleSettingsWindow()
        }
    }

    @objc private func toggleSettingsWindow() {
        if let window = settingsWindow, window.isVisible {
            window.orderOut(nil)
            return
        }

        // 获取状态栏按钮在屏幕上的位置
        guard let button = statusItem.button,
              let screen = NSScreen.main else { return }

        let buttonRect = button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? .zero

        // 创建窗口
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

        // 计算窗口位置：紧贴菜单栏底部，对齐图标
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

        window.setFrameOrigin(NSPoint(x: x, y: y))
        window.makeKeyAndOrderFront(nil)

        settingsWindow = window
    }

    @MainActor
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Warning Notification

    private func showWarningNotification() {
        guard !warningDelivered else { return }
        warningDelivered = true

        let content = UNMutableNotificationContent()
        content.title = "CatBreak 预警"
        content.body = "还有 \(timerManager.warningAdvanceSeconds / 60) 分钟即将开始休息，请保存工作！"
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

        // 休息开始后重置
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(timerManager.warningAdvanceSeconds + 10)) { [weak self] in
            self?.warningDelivered = false
        }
    }

    // MARK: - Break Overlay

    private var breakWindow: BreakOverlayWindow?

    private func showBreakOverlay() {
        warningDelivered = false

        // 休息时静音（CoreAudio 直接控制）
        if settingsStore.muteOnBreak {
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
        if settingsStore.muteOnBreak {
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
    }
}
