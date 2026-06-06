# CatBreak 详细设计文档

> 版本: 1.6.0 | 反向推导 | 2026-05-25

---

## 1. 架构总览

### 1.1 分层架构

```
┌─────────────────────────────────────────────────────┐
│                   Presentation Layer                 │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │ ContentView  │  │CatOverlayView│  │AppPicker- │ │
│  │  (设置面板)   │  │  (休息覆盖)   │  │  View     │ │
│  └──────┬───────┘  └──────┬───────┘  └─────┬─────┘ │
│         │                 │                 │       │
├─────────┼─────────────────┼─────────────────┼───────┤
│         │          ViewModel Layer          │       │
│  ┌──────┴───────┐  ┌──────┴───────┐         │       │
│  │ TimerManager │  │ QuoteStore  │         │       │
│  │  (计时状态机) │  │  (名言库)   │         │       │
│  └──────┬───────┘  └─────────────┘         │       │
│         │                                    │       │
├─────────┼────────────────────────────────────┼───────┤
│         │           Service Layer            │       │
│  ┌──────┴──────────┐  ┌──────────────────┐  │       │
│  │ActiveAppMonitor │  │SensitiveApp-     │  │       │
│  │  (活跃应用监控)   │  │  Detector        │  │       │
│  │  (输入事件监控)   │  │  (敏感应用检测)    │  │       │
│  └──────┬──────────┘  └────────┬─────────┘  │       │
│         │                      │             │       │
├─────────┼──────────────────────┼─────────────┼───────┤
│         │      Data Layer      │             │       │
│  ┌──────┴──────────────────────┴──────────┐  │       │
│  │           SettingsStore                │  │       │
│  │        (UserDefaults 持久化)            │  │       │
│  └────────────────────────────────────────┘  │       │
│                                              │       │
├──────────────────────────────────────────────┼───────┤
│                  AppDelegate                 │       │
│          (应用生命周期 + 窗口管理)             │       │
└──────────────────────────────────────────────┘       │
```

### 1.2 依赖方向

```
AppDelegate ──owns──> TimerManager ──reads──> SettingsStore
     │                    │
     │                    ├──notifies──> ContentView (via @ObservableObject)
     │                    ├──notifies──> CatOverlayView (via @ObservableObject)
     │                    └──reads──> ActiveAppMonitor
     │
     ├──owns──> SettingsStore (via @ObservedObject)
     ├──owns──> QuoteStore
     ├──owns──> ActiveAppMonitor ──calls──> TimerManager.tick()
     ├──owns──> SensitiveAppDetector ──calls──> TimerManager
     └──manages──> BreakOverlayWindow[] (one per screen)
```

关键原则:
- **TimerManager** 是核心枢纽, 不依赖任何 UI 组件
- **SettingsStore** 是唯一的数据源 (Single Source of Truth), 通过 UserDefaults 同步
- UI 层通过 `@ObservedObject` / `@EnvironmentObject` 响应式绑定

---

## 2. 核心模块设计

### 2.1 TimerManager — 计时状态机

```
                         ┌──────────────────────────────┐
                         │       TimerManager            │
                         │   (ObservableObject)          │
                         ├──────────────────────────────┤
                         │ @Published state: TimerState  │
                         │ @Published elapsedSeconds     │
                         │ @Published breakRemaining     │
                         │ @Published breakCount: Int    │
                         │ @Published sensitiveWarning   │
                         │                              │
                         │ settings: SettingsStore       │
                         ├──────────────────────────────┤
                         │ + tick()                      │
                         │ + startBreak()                │
                         │ + endBreak()                  │
                         │ + handleSensitiveAppDetected()│
                         │ + resetElapsed()              │
                         └──────────────────────────────┘
```

#### 2.1.1 状态枚举

```swift
enum TimerState {
    case idle        // 待机: 等待用户活动
    case monitoring  // 监控: 累计使用时长
    case paused      // 离开: 用户暂时离开
    case breaking    // 休息: 全屏覆盖中
}
```

#### 2.1.2 状态转换表

