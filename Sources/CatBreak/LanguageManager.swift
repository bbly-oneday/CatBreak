import Foundation
import Combine

/// 应用内语言选择。
///
/// 支持「简体中文 / English」二选一，切换后通过 `objectWillChange`
/// 通知所有观察的视图刷新；本地化字符串由 `L10n` 根据当前语言从对应 `.lproj` 取值，
/// 绕过 `Bundle.main` 的语言缓存，实现无需重启的即时切换。
@MainActor
final class LanguageManager: ObservableObject {

    enum AppLanguage: String, CaseIterable, Identifiable {
        case zhHans = "zh-Hans"
        case en

        var id: String { rawValue }

        /// 设置界面显示名
        var displayName: String {
            switch self {
            case .zhHans: return "简体中文"
            case .en: return "English"
            }
        }
    }

    static let shared = LanguageManager()

    @Published var current: AppLanguage {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: LanguageManager.storageKey)
        }
    }

    /// 实际解析出的语言代码（"zh-Hans" / "en"），供 L10n 取 .lproj 用
    var resolvedCode: String {
        switch current {
        case .zhHans: return "zh-Hans"
        case .en: return "en"
        }
    }

    private static let storageKey = "appLanguage"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: LanguageManager.storageKey),
           let lang = AppLanguage(rawValue: raw) {
            current = lang
        } else {
            // 默认中文
            current = .zhHans
        }
    }
}
