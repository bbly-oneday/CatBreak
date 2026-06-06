import SwiftUI

struct ContentView: View {
    @ObservedObject var timerManager: TimerManager
    @ObservedObject var settingsStore: SettingsStore

    @State private var elapsedMinutes: Int = 0
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "cat.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("CatBreak")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                StatusBadge(state: timerManager.state)
            }

            Divider()

            // Timer display
            VStack(spacing: 4) {
                Text("Session Time")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%02d:%02d", elapsedMinutes, elapsedSeconds))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(timerManager.state == .breaking ? .red : .primary)
            }
            .padding(.vertical, 8)

            // Progress bar
            ProgressView(value: min(Double(timerManager.elapsedSeconds) / Double(settingsStore.usageLimitSeconds), 1.0))
                .tint(timerManager.state == .breaking ? .red : .orange)

            Text("\(Int(Double(timerManager.elapsedSeconds) / Double(settingsStore.usageLimitSeconds) * 100))% of limit")
                .font(.caption2)
                .foregroundColor(.secondary)

            Divider()

            // Settings
            VStack(spacing: 16) {
                TimeSlider(
                    title: "Usage Limit",
                    value: Binding(
                        get: { settingsStore.usageLimitMinutes },
                        set: { settingsStore.usageLimitMinutes = $0 }
                    ),
                    range: 5...120,
                    unit: "min"
                )

                TimeSlider(
                    title: "Break Duration",
                    value: Binding(
                        get: { settingsStore.breakDurationMinutes },
                        set: { settingsStore.breakDurationMinutes = $0 }
                    ),
                    range: 1...30,
                    unit: "min"
                )
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 320, height: 280)
        .onAppear {
            startUIUpdateTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: timerManager.elapsedSeconds) { _, newValue in
            elapsedMinutes = newValue / 60
            elapsedSeconds = newValue % 60
        }
    }

    private func startUIUpdateTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Force UI refresh by accessing elapsedSeconds
            _ = timerManager.elapsedSeconds
        }
    }
}

struct StatusBadge: View {
    let state: TimerState

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        switch state {
        case .idle: return .gray
        case .monitoring: return .green
        case .breaking: return .red
        }
    }

    private var statusText: String {
        switch state {
        case .idle: return "Idle"
        case .monitoring: return "Monitoring"
        case .breaking: return "Break!"
        }
    }
}