| 当前状态 | 事件 | 下一状态 | 附加动作 |
|----------|------|----------|----------|
| idle | 检测到用户输入 | monitoring | resetElapsed() |
| monitoring | elapsed >= usageLimit | breaking | startBreak() |
| monitoring | 无输入 > 3min | paused | — |
| paused | 检测到输入, 离开 < 10min | monitoring | — |
| paused | 离开 ≥ 10min | idle | resetElapsed() |
| breaking | breakRemaining == 0 | idle | endBreak(), breakCount++ |
| breaking | 敏感应用检测到活跃 | idle | endBreak() (提前终止) |

#### 2.1.3 推迟机制 (敏感应用)

```
monitoring 状态下 elapsed >= usageLimit:
  │
  ├─ 敏感应用活跃 且 推迟时长 < 600s?
  │   YES → 不进入 breaking, 显示 sensitiveWarning
  │         tick() 继续, 10秒后再次检查
  │         (推迟最长 600 秒后强制执行)
  │
  └─ NO → 直接进入 breaking
```

#### 2.1.4 关键方法伪代码

```swift
func tick() {
    switch state {
    case .idle:
        break
    case .monitoring:
        elapsedSeconds += 1
        if elapsedSeconds >= settings.usageLimitSeconds {
            if sensitiveAppDetector.isActive && deferCountdown > 0 {
                sensitiveWarning = "会议/视频中，推迟休息"
                deferCountdown -= 1
                if deferCountdown <= 0 { startBreak() }
            } else {
                startBreak()
            }
        }
    case .paused:
        break // 不计时
    case .breaking:
        breakRemaining -= 1
        if breakRemaining <= 0 { endBreak() }
    }
}

func startBreak() {
    state = .breaking
    breakRemaining = settings.breakDurationSeconds
    muteIfNeeded()
    // AppDelegate 创建全屏覆盖窗口
}

func endBreak() {
    state = .idle
    breakRemaining = 0
    elapsedSeconds = 0
    breakCount += 1
    unmuteIfNeeded()
    // AppDelegate 销毁全屏覆盖窗口
}
```

---

### 2.2 ActiveAppMonitor — 活跃检测

```
┌──────────────────────────────────────────┐
│           ActiveAppMonitor               │
├──────────────────────────────────────────┤
│ Properties:                              │
│   - timerManager: TimerManager           │
│   - lastInputTime: Date                  │
│   - monitoringTimer: Timer?  (1s间隔)    │
│   - eventMonitor: Any?                   │
│                                          │
│ Methods:                                 │
│   + startMonitoring()                    │
│   + stopMonitoring()                     │
│   - handleInputEvent()                   │
│   - checkIdleState()                     │
└──────────────────────────────────────────┘
```

#### 2.2.1 输入事件监控

```
NSEvent.addGlobalMonitorForEvents(matching: [
    .mouseMoved,
    .leftMouseDown,
    .rightMouseDown,
    .keyDown,
    .scrollWheel
])
```

#### 2.2.2 空闲检测流程

```
每隔 1 秒:
  now - lastInputTime:
    │
    ├─ < 3 分钟 → 用户活跃
    │   ├─ state == idle → 转为 monitoring
    │   ├─ state == paused → 转为 monitoring (恢复)
    │   └─ state == monitoring → tick()
    │
    ├─ 3~10 分钟 → 用户离开
    │   └─ state == monitoring → 转为 paused
    │
    └─ > 10 分钟 → 用户长时间离开
        └─ state == paused → 转为 idle, 重置计时
```

---

### 2.3 SensitiveAppDetector — 敏感应用检测

```
┌──────────────────────────────────────────┐
│          SensitiveAppDetector            │
├──────────────────────────────────────────┤
│ Properties:                              │
│   - sensitiveBundleIds: [String]         │
│   - isActive: Bool                       │
│   - detectionTimer: Timer?  (10s/5s间隔) │
│                                          │
│ Methods:                                 │
│   + checkAsync() → Bool                  │
│   - classifyApp(bundleId) → AppCategory  │
│   - checkWindowTitles(app) → Bool        │
│   - checkMicrophone() → Bool             │
│   - checkWindowHeuristics(app) → Bool    │
└──────────────────────────────────────────┘
```

