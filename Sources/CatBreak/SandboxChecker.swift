import Foundation

/// 运行时检测当前是否运行在 App Sandbox 内
enum SandboxChecker {
    static var isSandboxed: Bool {
        if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil {
            return true
        }
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }
}
