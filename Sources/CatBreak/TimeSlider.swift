import SwiftUI

struct TimeSlider: View {
    let title: String
    @Binding var value: Int  // 内部存储为秒
    let range: ClosedRange<Int>  // 秒为单位
    var step: Int = 30  // 步进（秒），默认30秒
    var isDarkMode: Bool = false
    var accentColor: Color = .blue

    // 根据值显示友好文字
    private var displayValue: String {
        if value < 60 {
            return "\(value)秒"
        } else if value % 60 == 0 {
            return "\(value / 60)分钟"
        } else {
            let min = value / 60
            let sec = value % 60
            return "\(min)分\(sec)秒"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题行 - 增强视觉层次
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .primary)

                Spacer()

                // 数值显示卡片
                Text(displayValue)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accentColor, accentColor.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }

            // 自定义滑块 - 更美观的设计
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                        .frame(height: 8)

                    // 刻度标记 - 4个均匀分布的浅色刻度
                    ForEach(1..<4, id: \.self) { index in
                        Rectangle()
                            .fill(isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
                            .frame(width: 1, height: 12)
                            .offset(x: geometry.size.width * CGFloat(index) / 4 - 0.5)
                    }

                    // 已选区域 - 颜色随数值加深
                    let progress = Double(value - range.lowerBound) / Double(range.upperBound - range.lowerBound)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: sliderGradientColors(for: progress),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)

                    // 滑块指示器
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .fill(accentColor)
                                .frame(width: 12, height: 12)
                        )
                        .shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                        .offset(x: geometry.size.width * progress - 9)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    let location = max(0, min(1, gesture.location.x / geometry.size.width))
                                    let newValue = range.lowerBound + Int(location * Double(range.upperBound - range.lowerBound))
                                    let stepped = round(Double(newValue) / Double(step)) * Double(step)
                                    value = Int(stepped)
                                }
                        )
                }
                // 支持点击整个轨道区域
                .contentShape(Rectangle())
                .onTapGesture { location in
                    let tapLocation = location.x / geometry.size.width
                    let clampedLocation = max(0, min(1, tapLocation))
                    let newValue = range.lowerBound + Int(clampedLocation * Double(range.upperBound - range.lowerBound))
                    let stepped = round(Double(newValue) / Double(step)) * Double(step)
                    value = Int(stepped)
                }
            }
            .frame(height: 18)

            // 范围标签
            HStack {
                Text(formatBound(range.lowerBound))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.4) : .secondary)

                Spacer()

                Text(formatBound(range.upperBound))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.4) : .secondary)
            }
        }
    }

    private func formatBound(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)秒"
        } else if seconds % 60 == 0 {
            return "\(seconds / 60)分钟"
        } else {
            return "\(seconds)秒"
        }
    }

    /// 滑块渐变色 - 数值越大颜色越深
    private func sliderGradientColors(for progress: Double) -> [Color] {
        // 进度越大，颜色越深，但不夸张
        let intensity = 0.4 + progress * 0.45  // 0.4 ~ 0.85
        return [accentColor.opacity(intensity * 0.7), accentColor.opacity(intensity)]
    }
}