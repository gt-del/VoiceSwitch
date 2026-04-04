# VoiceSwitch

VoiceSwitch 是一个运行于 macOS 的桌面应用，主交互位于应用窗口，菜单栏只保留状态入口和快速控制。当前版本围绕一个最小可用闭环构建：

- 默认保持用户配置的 `Primary IME`
- 按住 `Option` 切换到 `Voice IME`
- 松开 `Option` 切回 `Primary IME`
- 用户手动切换输入法后进入 `cooldown`

当前实现目标是 `v0.1.0`，支持 macOS 15+，并已用 Rust FFI 替换早期的 CLI bridge。

## 当前已支持能力

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

## 当前产品结构

- 启动应用后直接显示主窗口，可在窗口内完成主要配置
- 关闭主窗口后应用不会退出，会继续保留 Dock 与菜单栏入口常驻运行
- `Dashboard` 展示当前状态、权限、监听状态、当前 IME 和最近动作
- `Settings` 负责 Input Sources、Behavior、Permissions & System 配置
- `Logs` 展示最近日志、原始事件与调试按钮
- 菜单栏只保留：
  - `Open VoiceSwitch`
  - `Status`
  - `Enable / Disable`
  - `Retry Monitoring`
  - `Quit`

## 当前状态机

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

- `optionPressed`
- `optionReleased`
- `typingDetected`
- `typingKeyLetters`
- `typingKeyNumbers`
- `typingKeySpace`
- `typingKeyDelete`
- `typingKeyReturnKey`
- `manualSwitchDetected`
- `cooldownExpired`

## 当前自动切换行为

核心闭环如下：

1. `idlePrimary + optionPressed -> voiceHeld + switchToVoice`
2. `voiceHeld + optionReleased -> idlePrimary + switchToPrimary`
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

当前主窗口设置页暴露以下参数，保存后会持久化；新事件会立即使用新配置：

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

运行：

```bash
swift run VoiceSwitchApp
```

开发态 `.app` 运行：

```bash
./scripts/run-dev-app.sh
```

这会在仓库根目录生成并打开 `.dev-app/VoiceSwitch.app`，同时写入：

- 普通 Dock App metadata
- `AppIcon.icns`
- 主窗口 + 菜单栏并存的运行形态

如果要验证更接近成品的软件形态，优先使用 `.app` 启动，而不是只用 `swift run`。

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
- `Launch at Login` 可能返回 `requiresApproval`，需要用户在系统登录项中确认
- 主窗口负责主要错误提示；日志页用于排查，不再作为主配置入口
- 当前日志仍以结构化字符串形式展示，尚未落成持久化 schema

## 文档

- 项目约束：`AGENTS.md`
- 回归矩阵：`docs/testing/v0.1.0-regression-matrix.md`
- 发布说明：`docs/releases/v0.1.0.md`
