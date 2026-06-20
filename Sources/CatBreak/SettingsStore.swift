import Foundation
import Combine

class SettingsStore: ObservableObject {
    // MARK: - 常量
    static let minUsageLimitSeconds = 60      // 最小 1 分钟
    static let maxUsageLimitSeconds = 7200    // 最大 120 分钟
    static let defaultUsageLimitSeconds = 3600  // 默认 60 分钟

    static let minBreakDurationSeconds = 10
    static let maxBreakDurationSeconds = 1200
    static let defaultBreakDurationSeconds = 300  // 默认 5 分钟

    static let minAutoHideDelaySeconds = 5
    static let maxAutoHideDelaySeconds = 60
    static let defaultAutoHideDelaySeconds = 10  // 默认 10 秒

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let usageLimitSeconds = "usageLimitSeconds"
        static let breakDurationSeconds = "breakDurationSeconds"
        static let launchAtLogin = "launchAtLogin"
        static let muteOnBreak = "muteOnBreak"
        static let enableSensitiveAppDetection = "enableSensitiveAppDetection"
        static let autoHideDelaySeconds = "autoHideDelaySeconds"
    }

    // 休息时自动静音
    @Published var muteOnBreak: Bool {
        didSet {
            defaults.set(muteOnBreak, forKey: Keys.muteOnBreak)
        }
    }

    // 暂停休息事件监测（麦克风检测）
    @Published var enableSensitiveAppDetection: Bool {
        didSet {
            defaults.set(enableSensitiveAppDetection, forKey: Keys.enableSensitiveAppDetection)
        }
    }

    // 使用时长限额（秒）- 使用普通属性 + willSet 发送更新
    private var _usageLimitSeconds: Int = 0
    var usageLimitSeconds: Int {
        get { _usageLimitSeconds }
        set {
            let clampedValue = max(Self.minUsageLimitSeconds, min(Self.maxUsageLimitSeconds, newValue))
            if _usageLimitSeconds != clampedValue {
                _usageLimitSeconds = clampedValue
                defaults.set(clampedValue, forKey: Keys.usageLimitSeconds)
                objectWillChange.send()
            }
        }
    }

    // 休息时长（秒）
    private var _breakDurationSeconds: Int = 0
    var breakDurationSeconds: Int {
        get { _breakDurationSeconds }
        set {
            let clampedValue = max(Self.minBreakDurationSeconds, min(Self.maxBreakDurationSeconds, newValue))
            if _breakDurationSeconds != clampedValue {
                _breakDurationSeconds = clampedValue
                defaults.set(clampedValue, forKey: Keys.breakDurationSeconds)
                objectWillChange.send()
            }
        }
    }

    // 自动隐藏延迟时间（秒）
    private var _autoHideDelaySeconds: Int = 0
    var autoHideDelaySeconds: Int {
        get { _autoHideDelaySeconds }
        set {
            let clampedValue = max(Self.minAutoHideDelaySeconds, min(Self.maxAutoHideDelaySeconds, newValue))
            if _autoHideDelaySeconds != clampedValue {
                _autoHideDelaySeconds = clampedValue
                defaults.set(clampedValue, forKey: Keys.autoHideDelaySeconds)
                objectWillChange.send()
            }
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            onLaunchAtLoginChanged?(launchAtLogin)
        }
    }

    /// 外部设置的回调，用于响应开机自启动切换
    var onLaunchAtLoginChanged: ((Bool) -> Void)?

    init() {
        // 使用时长限额：1分钟 ~ 120分钟 (7200秒)
        let savedUsage = defaults.integer(forKey: Keys.usageLimitSeconds)
        _usageLimitSeconds = savedUsage > 0 ? savedUsage : Self.defaultUsageLimitSeconds

        // 休息时长：10秒 ~ 20分钟 (1200秒)
        let savedBreak = defaults.integer(forKey: Keys.breakDurationSeconds)
        _breakDurationSeconds = savedBreak > 0 ? savedBreak : Self.defaultBreakDurationSeconds

        // 自动隐藏延迟时间：5秒 ~ 60秒
        let savedAutoHide = defaults.integer(forKey: Keys.autoHideDelaySeconds)
        _autoHideDelaySeconds = savedAutoHide > 0 ? savedAutoHide : Self.defaultAutoHideDelaySeconds

        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.muteOnBreak = defaults.bool(forKey: Keys.muteOnBreak)

        // 默认开启暂停休息事件监测（麦克风检测）
        if defaults.object(forKey: Keys.enableSensitiveAppDetection) == nil {
            self.enableSensitiveAppDetection = true
        } else {
            self.enableSensitiveAppDetection = defaults.bool(forKey: Keys.enableSensitiveAppDetection)
        }
    }
}
