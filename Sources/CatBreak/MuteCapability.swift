import Foundation

/// 当前构建是否支持系统级「休息静音」
/// - DMG 版：支持（非沙盒，CoreAudio 可写 mute）
/// - App Store 版：不支持（沙盒无控制输出设备静音的 entitlement）
enum MuteCapability {
    static var isSupported: Bool {
        #if APPSTORE
        return false
        #else
        return true
        #endif
    }
}
