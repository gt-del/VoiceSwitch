# VoiceSwitch

VoiceSwitch 是一个运行于 macOS 的桌面应用，主交互位于应用窗口，菜单栏只保留状态入口和快速控制。当前产品语义如下：

- 默认保持用户配置的 `Primary IME`
- 轻按一次左 `Control` 切换到 `Voice IME`
- 再按一次左 `Control` 切回 `Primary IME`
- 用户手动切换输入法后进入 `cooldown`

当前版本为 `v0.1.0`，支持 macOS 15+，并已用 Rust FFI 替换早期的 CLI bridge。

## 当前能力

- 主窗口 Dashboard / Settings / Logs
- 菜单栏状态入口、打开主窗口、快速启停、重试、退出
- 系统输入法列表读取与 Primary / Voice IME 配置保存
- Rust core 最小状态机
- Swift -> Rust FFI bridge
- Keyboard Event Tap 监听
- Accessibility 权限降级与重试接管
- 输入法真实切换
- 用户手动切换检测与真实 cooldown
- Launch at Login 接入 `SMAppService.mainApp`

## 产品结构

- 启动应用后直接显示主窗口，可在窗口内完成主要配置
- 关闭主窗口后应用不会退出，会继续保留 Dock 与菜单栏入口常驻运行
- 主窗口关闭后，可通过点击 Dock 图标或菜单栏 `Open VoiceSwitch` 重新打开
- `Dashboard` 默认只展示当前状态、输入法组合、权限/监听状态、最近动作
- `Dashboard` 只在当前不可用时展示阻塞原因与下一步建议；正常运行时保持简洁
- 诊断字段收进 `诊断信息` 折叠区，避免主视图被路径和底层布尔值占满
- `Settings` 负责 Input Sources、Behavior、Permissions & System 配置，不再重复展示 Dashboard 已经清楚表达的状态说明
- `Logs` 默认显示用户日志，可切换到诊断日志继续排障
- `Permissions & System` 会显示实时权限检测值与运行对象信息：
  - `AXIsProcessTrusted`
  - `CGPreflightListenEventAccess`
  - 当前运行路径
  - 当前 Bundle ID / Bundle 路径
- 主窗口和设置页都会区分以下不可用原因：
  - `AccessibilityDenied`
  - `InputMonitoringDenied`
  - `RuntimeIdentityMismatch`
  - `KeyboardMonitoringStopped`
- 菜单栏只保留：
  - `Open VoiceSwitch`
  - `Status`
  - `Enable / Disable`
  - `Retry Monitoring`
  - `Quit`

## 状态机

当前实现只保留 3 个状态：

- `idlePrimary`
- `voiceHeld`
- `cooldown`

当前实现只保留 4 个动作：

- `switchToPrimary`
- `switchToVoice`
- `enterCooldown`
- `noOp`

当前关键事件：

- `controlPressed`
- `controlReleased`
- `typingDetected`
- `typingKeyLetters`
- `typingKeyNumbers`
- `typingKeySpace`
- `typingKeyDelete`
- `typingKeyReturnKey`
- `manualSwitchDetected`
- `cooldownExpired`

## 自动切换行为

核心闭环如下：

1. 第一次轻按左 `Control` 后触发 `idlePrimary + controlPressed -> voiceHeld + switchToVoice`
2. 第二次轻按左 `Control` 后触发 `voiceHeld + controlReleased -> idlePrimary + switchToPrimary`
3. `* + manualSwitchDetected -> cooldown + enterCooldown`
4. `cooldown + cooldownExpired -> idlePrimary`

补充规则：

- `voiceActivationDelay`、`releaseReturnDelay`、`cooldownDuration` 由 Rust core 配置驱动
- `voiceActivationDelay` 和 `releaseReturnDelay` 只用于轻微防抖，不改变主状态机语义
- Swift 负责执行 Rust 返回的动作，并在需要时调度轻微延迟 timer
- `typingKeyWhitelist` 定义在 Rust core，Swift 只上传稳定键类别
- typing 事件保留兼容，但不再决定主路径回切
- cooldown 期间自动切换会被抑制，并写入结构化日志

## 设置项

主窗口设置页暴露以下参数，改动后会自动保存并持久化；新事件会立即使用新配置：

- `Primary IME`
- `Voice IME`
- `Enable VoiceSwitch`
- `Launch at Login`
- `Voice Activation Delay`
- `Release Return Delay`
- `Cooldown Duration`

当前参数默认值与合法范围：

| 参数 | 默认值 | 范围 |
| --- | --- | --- |
| `voiceActivationDelay` | `0.00s` | `0.0...0.3` |
| `releaseReturnDelay` | `0.00s` | `0.0...0.3` |
| `cooldownDuration` | `5.0s` | `0.5...30.0` |

`typingKeyWhitelist` 当前仍保留在 Rust 内部配置中，但不在设置页暴露，也不参与主切换逻辑。

## 日志字段

当前主日志字段已固定为：

- `trigger`
- `reason`
- `source_state`
- `target_state`
- `action`
- `current_input_source`
- `target_input_source`
- `cooldown_status`

按场景追加：

- `timer_kind`
- `timer_delay_seconds`
- `raw_event`
- `switch_result`
- `requested`
- `actual`
- `enabled`

其中业务语义字段由 Rust diagnostic 产出，Swift 执行层只补输入法与 cooldown 上下文。

## 架构摘要

- `RustCore/`
  - 状态机、配置校验、诊断、FFI 导出
