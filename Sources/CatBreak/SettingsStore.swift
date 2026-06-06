import Foundation
import Combine

class SettingsStore: ObservableObject {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let usageLimitSeconds = "usageLimitSeconds"
        static let breakDurationSeconds = "breakDurationSeconds"
        static let launchAtLogin = "launchAtLogin"
        static let muteOnBreak = "muteOnBreak"
    }

    // 休息时自动静音
    @Published var muteOnBreak: Bool {
        didSet {
            defaults.set(muteOnBreak, forKey: Keys.muteOnBreak)
        }
    }

    // 使用时长限额（秒）
    @Published var usageLimitSeconds: Int {
        didSet {
            defaults.set(usageLimitSeconds, forKey: Keys.usageLimitSeconds)
        }
    }

    // 休息时长（秒）
    @Published var breakDurationSeconds: Int {
        didSet {
            defaults.set(breakDurationSeconds, forKey: Keys.breakDurationSeconds)
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
        self.usageLimitSeconds = savedUsage > 0 ? savedUsage : 3600  // 默认60分钟

        // 休息时长：10秒 ~ 20分钟 (1200秒)
        let savedBreak = defaults.integer(forKey: Keys.breakDurationSeconds)
        self.breakDurationSeconds = savedBreak > 0 ? savedBreak : 300  // 默认5分钟

        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.muteOnBreak = defaults.bool(forKey: Keys.muteOnBreak)
    }
}
