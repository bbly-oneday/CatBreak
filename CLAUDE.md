# CatBreak 项目指南

## 项目概述

CatBreak 是一款 macOS 菜单栏休息提醒工具，通过全屏覆盖强制用户定时休息，防止长时间持续用眼和久坐。

## 技术栈

- **语言**: Swift 5.9
- **UI 框架**: SwiftUI + AppKit
- **构建工具**: Xcode 15.0 + XcodeGen (project.yml)
- **最低系统**: macOS 13.0 (Ventura)

## 项目结构

```
CatBreak/
├── Sources/CatBreak/   # 源代码（唯一目录）
│   ├── AppDelegate.swift
│   ├── TimerManager.swift
│   ├── ContentView.swift
│   ├── ActiveAppMonitor.swift
│   ├── SensitiveAppDetector.swift
│   ├── SettingsStore.swift
│   ├── Logger.swift
│   └── ...
├── Resources/          # 资源文件
├── Tests/              # 测试
├── image/              # README 截图
├── docs/               # 文档
├── project.yml         # XcodeGen 配置
└── README.md
```

## 开发规范

### 代码风格
- 使用 `@Published` + `@ObservedObject` 进行响应式绑定
- 闭包中使用 `[weak self]` 避免循环引用
- 添加 `deinit` 清理 Timer 和监听器

### 日志系统
```swift
import os.log

Logger.timer.info("消息")
Logger.audio.error("错误")
```

## 构建命令

```bash
# 生成 Xcode 项目
xcodegen generate

# 编译
xcodebuild -project CatBreak.xcodeproj -scheme CatBreak build
```

## DMG 打包规则

### ⚠️ 重要：DMG 打包必须包含以下内容

**每次编译 DMG 时，必须打包以下文件：**

1. ✅ `CatBreak.app` - 应用程序
2. ✅ `docs/安装和使用.txt` - 安装使用说明
3. ✅ `Applications` 文件夹快捷方式 - 方便用户拖拽安装

**DMG 打包命令示例：**

```bash
# 1. 编译 Release 版本
xcodebuild -project CatBreak.xcodeproj -scheme CatBreak -configuration Release build

# 2. 创建 DMG 目录结构
mkdir -p staging_dmg
cp -R ~/Library/Developer/Xcode/DerivedData/CatBreak-*/Build/Products/Release/CatBreak.app staging_dmg/
cp docs/安装和使用.txt staging_dmg/
ln -sf /Applications staging_dmg/Applications

# 3. 创建 DMG
hdiutil create -volname "CatBreak" -srcfolder staging_dmg -ov -format UDZO CatBreak-vX.X.dmg

# 4. 清理临时文件
rm -rf staging_dmg
```

**DMG 目录结构：**
```
CatBreak.dmg
├── CatBreak.app          # 应用程序
├── 安装和使用.txt         # 安装说明
└── Applications -> /Applications  # 快捷方式
```

## 重要规则

### ⚠️ Git 提交规则

**修改完代码后，不要自动提交到 GitHub！**

正确流程：
1. 修改代码后，先本地测试验证
2. 使用 `git status` 检查改动
3. **等待用户确认后再提交和推送**

```bash
# 检查改动
git status

# 用户确认后才执行
git add -A
git commit -m "描述"
git push
```

### 已完成的修复

- ✅ P0: 清理冗余代码目录 (App/, Core/, UI/)
- ✅ P0: 修复内存泄漏 (TimerManager, ActiveAppMonitor)
- ✅ P1: 移除 ContentView 冗余 Timer
- ✅ P1: 添加日志系统 (Logger.swift)
- ✅ 清理临时文件 (staging/, staging_dmg/)

## 版本历史

- v2.0: 初始稳定版本
- v2.5: 全新 UI 设计，现代化界面风格
