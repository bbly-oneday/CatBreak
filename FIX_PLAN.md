# CatBreak 代码修复计划

## 修复目标

基于代码审查报告，系统性修复以下问题：

### P0 - 紧急修复（必须完成）

1. **清理冗余代码目录**
   - 删除 `App/`、`Core/`、`UI/` 目录
   - 更新 `project.yml` 指向 `Sources/CatBreak/`
   - 确保 Xcode 项目正确编译

2. **修复内存泄漏风险**
   - TimerManager 添加 deinit 清理 breakTimer
   - ActiveAppMonitor 添加 deinit 清理 pollTimer 和 eventMonitor
   - BreakOverlayWindow 确保通知观察者正确移除

### P1 - 重要修复

3. **移除不必要的 UI Timer**
   - ContentView 中移除手动 Timer
   - 使用 Combine 的 onReceive 替代

4. **添加日志系统**
   - 引入 os.log
   - 在关键路径添加日志

### P2 - 架构改进

5. **拆分 AppDelegate 职责**
   - 创建 AudioController 处理音量控制
   - 创建 NotificationManager 处理通知

6. **添加错误处理**
   - CoreAudio 错误日志记录
   - 边界值验证

### P3 - 功能完善

7. **添加国际化支持**（可选）
8. **实现窗口标题检测**（可选）

---

## 修复策略

### 阶段一：代码清理（P0）
- 风险：高（可能影响编译）
- 策略：先备份，后删除，验证编译通过

### 阶段二：内存安全（P0）
- 风险：中（需要仔细测试生命周期）
- 策略：逐个类添加 deinit，确保正确清理

### 阶段三：性能优化（P1）
- 风险：低
- 策略：移除冗余代码，使用 Combine

### 阶段四：架构重构（P2）
- 风险：中
- 策略：逐步拆分，保持向后兼容

---

## 验证检查点

每个阶段完成后：
1. 编译通过
2. 应用能正常启动
3. 核心功能正常（计时、休息覆盖、设置保存）
4. 无内存泄漏警告

---

## 回滚方案

每个阶段创建独立 commit，出问题可回滚：
- commit 1: 清理冗余代码
- commit 2: 修复内存泄漏
- commit 3: 性能优化
- commit 4: 架构重构