#### 2.3.1 检测决策树

```
checkAsync():
  for each running app:
    if app.bundleId in sensitiveBundleIds:
      │
      ├─ classifyApp(bundleId):
      │   ├─ meetingApp → 检测会议状态
      │   ├─ commApp    → 检测通话状态
      │   └─ other      → 直接标记活跃
      │
      ├─ checkWindowTitles() → 匹配关键词?
      │   YES → return true
      │
      ├─ checkMicrophone() → 麦克风在使用?
      │   YES → return true
      │
      └─ checkWindowHeuristics() → 窗口启发式匹配?
          YES → return true

  return false
```

#### 2.3.2 关键词字典

```swift
let meetingKeywords = [
    "会议中", "会议进行中", "正在开会",
    "视频中", "音频中", "共享屏幕", "邀请你加入",
    "Meeting in Progress", "In Meeting",
    "Screen Sharing", "Zoom Meeting",
    "Microsoft Teams Meeting"
]

let callKeywords = [
    "语音通话", "视频通话", "通话中",
    "Calling", "Voice Call"
]
```

#### 2.3.3 麦克风检测 (CoreAudio)

```swift
func checkMicrophone() -> Bool {
    // 1. 获取默认输入设备
    var defaultInputDevice = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    AudioObjectGetPropertyData(..., &defaultInputDevice)

    // 2. 检查是否正在运行
    var isRunning: UInt32 = 0
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    AudioObjectGetPropertyData(deviceID, &propertyAddress, &isRunning)
    return isRunning == 1
}
```

#### 2.3.4 窗口启发式规则

```
应用: 腾讯会议
条件: 可见窗口数 >= 2
      AND 至少一个窗口 width > 600 AND height > 400
→ 判定为会议中

应用: Zoom
条件: 可见窗口数 >= 2
      AND 至少一个窗口有标题 AND width > 300 AND height > 200
→ 判定为会议中

应用: 微信
条件: 存在浮动窗口 (window.level == 0)
      AND 50 < width < 300
      AND 50 < height < 250
→ 判定为语音通话中
```

---

### 2.4 SettingsStore — 配置持久化

```
┌──────────────────────────────────────────┐
│             SettingsStore                │
│          (ObservableObject)              │
├──────────────────────────────────────────┤
│ @Published var usageLimitSeconds: Int    │  ← UserDefaults 双向同步
│ @Published var breakDurationSeconds: Int │
│ @Published var launchAtLogin: Bool       │
│ @Published var muteOnBreak: Bool         │
│ @Published var sensitiveAppBundleIds     │
│                   : [String]             │
├──────────────────────────────────────────┤
│ init(): 从 UserDefaults 读取默认值        │
│ didSet 各属性: 自动写入 UserDefaults      │
└──────────────────────────────────────────┘
```

#### 2.4.1 读写策略

- **初始化时**: 从 UserDefaults 读取, 缺省则使用默认值
- **属性变更时**: `didSet` 中自动 `UserDefaults.standard.set(value, forKey:)`
- **不写磁盘**: 纯内存 + UserDefaults, 无自定义文件存储

#### 2.4.2 默认值设计

| 参数 | 默认值 | 设计理由 |
|------|--------|----------|
| usageLimitSeconds = 3600 | 60 分钟 | 符合眼科医生建议的 "每1小时休息" 原则 |
| breakDurationSeconds = 300 | 5 分钟 | 足够起身活动但不会太长打断心流 |
| muteOnBreak = false | 关闭 | 不主动改变用户音量设置, 需用户显式开启 |
| launchAtLogin = false | 关闭 | 让用户决定是否常驻 |
| sensitiveAppBundleIds = 7 个预置 | — | 覆盖中国用户最常用的会议/通讯应用 |

---

### 2.5 QuoteStore — 名言库

```
┌──────────────────────────────────────────┐
│              QuoteStore                  │
├──────────────────────────────────────────┤
│ private var quotes: [String]             │
├──────────────────────────────────────────┤
│ init(): 加载 catbreak.txt 并解析          │
│ func random() → String                  │
│ private func parse(_ text: String)       │
└──────────────────────────────────────────┘
```

