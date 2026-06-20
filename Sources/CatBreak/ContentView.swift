import SwiftUI

// MARK: - ContentView: Container View
struct ContentView: View {
    @ObservedObject var timerManager: TimerManager
    @ObservedObject var settingsStore: SettingsStore
    @State private var showSettings = false

    /// Dark mode detection
    private var isDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    var body: some View {
        Group {
            if showSettings {
                SettingsView(
                    settingsStore: settingsStore,
                    isDarkMode: isDarkMode,
                    onBack: { showSettings = false }
                )
            } else {
                MainView(
                    timerManager: timerManager,
                    settingsStore: settingsStore,
                    isDarkMode: isDarkMode,
                    onSettingsTap: { showSettings = true }
                )
            }
        }
        .frame(width: 320, height: 550)
    }
}

// MARK: - MainView: Primary Timer Interface
struct MainView: View {
    @ObservedObject var timerManager: TimerManager
    @ObservedObject var settingsStore: SettingsStore
    let isDarkMode: Bool
    let onSettingsTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header Section: Brand Identity
            headerSection

            // Timer Section: Core Status
            timerSection

            // Progress Cards Section
            progressCardsSection

            // Bottom Section: Settings Button
            bottomSection
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
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 10) {
            // Cat Icon with Gradient
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

            // App Name
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("app.name"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(isDarkMode ? .white : .primary)
                Text(L10n.tr("app.tagline"))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .secondary)
            }

            Spacer()

            // Status Badge
            StatusBadge(state: timerManager.state, isUserAway: timerManager.isUserAway, isDarkMode: isDarkMode)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Timer Section
    private var timerSection: some View {
        VStack(spacing: 6) {
            // Timer Card - Primary Focus
            VStack(spacing: 6) {
                Text(L10n.tr("timer.usage_time"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .primary)

                // Large Timer Display
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

                // Progress Bar
                usageProgressBar
            }
            .padding(.vertical, 6)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Usage Progress Bar
    private var usageProgressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                        .frame(height: 12)

                    // Progress - Color deepens with progress
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

            // Progress Info
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
                        Text("\(L10n.tr("timer.remaining")) \(formatCountdown(timerManager.secondsToLimit))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(timerManager.isWarning ? .orange : (isDarkMode ? .white.opacity(0.5) : .secondary))
                }
            }
        }
    }

    // MARK: - Progress Cards Section
    private var progressCardsSection: some View {
        VStack(spacing: 12) {
            Divider()
                .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))

            // Usage Limit Slider
            TimeSlider(
                title: L10n.tr("settings.title"),
                value: $settingsStore.usageLimitSeconds,
                range: 60...7200,
                step: 30,
                isDarkMode: isDarkMode,
                accentColor: .blue
            )

            Divider()
                .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))

            // Break Duration Slider
            TimeSlider(
                title: L10n.tr("settings.break_duration"),
                value: $settingsStore.breakDurationSeconds,
                range: 10...1200,
                step: 10,
                isDarkMode: isDarkMode,
                accentColor: .mint
            )

            Divider()
                .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))

            // Break Duration Progress Card (shown when in break)
            if timerManager.state == .breaking {
                ProgressCard(
                    title: L10n.tr("settings.break_duration"),
                    icon: "cup.and.saucer.fill",
                    iconColor: .mint,
                    progress: 1.0 - Double(timerManager.currentBreakRemaining) / Double(settingsStore.breakDurationSeconds),
                    isDarkMode: isDarkMode,
                    accentColor: .orange
                )
            }

            // Sensitive App Detection Card
            sensitiveAppCard
        }
        .padding(.bottom, 8)
    }

    // MARK: - Sensitive App Card
    private var sensitiveAppCard: some View {
        HStack(spacing: 10) {
            // 根据功能开启状态和麦克风占用状态决定图标颜色
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(sensitiveAppStatus.color.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: "shield.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(sensitiveAppStatus.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("settings.sensitive_app"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .primary)
                Text(L10n.tr("settings.sensitive_app_hint"))
                    .font(.system(size: 11))
                    .foregroundColor(isDarkMode ? .white.opacity(0.4) : .secondary)
            }

            Spacer()

            // 状态显示：已禁用 / 正常 / 推迟休息
            switch sensitiveAppStatus {
            case .disabled:
                Text(L10n.tr("settings.disabled"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(isDarkMode ? 0.2 : 0.12))
                    )
            case .normal:
                VStack(alignment: .trailing, spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                    Text(L10n.tr("settings.normal"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                }
            case .deferred:
                Text(L10n.tr("settings.defer_break"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(isDarkMode ? 0.2 : 0.12))
                    )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(sensitiveAppStatus.color.opacity(0.3),
                    lineWidth: 1)
        )
    }

    // MARK: - Sensitive App Status
    private enum SensitiveAppStatus {
        case disabled  // 功能已关闭
        case normal    // 功能开启，麦克风未被占用
        case deferred  // 功能开启，麦克风被占用

        var color: Color {
            switch self {
            case .disabled: return .gray
            case .normal: return .green
            case .deferred: return .orange
            }
        }
    }

    private var sensitiveAppStatus: SensitiveAppStatus {
        if !settingsStore.enableSensitiveAppDetection {
            return .disabled
        } else if timerManager.isInSensitiveApp {
            return .deferred
        } else {
            return .normal
        }
    }

    // MARK: - Bottom Section
    private var bottomSection: some View {
        VStack(spacing: 8) {
            Divider()
                .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))

            // Settings Button
            Button(action: onSettingsTap) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .medium))
                    Text(L10n.tr("action.settings"))
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .primary)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helper Properties

    /// Timer color based on state
    private var timerColor: Color {
        switch timerManager.state {
        case .breaking: return .red
        case .warning: return .orange
        case .paused: return isDarkMode ? .white.opacity(0.4) : .gray
        default: return isDarkMode ? .white : .primary
        }
    }

    /// Progress bar gradient color - deepens with progress
    private func progressColorGradient(for progress: Double) -> [Color] {
        let baseColor: Color
        switch timerManager.state {
        case .breaking: baseColor = .red
        case .warning: baseColor = .orange
        case .paused: baseColor = isDarkMode ? .white.opacity(0.5) : .gray
        default: baseColor = .blue
        }

        let intensity = 0.4 + progress * 0.5
        return [baseColor.opacity(intensity * 0.7), baseColor.opacity(intensity)]
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - SettingsView: Settings Interface
struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    let isDarkMode: Bool
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with Back Button
            headerSection

            // Settings Content
            settingsContent

            // Bottom Action Section
            bottomSection
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
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 12) {
            // Back Button
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .primary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                    )
            }
            .buttonStyle(.plain)

            Text(L10n.tr("action.settings"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(isDarkMode ? .white : .primary)

            Spacer()
        }
        .padding(.bottom, 12)
    }

    // MARK: - Settings Content
    private var settingsContent: some View {
        VStack(spacing: 10) {
            Divider()
                .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))

            // Auto-hide Delay Slider
            TimeSlider(
                title: L10n.tr("settings.auto_hide_delay"),
                value: $settingsStore.autoHideDelaySeconds,
                range: 5...60,
                step: 1,
                isDarkMode: isDarkMode,
                accentColor: .cyan
            )

            Divider()
                .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))

            // Sensitive App Detection Toggle
            toggleRow(
                title: L10n.tr("settings.sensitive_app"),
                subtitle: L10n.tr("settings.sensitive_app_hint"),
                icon: "shield.fill",
                iconColor: .blue,
                isOn: $settingsStore.enableSensitiveAppDetection
            )

            Divider()
                .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))

            // Mute on Break Toggle
            toggleRow(
                title: L10n.tr("action.mute"),
                subtitle: muteSupported ? "" : L10n.tr("accessibility.mute_unsupported"),
                icon: "speaker.slash.fill",
                iconColor: .purple,
                isOn: $settingsStore.muteOnBreak
            )
            .opacity(muteSupported ? 1.0 : 0.45)
            .disabled(!muteSupported)

            Divider()
                .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))

            // Launch at Login Toggle
            toggleRow(
                title: L10n.tr("action.autostart"),
                subtitle: "",
                icon: "power",
                iconColor: .indigo,
                isOn: $settingsStore.launchAtLogin
            )

            Divider()
                .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))

            // Language Picker
            languagePicker

            Spacer()
        }
    }

    // MARK: - Language Picker
    private var languagePicker: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                    .frame(width: 28, height: 28)
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)
            }

            Text(L10n.tr("settings.language"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .primary)

            Spacer()

            Picker("", selection: Binding(
                get: { LanguageManager.shared.current },
                set: { LanguageManager.shared.current = $0 }
            )) {
                ForEach(LanguageManager.AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
        }
        .padding(.vertical, 8)
    }

    private var languageManager: LanguageManager {
        LanguageManager.shared
    }

    private var muteSupported: Bool { MuteCapability.isSupported }

    // MARK: - Toggle Row
    private func toggleRow(title: String, subtitle: String, icon: String, iconColor: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isOn.wrappedValue ?
                        Color.blue.opacity(0.15) :
                        (isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04)))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isOn.wrappedValue ? .blue : (isDarkMode ? .white.opacity(0.6) : .secondary))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .primary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(isDarkMode ? .white.opacity(0.4) : .secondary)
                }
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, subtitle.isEmpty ? 8 : 6)
    }

    // MARK: - Bottom Section
    private var bottomSection: some View {
        VStack(spacing: 8) {
            Divider()
                .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))

            // About and Quit buttons in a row
            HStack(spacing: 12) {
                // About Button
                Button(action: { showAboutDialog = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13, weight: .semibold))
                        Text(L10n.tr("action.about"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .alert(isPresented: $showAboutDialog) {
                    Alert(
                        title: Text(L10n.tr("about.title")),
                        message: Text("\(L10n.tr("about.version")) 3.0.0\n\n\(L10n.tr("about.description"))\n\(L10n.tr("about.features"))"),
                        primaryButton: .default(Text(L10n.tr("about.github"))) {
                            if let url = URL(string: "https://github.com/bbly-oneday/CatBreak") {
                                NSWorkspace.shared.open(url)
                            }
                        },
                        secondaryButton: .cancel(Text(L10n.tr("action.back")))
                    )
                }

                // Quit Button
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                        Text(L10n.tr("action.quit"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @State private var showAboutDialog = false
}

// MARK: - Progress Card Component
struct ProgressCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let progress: Double
    let isDarkMode: Bool
    var accentColor: Color = .blue

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .primary)

                // Mini Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.6), accentColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * min(progress, 1.0), height: 6)
                    }
                }
                .frame(height: 6)
            }

            Spacer()

            // Percentage
            Text("\(Int(progress * 100))%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(accentColor)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}

// MARK: - Status Badge (Optimized)
struct StatusBadge: View {
    let state: TimerState
    var isUserAway: Bool = false
    var isDarkMode: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            // Status Dot - Enhanced with animation
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
        case .idle: return L10n.tr("status.idle")
        case .monitoring: return isUserAway ? L10n.tr("status.away") : L10n.tr("status.monitoring")
        case .paused: return L10n.tr("status.away")
        case .warning: return L10n.tr("status.warning")
        case .breaking: return L10n.tr("status.breaking")
        }
    }
}