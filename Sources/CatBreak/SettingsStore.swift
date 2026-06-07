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

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let usageLimitSeconds = "usageLimitSeconds"
        static let breakDurationSeconds = "breakDurationSeconds"
        static let launchAtLogin = "launchAtLogin"
        static let muteOnBreak = "muteOnBreak"
        static let sensitiveAppBundleIds = "sensitiveAppBundleIds"
    }

    // 休息时自动静音
    @Published var muteOnBreak: Bool {
        didSet {
            defaults.set(muteOnBreak, forKey: Keys.muteOnBreak)
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

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            onLaunchAtLoginChanged?(launchAtLogin)
        }
    }

    // 敏感应用 Bundle ID 列表
    @Published var sensitiveAppBundleIds: [String] {
        didSet {
            defaults.set(sensitiveAppBundleIds, forKey: Keys.sensitiveAppBundleIds)
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

        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.muteOnBreak = defaults.bool(forKey: Keys.muteOnBreak)
        self.sensitiveAppBundleIds = defaults.stringArray(forKey: Keys.sensitiveAppBundleIds) ?? []
    }
}