#### 2.5.1 解析算法

```
catbreak.txt (5206 行):
  逐行读取:
    ├─ 跳过空行
    ├─ 跳过标题行: 包含 "名言名句警句摘抄大全" 等
    ├─ 跳过 URL 行: 包含 "http" 或 "www"
    └─ 匹配: /^\d+[、，。.]\s*(.+)$/
        提取捕获组作为名言文本
```

解析为纯字符串数组, `random()` 返回 `quotes.randomElement()`。

---

## 3. 窗口管理设计

### 3.1 BreakOverlayWindow

```
┌──────────────────────────────────────────────┐
│         BreakOverlayWindow : NSWindow         │
├──────────────────────────────────────────────┤
│ init(screen: NSScreen)                        │
│   - contentRect: screen.frame                 │
│   - styleMask: .borderless                    │
│   - backing: .buffered                        │
│   - defer: false (立即显示)                    │
│   - isOpaque: false                           │
│   - backgroundColor: .clear                   │
│   - level: CGShieldingWindowLevel()            │
│   - collectionBehavior:                       │
│       .canJoinAllSpaces                       │
│       .fullScreenAuxiliary                    │
│       .stationary                             │
│   - ignoresMouseEvents: true                  │
│   - hasShadow: false                          │
│   - contentView: NSHostingView(CatOverlayView) │
└──────────────────────────────────────────────┘
```

### 3.2 多显示器管理

```
AppDelegate.showBreakOverlay():
  overlays = []
  for screen in NSScreen.screens:
    window = BreakOverlayWindow(screen: screen)
    window.orderFrontRegardless()
    overlays.append(window)

AppDelegate.dismissBreakOverlay():
  for window in overlays:
    window.close()
  overlays = []
```

### 3.3 窗口层级对比

```
CGShieldingWindowLevel() — 屏幕保护层 (CatBreak 覆盖)
    ↑ 最顶层
NSStatusWindowLevel       — 菜单栏
NSFloatingWindowLevel    — 浮动面板
NSNormalWindowLevel      — 普通窗口
    ↓ 最底层
```

### 3.4 覆盖刷新策略

```
Timer (1s):
  for window in overlays:
    window.contentView = NSHostingView(
      CatOverlayView(timerManager: timerManager)
    )
```

每秒重新创建 `NSHostingView` 以刷新倒计时显示。这是为了复用已有的 SwiftUI View, 避免引入额外的刷新机制。

---

## 4. 组件通信设计

### 4.1 数据流图

```
                    ┌─────────────┐
                    │ UserDefaults │
                    └──────┬──────┘
                           │ read/write
                    ┌──────▼──────┐
                    │SettingsStore│
                    └──────┬──────┘
                           │ @ObservedObject
              ┌────────────┼────────────┐
              │            │            │
     ┌────────▼───┐  ┌────▼─────┐  ┌───▼──────────┐
     │TimerManager│  │AppDelegate│  │SensitiveApp- │
     │            │  │           │  │  Detector    │
     └──┬────┬────┘  └──────────┘  └──────────────┘
        │    │
        │    │ @EnvironmentObject / @ObservedObject
        │    │
   ┌────▼┐ ┌─▼──────────┐
   │Con- │ │CatOverlay- │
   │tent │ │   View     │
   │View │ │            │
   └─────┘ └────────────┘
```

### 4.2 通知机制

本应用**不使用** NotificationCenter。所有跨组件通信通过以下方式:

| 方向 | 方式 |
|------|------|
| SettingsStore → 所有消费者 | `@Published` + `@ObservedObject` |
| TimerManager → ContentView | `@Published` + `@ObservedObject` |
| TimerManager → CatOverlayView | `@Published` + `@ObservedObject` |
| AppDelegate → TimerManager | 直接持有引用, 调用方法 |
| ActiveAppMonitor → TimerManager | 直接持有引用, 调用 `tick()` |
| SensitiveAppDetector → TimerManager | 直接持有引用, 调用推迟方法 |
| UserDefaults → SettingsStore | 初始化读取 + `didSet` 写入 |

