import Foundation

/// 本地化字符串取值入口。
///
/// 根据 `LanguageManager.shared.resolvedCode` 直接从对应 `.lproj` 取值，
/// 绕过 `Bundle.main` 的 `AppleLanguages` 缓存，使应用内语言切换即时生效（无需重启）。
///
/// 用法：`L10n.tr("settings.usage_limit")`
enum L10n {

    /// 按 key 取本地化字符串，回退到 key 本身
    /// 需在主线程调用（因为访问 `LanguageManager.shared.resolvedCode`）
    @MainActor
    static func tr(_ key: String) -> String {
        let lang = LanguageManager.shared.resolvedCode
        if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        }
        return Bundle.main.localizedString(forKey: key, value: nil, table: "Localizable")
    }
}
