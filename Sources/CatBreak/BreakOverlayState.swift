import Combine
import SwiftUI

/// 休息遮罩的共享状态，所有屏幕的 CatOverlayView 共享同一个实例
/// 避免每秒重建 NSHostingView 导致多屏窗口丢失
class BreakOverlayState: ObservableObject {
    @Published var remainingSeconds: Int = 0
    @Published var breakCount: Int = 1
    @Published var quote: String = ""
}