选择 Combine `@Published` 而不使用 NotificationCenter 的原因:
- 编译时类型安全
- 与 SwiftUI 视图自动更新绑定
- 无需管理通知名称常量和显式 removeObserver

---

## 5. UI 组件树

### 5.1 完整组件层级

```
AppDelegate
├── NSStatusItem (菜单栏图标)
│   ├── NSMenu (右键菜单)
│   │   ├── "打开设置"
│   │   └── "退出"
│   └── NSPopover (左键弹出, transient, 320×600)
│       └── NSHostingView
│           └── ContentView
│               ├── TimerDisplayView
│               │   ├── Text (MM:SS 计时)
│               │   ├── ProgressView (进度条)
│               │   └── HStack (状态圆点 + 标签)
│               ├── TimeSlider (使用时长上限)
│               ├── TimeSlider (休息时长)
│               ├── Toggle (休息时静音)
│               ├── Toggle (开机自启)
│               ├── SensitiveAppsSection
│               │   ├── DisclosureGroup
│               │   │   ├── ForEach (敏感应用列表)
│               │   │   │   └── HStack (图标 + 名称 + 删除按钮)
│               │   │   └── Button ("选择应用") →
│               │   │       └── Sheet: AppPickerView
│               │   │           ├── TextField (搜索)
│               │   │           ├── List (应用列表)
│               │   │           │   └── AppRow (图标 + 名称 + Bundle ID + 勾选框)
│               │   │           ├── DisclosureGroup (手动输入)
│               │   │           │   └── TextField (Bundle ID)
│               │   │           └── Button ("完成")
│               │   └── Text (警告文字, 橙/灰色)
│               └── Button ("退出")
│
└── BreakOverlayWindow[] (多显示器)
    └── NSHostingView
        └── CatOverlayView
            ├── Image (catbreak.jpg 背景)
            ├── Color.black.opacity(0.45) (遮罩)
            ├── Circle (装饰光晕 × 2)
            ├── Image(systemName: "cat.fill") (55pt)
            ├── Text (名言警句, 衬线斜体)
            ├── Capsule (breakCount > 1 ? "第N次休息" : nil)
            ├── Text ("该休息啦！")
            ├── RoundedRectangle
            │   └── Text (倒计时, 72pt 等宽)
            └── Text ("伸展一下 · 看看远处 · 深呼吸")
```

### 5.2 ContentView 布局约束

```
┌────────────────────── 320pt ──────────────────────┐
│                                                    │
│  padding: 16pt                                     │
│                                                    │
│  VStack(spacing: 12)                               │
│  ├── TimerDisplay (自适应高度)                      │
│  ├── Divider                                       │
│  ├── TimeSlider                                    │
│  ├── TimeSlider                                    │
│  ├── HStack: Toggle + Toggle                       │
│  ├── Divider                                       │
│  ├── SensitiveAppsSection                          │
│  │   └── DisclosureGroup (可折叠)                   │
│  └── Button ("退出")                                │
│                                                    │
└────────────────────────────────────────────────────┘
```

### 5.3 CatOverlayView 布局约束

```
全屏 (各显示器 screen.frame)

ZStack:
  ├── Image (背景, aspectRatio: .fill)
  ├── LinearGradient (兜底: 无图片时使用)
  ├── Color.black.opacity(0.45) (遮罩)
  ├── Circle (白色光晕, 150pt, blur 60, offset)
  ├── Circle (绿色光晕, 100pt, blur 40, offset)
  ├── Image(systemName: "cat.fill") (55pt, shadow)
  ├── Text (名言, serif italic, 18pt)
  ├── Capsule("第N次休息") (条件显示, 12pt)
  ├── Text("该休息啦！") (title, 28pt bold)
  ├── RoundedRectangle (倒计时卡片, cornerRadius: 16)
  │   └── Text(countdown) (monospaced, 72pt)
  │       └── 最后5秒: .foregroundColor(.yellow)
  │                     .background(.red)
  │                     .scaleEffect(1.05)
  │                     .animation(pulse)
  └── Text("伸展一下 · 看看远处 · 深呼吸") (14pt, gray)

计时器刷新:
  TimelineView(.periodic(from: .now, by: 1)) {
    基于 timerManager.breakRemaining 渲染
  }
```

