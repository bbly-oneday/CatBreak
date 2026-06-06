import SwiftUI

struct TimeSlider: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(value) \(unit)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }

            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
            .tint(.orange)

            HStack {
                Text("\(range.lowerBound)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(range.upperBound)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