- `Sources/VoiceSwitchKit/`
  - 权限、监听、输入法切换、启动项、AppModel、Swift bridge
- `Sources/VoiceSwitchFFI/`
  - C shim、公开头文件、module map
- `Sources/VoiceSwitchApp/`
  - 主窗口、菜单栏入口、设置页、日志页

## 构建与测试

构建：

```bash
swift build
```

Rust 测试：

```bash
cargo test --manifest-path RustCore/Cargo.toml
```

Swift 测试：

```bash
swift test
```

推荐运行方式：

1. 用 Xcode 直接运行 `VoiceSwitchApp`
2. 或构建固定 `.app` 产物后启动

开发态 `.app` 运行脚本：

```bash
./scripts/run-dev-app.sh
```

这会在仓库根目录生成并打开 `.dev-app/VoiceSwitch.app`，同时写入：

- 普通 Dock App metadata
- `AppIcon.icns`
- 主窗口 + 菜单栏并存的运行形态

不建议把 `swift run VoiceSwitchApp` 当成长期使用方式。正式使用请优先从固定 `.app` 产物启动，这样 Dock、权限授权对象、Launch at Login 和事件监听更稳定。

## 已知限制

当前版本还不支持：

- 按 App 切换
- 黑名单
- 浏览器域名规则
- 复杂 typing score 模型
- 自定义 trigger key
- 设置页直接配置 `typingKeyWhitelist`
- 自动化的 1~2 小时 soak test

此外：

- Event Tap 和输入法切换都依赖系统权限与系统输入源状态
- 权限授权对象必须与当前运行目标一致；如果你换了运行路径、Bundle 或重新生成了新 `.app`，macOS 可能会把它当成新的授权对象
- 主窗口会区分四类主要阻塞原因：
  - 系统尚未授予辅助功能权限
  - 系统尚未授予输入监听权限
  - 当前运行目标未命中已授权条目
  - 权限和配置正常，但监听服务未运行
- `Launch at Login` 可能返回 `requiresApproval`，需要用户在系统登录项中确认
- 主窗口负责主要错误提示；日志页用于排查，不作为主配置入口
- 当前日志分为用户日志和诊断日志两层，界面默认展示用户日志；完整诊断仍保留在同一页面中

## 运行身份 FAQ

### 为什么明明授权了，应用里还是显示不可用？

macOS 记住的是“被授权的运行对象”，不是单纯记住“VoiceSwitch 这个名字”。如果你授权的是一个路径或 Bundle，但当前运行的是另一个目标，应用里就会继续显示不可用。

常见情况：

- 你之前授权的是 Xcode 直接运行出来的进程
- 现在运行的是固定 `.app`
- 或者之前授权的是旧路径下的 `.app`，现在重新生成了一个新路径的 `.app`

这时主窗口通常会显示 `RuntimeIdentityMismatch`，意思不是系统完全没授权，而是“当前进程未命中已授权条目”。

### 为什么 `swift run`、Xcode、固定 `.app` 看起来不一样？

因为这三种运行方式的可执行路径、Bundle 形态和系统识别身份都可能不同：

- `swift run VoiceSwitchApp`
  - 常见于 `.build` 下的可执行文件
  - 不适合长期使用
- Xcode 运行
  - 适合开发调试
  - 运行目标可能随着构建目录变化
- 固定 `.app`
  - 最适合长期使用
  - Dock、权限、Launch at Login、事件监听都更稳定

### 为什么路径或签名变化后要重新授权？

因为系统判断的是“这个具体运行目标有没有被授权”，不是“你以前是否给过某个同名应用权限”。当路径、Bundle 或签名变化后，系统可能把它当成新的对象，需要重新绑定权限。

### 为什么要分别打开“辅助功能”和“输入监听”？

因为它们是两个独立的系统入口，授权状态也彼此独立：

- “辅助功能”决定 VoiceSwitch 是否可以接管和监听需要的辅助能力
- “输入监听”决定 VoiceSwitch 是否可以读取全局键盘事件

设置页里会分别提供“打开辅助功能”和“打开输入监听”两个按钮；如果只授权了其中一个，应用仍然会显示不可用。

### 如何确认当前运行对象就是已授权对象？

打开主窗口，在 `Dashboard` 或 `Settings > Permissions & System` 查看：

- 当前运行路径
- 当前 Bundle ID
- 当前 Bundle 路径
- `AXIsProcessTrusted`
- `CGPreflightListenEventAccess`

默认界面会对路径做遮盖，避免长期暴露本机目录；如果需要完整排查，可以用日志页的“导出日志”拿到完整值。

### 如何重新绑定正确的授权对象？

1. 关闭当前 VoiceSwitch
2. 打开系统设置中的“辅助功能”和“输入监听”
3. 删除旧的 VoiceSwitch 条目
4. 用你准备长期使用的方式重新启动 VoiceSwitch
   - 推荐固定 `.app`
   - 不建议长期使用 `swift run VoiceSwitchApp`
5. 在系统设置里重新勾选当前这个运行目标
6. 回到 VoiceSwitch，等待自动恢复；只有自动恢复失败时，再点 `重试监听`

## 文档

- 项目约束：`AGENTS.md`
- 回归矩阵：`docs/testing/v0.1.0-regression-matrix.md`
- 权限回归清单：`docs/testing/permission-regression-checklist.md`
- 发布说明：`docs/releases/v0.1.0.md`