---

## 6. 异步与线程设计

### 6.1 线程模型

```
主线程 (Main Queue):
  ├── UI 更新 (所有 @Published 变更)
  ├── TimerManager.tick() (由 Timer 驱动, 但 timer 在 main run loop)
  ├── ActiveAppMonitor 事件回调 (NSEvent global monitor 在 main thread)
  └── 窗口创建/销毁 (AppKit 要求主线程)

后台线程 (Global Utility Queue):
  ├── 音量 AppleScript 执行 (避免阻塞 UI)
  └── 敏感应用检测 (避免每次检测阻塞 main run loop)

后台线程 (Global User Initiated Queue):
  └── 应用扫描 (扫描 /Applications 等目录)
```

### 6.2 关键异步操作

```swift
// 音量控制 - 避免 AppleScript 阻塞 UI
DispatchQueue.global(qos: .utility).async {
    let script = "set volume output muted true"
    NSAppleScript(source: script)?.executeAndReturnError(nil)
}

// 敏感应用检测 - 异步窗口遍历
func checkAsync() {
    DispatchQueue.global(qos: .utility).async {
        let result = self.performDetection()
        DispatchQueue.main.async {
            self.isActive = result
        }
    }
}

// 应用扫描
DispatchQueue.global(qos: .userInitiated).async {
    let apps = scanApplications()
    DispatchQueue.main.async {
        self.installedApps = apps
    }
}
```

---

## 7. 生命周期设计

### 7.1 应用启动

```
main.swift:
  NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)

AppDelegate.applicationDidFinishLaunching(_):
  1. SettingsStore.init()         // 加载 UserDefaults
  2. TimerManager.init(settings)  // 初始化计时器 (state: .idle)
  3. QuoteStore.init()            // 加载名言库
  4. ActiveAppMonitor.init()      // 开始监听全局事件
  5. setupStatusBarItem()         // 创建菜单栏图标
  6. if settings.launchAtLogin:
       SMAppService.mainApp.register()  // 注册登录项
```

### 7.2 应用退出

```
NSApplication.terminate(_):
  ├── ActiveAppMonitor.stopMonitoring()
  │   └── NSEvent.removeMonitor(eventMonitor)
  ├── dismissBreakOverlay() (如有进行中的休息)
  │   └── for window in overlays: window.close()
  └── SettingsStore 自动保存 (didSet 已在每次变更时写入)
```

### 7.3 进入/退出全屏

- `fullScreenAuxiliary` 确保休息覆盖在所有 Space (包括全屏应用 Space) 中都可见
- 进入其他应用会触发 `NSWorkspace.activeApplication` 变化, ActiveAppMonitor 仅跟踪前台应用

---

## 8. 资源管理

### 8.1 资源清单

```
Resources/
├── Info.plist                       # 应用元数据
├── CatBreak.entitlements            # 权限声明 (Sandbox OFF)
├── AppIcon.icns                     # 应用图标 (icns 格式)
├── Assets.xcassets/
│   ├── AppIcon.appiconset/          # 多分辨率图标的 PNG 资源
│   ├── catbreak.imageset/
│   │   └── catbreak.jpg             # 休息覆盖背景图
│   └── Cat.imageset/               # 空占位 (未使用)
├── catbreak.txt                     # 名言库 (5206 行)
└── 安装说明.txt                      # 用户安装指南
```

### 8.2 资源加载策略

| 资源 | 加载方式 | 兜底 |
|------|----------|------|
| catbreak.jpg | `Bundle.main.image(forResource:)` | 深色渐变 (LinearGradient) |
| catbreak.txt | `Bundle.main.url(forResource:)` + String(contentsOf:) | 硬编码兜底名言 |
| AppIcon | `NSImage(named: "AppIcon")` | 无 |

