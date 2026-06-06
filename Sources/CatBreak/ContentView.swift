import SwiftUI

struct ContentView: View {
    @ObservedObject var timerManager: TimerManager
    @ObservedObject var settingsStore: SettingsStore

    /// 深色模式检测
    private var isDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    var body: some View {
        VStack(spacing: 0) {
            // ===== 顶部区域：品牌标识 =====
            headerSection

            // ===== 核心区域：计时状态 =====
            timerSection

            // ===== 设置区域 =====
            settingsSection

            // ===== 底部操作区域 =====
            actionSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ?
                    Color(red: 0.11, green: 0.11, blue: 0.13) :
                    Color(red: 0.98, green: 0.98, blue: 0.99))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isDarkMode ?
                    Color.white.opacity(0.08) :
                    Color.black.opacity(0.04), lineWidth: 1)
        )
        .frame(width: 320, height: 550)
    }

    // MARK: - 顶部区域
    private var headerSection: some View {
        HStack(spacing: 10) {
            // 猫咪图标 - 使用渐变色彩
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isDarkMode ?
                                [Color.orange.opacity(0.8), Color.orange.opacity(0.6)] :
                                [Color.orange, Color.orange.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: "cat.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }

            // 应用名称
            VStack(alignment: .leading, spacing: 2) {
                Text("CatBreak")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(isDarkMode ? .white : .primary)
                Text("健康休息提醒")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .secondary)
            }

            Spacer()

            // 状态徽章 - 增强视觉效果
            StatusBadge(state: timerManager.state, isUserAway: timerManager.isUserAway, isDarkMode: isDarkMode)
        }
        .padding(.bottom, 8)
    }

    // MARK: - 计时区域
    private var timerSection: some View {
        VStack(spacing: 6) {
            // 预警横幅 - 优化视觉效果
            if timerManager.isWarning {
                warningBanner
            }

            // 计时卡片 - 主要视觉焦点
            VStack(spacing: 6) {
                Text("本次使用时长")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .secondary)

                // 大时钟显示
                let minutes = timerManager.elapsedSeconds / 60
                let seconds = timerManager.elapsedSeconds % 60

                Text(String(format: "%02d:%02d", minutes, seconds))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(timerColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(timerColor.opacity(0.1))
                    )

                // 进度条 - 增强视觉反馈
                progressBar
            }
            .padding(.vertical, 6)
        }
        .padding(.bottom, 4)
    }

    // MARK: - 预警横幅
    private var warningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.orange)

            Text("即将休息")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.orange)

            Spacer()

            Text(formatCountdown(timerManager.secondsToLimit))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(isDarkMode ? 0.15 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 进度条
    private var progressBar: some View {
        VStack(spacing: 6) {
            // 自定义进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                        .frame(height: 12)

                    // 进度 - 颜色随进度加深
                    let progress = min(max(Double(timerManager.elapsedSeconds) / Double(settingsStore.usageLimitSeconds), 0), 1.0)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: progressColorGradient(for: progress),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 12)
                }
            }
            .frame(height: 12)

            // 进度信息
            HStack {
                let progress = min(max(Double(timerManager.elapsedSeconds) / Double(settingsStore.usageLimitSeconds), 0), 1.0)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .secondary)

                Spacer()

                if timerManager.state == .monitoring || timerManager.isWarning {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("剩余 \(formatCountdown(timerManager.secondsToLimit))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(timerManager.isWarning ? .orange : (isDarkMode ? .white.opacity(0.5) : .secondary))
                }
            }
        }
    }

    // MARK: - 设置区域
    private var settingsSection: some View {
        VStack(spacing: 16) {
            // 分隔线
            Divider()
                .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))

            // 使用时长限额
            TimeSlider(
                title: "使用时长限额",
                value: $settingsStore.usageLimitSeconds,
                range: 60...7200,
                step: 30,
                isDarkMode: isDarkMode,
                accentColor: .blue
            )

            // 休息时长
            TimeSlider(
                title: "休息时长",
                value: $settingsStore.breakDurationSeconds,
                range: 10...1200,
                step: 10,
                isDarkMode: isDarkMode,
                accentColor: .mint
            )

            // 暂停事件监测卡片
            sensitiveAppCard
        }
        .padding(.bottom, 8)
    }

    // MARK: - 暂停事件监测卡片
    private var sensitiveAppCard: some View {
        HStack(spacing: 10) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(timerManager.isInSensitiveApp ?
                        Color.orange.opacity(0.2) :
                        (isDarkMode ? Color.white.opacity(0.08) : Color.blue.opacity(0.1)))
                    .frame(width: 32, height: 32)
                Image(systemName: "shield.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(timerManager.isInSensitiveApp ? .orange : .blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("暂停休息事件监测")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .primary)
                Text("会议/通话时自动推迟")
                    .font(.system(size: 11))
                    .foregroundColor(isDarkMode ? .white.opacity(0.4) : .secondary)
            }

            Spacer()

            // 状态指示
            if timerManager.isInSensitiveApp {
                Text("推迟休息")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(isDarkMode ? 0.2 : 0.12))
                    )
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                    Text("正常")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(timerManager.isInSensitiveApp ?
                    Color.orange.opacity(0.3) :
                    (isDarkMode ? Color.white.opacity(0.08) : Color.blue.opacity(0.15)),
                    lineWidth: 1)
        )
    }

    // MARK: - 底部操作区域
    private var actionSection: some View {
        VStack(spacing: 8) {
            Divider()
                .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))

            // 三个圆形按钮并排
            HStack(spacing: 24) {
                // 休息静音开关
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(settingsStore.muteOnBreak ?
                                Color.purple.opacity(0.2) :
                                (isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04)))
                            .frame(width: 32, height: 32)
                        Image(systemName: settingsStore.muteOnBreak ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(settingsStore.muteOnBreak ? .purple : (isDarkMode ? .white.opacity(0.6) : .secondary))
                    }
                    Text("休息静音")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .primary)
                }
                .frame(width: 70)
                .onTapGesture {
                    settingsStore.muteOnBreak.toggle()
                }

                // 开机自启动开关
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(settingsStore.launchAtLogin ?
                                Color.indigo.opacity(0.2) :
                                (isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04)))
                            .frame(width: 32, height: 32)
                        Image(systemName: "power")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(settingsStore.launchAtLogin ? .indigo : (isDarkMode ? .white.opacity(0.6) : .secondary))
                    }
                    Text("开机自启")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .primary)
                }
                .frame(width: 70)
                .onTapGesture {
                    settingsStore.launchAtLogin.toggle()
                }

                // 退出按钮 - 圆形带叉
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    Text("退出")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .primary)
                }
                .frame(width: 70)
                .onTapGesture {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    // MARK: - 辅助计算属性

    /// 计时器颜色
    private var timerColor: Color {
        switch timerManager.state {
        case .breaking: return .red
        case .warning: return .orange
        case .paused: return isDarkMode ? .white.opacity(0.4) : .gray
        default: return isDarkMode ? .white : .primary
        }
    }

    /// 进度条渐变色 - 根据进度深度变化
    private func progressColorGradient(for progress: Double) -> [Color] {
        // 基础颜色根据状态确定
        let baseColor: Color
        switch timerManager.state {
        case .breaking: baseColor = .red
        case .warning: baseColor = .orange
        case .paused: baseColor = isDarkMode ? .white.opacity(0.5) : .gray
        default: baseColor = .blue
        }

        // 根据进度调整深度：进度越大，颜色越深
        let intensity = 0.4 + progress * 0.5  // 0.4 ~ 0.9
        return [baseColor.opacity(intensity * 0.7), baseColor.opacity(intensity)]
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - 状态徽章（优化版）
struct StatusBadge: View {
    let state: TimerState
    var isUserAway: Bool = false
    var isDarkMode: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            // 状态指示点 - 增加动画效果
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 14, height: 14)
                )

            Text(statusText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(statusColor.opacity(isDarkMode ? 0.2 : 0.12))
        )
        .overlay(
            Capsule()
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch state {
        case .idle: return isDarkMode ? .gray : .gray
        case .monitoring: return .green
        case .paused: return .cyan
        case .warning: return .orange
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