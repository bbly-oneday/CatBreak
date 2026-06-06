import SwiftUI

struct ContentView: View {
    @ObservedObject var timerManager: TimerManager
    @ObservedObject var settingsStore: SettingsStore

    @State private var elapsedMinutes: Int = 0
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?
    @State private var showStats: Bool = false

    /// 深色模式检测
    private var isDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    var body: some View {
        VStack(spacing: 10) {
            // 标题栏 — 加顶部安全距离
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "cat.fill")
                    .font(.title3)
                    .foregroundColor(isDarkMode ? .orange : .primary)
                Text("CatBreak")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                StatusBadge(state: timerManager.state, isUserAway: timerManager.isUserAway)
            }
            .padding(.top, 4) // 额外顶部距离，防止被裁切

            // 预警横幅
            if timerManager.isWarning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("即将休息，请保存工作！")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                    Spacer()
                    Text(formatCountdown(timerManager.secondsToLimit))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(isDarkMode ? 0.15 : 0.1))
                .cornerRadius(8)
                .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: timerManager.isWarning)
            }

            Divider()

            // 计时显示
            VStack(spacing: 4) {
                Text("本次使用时长")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%02d:%02d", elapsedMinutes, elapsedSeconds))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(timerManager.state == .breaking ? .red : (timerManager.isWarning ? .yellow : .primary))

                // 暂停休息事件状态指示
                if timerManager.isInSensitiveApp && timerManager.state == .monitoring {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text(timerManager.sensitiveAppReason ?? "检测到暂停休息事件")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 6)

            // 进度条
            let progress = min(max(Double(timerManager.elapsedSeconds) / Double(settingsStore.usageLimitSeconds), 0), 1.0)
            ProgressView(value: progress)
                .tint(timerManager.state == .breaking ? .red : (timerManager.isWarning ? .yellow : (timerManager.state == .paused ? .gray : .blue)))

            HStack {
                Text("\(Int(progress * 100))% / 限额")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if timerManager.state == .monitoring || timerManager.isWarning {
                    Text("剩余 \(formatCountdown(timerManager.secondsToLimit))")
                        .font(.caption2)
                        .foregroundColor(timerManager.isWarning ? .yellow : .secondary)
                }
            }

            Divider()

            // 设置
            VStack(spacing: 10) {
                TimeSlider(
                    title: "使用时长限额",
                    value: $settingsStore.usageLimitSeconds,
                    range: 60...7200,
                    step: 30
                )

                TimeSlider(
                    title: "休息时长",
                    value: $settingsStore.breakDurationSeconds,
                    range: 10...1200,
                    step: 10
                )

                // 静音 + 开机自启动 + 退出
                HStack(spacing: 0) {
                    // 休息静音 — 竖排两行
                    Toggle(isOn: $settingsStore.muteOnBreak) {
                        VStack(spacing: 1) {
                            Image(systemName: "speaker.slash.fill")
                                .font(.caption)
                            Text("休息\n静音")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize()
                        }
                    }
                    .toggleStyle(.switch)

                    Spacer()

                    // 开机自启动 — 竖排两行
                    Toggle(isOn: $settingsStore.launchAtLogin) {
                        VStack(spacing: 1) {
                            Image(systemName: "power")
                                .font(.caption)
                            Text("开机\n自启动")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize()
                        }
                    }
                    .toggleStyle(.switch)

                    Spacer()

                    // 退出 — 加大加粗更醒目
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                            Text("退出")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.black)
                }

                Divider()

                // 暂停休息事件监测
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("暂停休息事件监测")
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                    Circle()
                        .fill(timerManager.isInSensitiveApp ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    Text(timerManager.isInSensitiveApp ? "有" : "无")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.06))
                )

                Divider()

                // 每日统计 — 可展开
                VStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showStats.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: showStats ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 12)
                            Image(systemName: "chart.bar.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("今日统计")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if showStats {
                        VStack(spacing: 6) {
                            HStack {
                                Label("使用时长", systemImage: "clock.fill")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(timerManager.todayStats.formattedTotalUsage)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            HStack {
                                Label("休息次数", systemImage: "cup.and.saucer.fill")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(timerManager.todayStats.breakCount) 次")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            HStack {
                                Label("跳过/推迟", systemImage: "forward.fill")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(timerManager.todayStats.skippedCount) 次")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            HStack {
                                Label("最长连续", systemImage: "flame.fill")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(timerManager.todayStats.formattedLongestContinuous)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                        }
                        .padding(.top, 2)
                        .padding(.leading, 18)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)     // 顶部加大内边距，避免图标被裁切
        .padding(.bottom, 14)
        .frame(width: 300, height: 520)
        .onAppear {
            startUIUpdateTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: timerManager.elapsedSeconds) { newValue in
            elapsedMinutes = newValue / 60
            elapsedSeconds = newValue % 60
        }
    }

    private func startUIUpdateTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            _ = timerManager.elapsedSeconds
            // 定期持久化统计
            if timerManager.elapsedSeconds % 30 == 0 {
                timerManager.todayStats.save()
            }
        }
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct StatusBadge: View {
    let state: TimerState
    var isUserAway: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption2)
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
        case .paused: return .blue
        case .warning: return .yellow
        case .breaking: return .red
        }
    }

    private var statusText: String {
        switch state {
        case .idle: return "待机"
        case .monitoring: return isUserAway ? "已离开" : "监控中"
        case .paused: return "已离开"
        case .warning: return "即将休息"
        case .breaking: return "休息中"
        }
    }
}
