import SwiftUI

// 已安装应用的数据模型
struct InstalledApp: Identifiable, Hashable {
    let id: String          // Bundle ID
    let name: String        // 应用名称
    let url: URL            // 应用路径
    let icon: NSImage       // 应用图标

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id
    }
}

// 扫描已安装应用的工具类
class AppScanner {
    /// 扫描系统中已安装的应用
    static func scanInstalledApps() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        var seenIds = Set<String>()

        let searchPaths = [
            "/Applications",
            NSHomeDirectory() + "/Applications",
            "/System/Applications"
        ]

        for searchPath in searchPaths {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents {
                guard url.pathExtension == "app" else { continue }

                let plistPath = url.appendingPathComponent("Contents/Info.plist").path
                guard let dict = NSDictionary(contentsOfFile: plistPath) else { continue }

                let bundleId = dict["CFBundleIdentifier"] as? String ?? ""
                let appName = dict["CFBundleName"] as? String
                    ?? dict["CFBundleDisplayName"] as? String
                    ?? url.deletingPathExtension().lastPathComponent

                // 去重
                if bundleId.isEmpty || seenIds.contains(bundleId) { continue }
                seenIds.insert(bundleId)

                // 获取图标
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 32, height: 32)

                apps.append(InstalledApp(id: bundleId, name: appName, url: url, icon: icon))
            }
        }

        // 按名称排序
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// 应用选择器视图（作为 Sheet 弹出）
struct AppPickerView: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var allApps: [InstalledApp] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = true

    let onSelect: () -> Void

    var filteredApps: [InstalledApp] {
        if searchText.isEmpty {
            return allApps
        }
        return allApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "app.badge.fill")
                    .foregroundColor(.primary)
                Text("选择敏感应用")
                    .font(.headline)
                Spacer()
                Text("\(settingsStore.sensitiveAppBundleIds.count) 个已选")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)

            Divider()

            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索应用名称或 Bundle ID", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if isLoading {
                Spacer()
                ProgressView("正在扫描应用...")
                Spacer()
            } else {
                // 应用列表
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredApps) { app in
                            AppRow(
                                app: app,
                                isSelected: settingsStore.sensitiveAppBundleIds.contains(app.id),
                                onToggle: {
                                    toggleApp(app.id)
                                }
                            )
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .padding(.top, 4)
            }

            Divider()

            // 底部按钮
            HStack {
                // 手动输入 Bundle ID
                ManualBundleIdInput { bundleId in
                    if !settingsStore.sensitiveAppBundleIds.contains(bundleId) {
                        settingsStore.sensitiveAppBundleIds.append(bundleId)
                    }
                }
                Spacer()
                Button("完成") {
                    onSelect()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
        }
        .frame(width: 400, height: 500)
        .onAppear {
            loadApps()
        }
    }

    private func loadApps() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = AppScanner.scanInstalledApps()
            DispatchQueue.main.async {
                self.allApps = apps
                self.isLoading = false
            }
        }
    }

    private func toggleApp(_ bundleId: String) {
        if settingsStore.sensitiveAppBundleIds.contains(bundleId) {
            settingsStore.sensitiveAppBundleIds.removeAll { $0 == bundleId }
        } else {
            settingsStore.sensitiveAppBundleIds.append(bundleId)
        }
    }
}

// 单个应用行
struct AppRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(nsImage: app.icon)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(app.id)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.primary)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.primary.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// 手动输入 Bundle ID 的折叠区
struct ManualBundleIdInput: View {
    @State private var showInput: Bool = false
    @State private var inputText: String = ""
    let onAdd: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { showInput.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "keyboard")
                        .font(.caption2)
                    Text("手动输入")
                        .font(.caption2)
                    Image(systemName: showInput ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            if showInput {
                HStack(spacing: 4) {
                    TextField("com.example.app", text: $inputText)
                        .font(.caption2)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                    Button(action: {
                        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            onAdd(trimmed)
                            inputText = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
