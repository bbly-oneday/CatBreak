import SwiftUI

struct TimeSlider: View {
    let title: String
    @Binding var value: Int  // 内部存储为秒
    let range: ClosedRange<Int>  // 秒为单位
    var step: Int = 30  // 步进（秒），默认30秒

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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(displayValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .monospacedDigit()
            }

            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { newValue in
                        // 按 step 对齐
                        let stepped = round(newValue / Double(step)) * Double(step)
                        value = Int(stepped)
                    }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step)
            )

            HStack {
                Text(formatBound(range.lowerBound))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatBound(range.upperBound))
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
}