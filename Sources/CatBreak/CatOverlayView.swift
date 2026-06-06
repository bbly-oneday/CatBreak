import SwiftUI

struct CatOverlayView: View {
    @ObservedObject var state: BreakOverlayState

    /// 固定遮罩透明度（无动画）
    private var fixedOverlayOpacity: Double {
        isDarkMode ? 0.8 : 0.75
    }

    /// 深色模式检测
    private var isDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    /// 预加载背景图片
    private static let cachedBackgroundImage: NSImage? = {
        if let path = Bundle.main.path(forResource: "catbreak", ofType: "jpg") {
            return NSImage(contentsOfFile: path)
        }
        return nil
    }()

    var body: some View {
        ZStack {
            // 背景图
            if let nsImage = Self.cachedBackgroundImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    gradient: Gradient(colors: isDarkMode ? [
                        Color(red: 0.02, green: 0.02, blue: 0.05),
                        Color(red: 0.04, green: 0.04, blue: 0.08),
                        Color(red: 0.03, green: 0.05, blue: 0.07)
                    ] : [
                        Color(red: 0.05, green: 0.08, blue: 0.18),
                        Color(red: 0.08, green: 0.12, blue: 0.25),
                        Color(red: 0.06, green: 0.15, blue: 0.22)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }

            // 深色遮罩：固定透明度，无动画
            Color.black
                .opacity(fixedOverlayOpacity)
                .ignoresSafeArea()

            // 静态柔光
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.04),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 100,
                        endRadius: 500
                    )
                )
                .frame(width: 600, height: 600)
                .offset(x: -60, y: -200)

            VStack(spacing: 20) {
                Spacer()

                // 第N次休息
                if state.breakCount > 1 {
                    Text("第 \(state.breakCount) 次休息")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                }

                // 猫咪图标
                Image(systemName: "cat.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.7))

                // 名人语录
                Text("「\(state.quote)」")
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .italic()
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 48)

                // 主标题
                Text("该休息啦")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // 倒计时
                VStack(spacing: 8) {
                    Text("休息倒计时")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))

                    Text(formatTime(state.remainingSeconds))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 36)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                }

                Spacer()

                // 底部提示
                Text("喝杯水  ·  站起来  ·  看远方  ·  想想未来")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.bottom, 30)
            }
            .padding(44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