---

## 9. 错误处理设计

### 9.1 优雅降级策略

| 场景 | 降级行为 |
|------|----------|
| catbreak.jpg 加载失败 | 使用硬编码的深色渐变作为背景 |
| catbreak.txt 加载失败 | 使用硬编码兜底名言 |
| 音量 AppleScript 执行失败 | 静默忽略, 不阻塞休息流程 |
| 应用扫描权限不足 | 跳过该目录, 继续扫描其他目录 |
| 麦克风检测失败 | 返回 false, 不判定为通话中 |
| SMAppService 注册失败 | 弹窗提示用户 "设置失败" |
| 用户手动添加无效 Bundle ID | 仅存储字符串, 运行时检测不到则忽略 |

### 9.2 不处理的情况 (设计选择)

- 全局事件监控权限被撤销: 不检测, 依赖首次启动时的系统授权提示
- UserDefaults 写入失败: 不处理 (极端情况, 磁盘满等)
- 多显示器热插拔: 当前休息中的覆盖不会响应屏幕变化 (设计简化)

---

## 10. 关键设计决策

### 10.1 为什么不用 App Sandbox?

**问题**: App Sandbox 会阻止 `NSWorkspace.runningApplications` 获取其他应用的窗口标题。

**决策**: 关闭 Sandbox, 启用 Hardened Runtime。

**代价**: 无法通过 Mac App Store 分发, 无法使用 iCloud/App Groups 等沙盒特性。

### 10.2 为什么全屏覆盖而不是系统通知?

**问题**: 系统通知可以被忽略、关闭或静音。

**决策**: 使用 `CGShieldingWindowLevel()` 最高层级的全屏窗口, 确保用户无法跳过。

**代价**: 侵入性强, 但这是产品的核心价值——强制执行休息。

### 10.3 为什么每秒重建 NSHostingView?

**问题**: SwiftUI View 需要刷新倒计时数字。

**决策**: 每秒创建新的 `NSHostingView(CatOverlayView(timerManager:))` 替换旧的 contentView。

**替代方案**: 使用 Combine 订阅 `timerManager.$breakRemaining` 自动更新。当前实现更简单但略重, 不过考虑到 UI 元素少、每秒仅一次刷新, 性能影响可忽略。

### 10.4 为什么不用 SwiftUI 的 WindowGroup?

**问题**: SwiftUI App 生命周期更适合单窗口应用。

**决策**: 使用 AppKit AppDelegate 生命周期, 手动管理 NSStatusItem + NSPopover + BreakOverlayWindow。

**原因**:
- 需要精细控制窗口层级 (CGShieldingWindowLevel)
- 需要多显示器独立窗口管理
- 菜单栏应用需要 NSStatusItem (SwiftUI 的 MenuBarExtra 在 macOS 13 才引入, 且功能受限)

### 10.5 为什么选择 3 分钟空闲 / 10 分钟重置?

**设计考量**:
- 3 分钟: 足够覆盖去洗手间、倒水、短暂交谈的场景, 不会误判为放松
- 10 分钟: 超过此时间视为一次完整的休息/离开, 之前的使用时长不算连续用眼
- 这两个阈值没有严格科学依据, 是非正式的产品判断

### 10.6 为什么是敏感应用列表而非全局规则?

**决策**: 让用户自定义哪些应用触发推迟。

**原因**: 不同用户的工作场景不同 (有人用 Chrome 开会, 有人用 Chrome 摸鱼), 全局规则无法覆盖所有情况。预设腾讯会议/Zoom/Teams 覆盖大部分中国办公场景。

---

## 11. 版本演进记录

| 版本 | 变更 |
|------|------|
| 1.0.0 (Gen 1) | 基础计时 + 全屏覆盖 + 英文 UI + 单显示器 |
| 1.5.0 (Gen 2) | 中文 UI + 敏感应用检测 + 名言库 + 静音 + 开机自启 |
| 1.6.0 | 新增 QuoteStore + SensitiveAppDetector 完善 + 多显示器支持 + 紧急倒计时动画 + 休息次数统计 |
