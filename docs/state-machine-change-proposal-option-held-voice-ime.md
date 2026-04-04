# State Machine Change Proposal

## Background

当前实现的主路径仍然依赖 `optionPendingWindow` 和 typing 事件：

- `idlePrimary + optionPressed -> optionPending`
- `optionPending + optionWindowExpired -> voiceActive + switchToVoice`
- `voiceActive + typingKey* -> idlePrimary + switchToPrimary`

这与本次产品目标不一致。新的目标是把 `Option` 变成显式 hold-to-talk 风格切换键：按下切到 `Voice IME`，松开立即回到 `Primary IME`，typing 只保留为兼容事件，不再决定主路径。

## Current Behavior

- 默认状态为 `idlePrimary`
- `optionPressed` 只进入 `optionPending`，不立即切输入法
- 只有 `optionWindowExpired` 才会切到 `voiceActive`
- `voiceActive` 主要通过 `typingDetected` / `typingKey*` 返回 `idlePrimary`
- `optionReleased` 在 `voiceActive` 上只启动 `voiceExitDelay`
- `manualSwitchDetected` 会进入 `cooldown`

## Proposed Change

- 删除状态 `optionPending`、`voiceActive`
- 主状态收敛为：
  - `idlePrimary`
  - `voiceHeld`
  - `cooldown`
- 主路径改为：
  - `idlePrimary + optionPressed -> voiceHeld + switchToVoice`
  - `voiceHeld + optionReleased -> idlePrimary + switchToPrimary`
- `manualSwitchDetected` 统一进入 `cooldown`
- `cooldownExpired` 返回 `idlePrimary`
- `typingDetected` / `typingKey*` 保留兼容，但不再驱动主切换语义
- `voiceActivationDelay`、`releaseReturnDelay` 只作为轻微防抖实现细节；允许为 `0`

## Affected Semantics

- States:
  - 删除 `optionPending`
  - 删除 `voiceActive`
  - 新增 `voiceHeld`
- Events:
  - 保留 `optionPressed`
  - 保留 `optionReleased`
  - 保留 `manualSwitchDetected`
  - 保留 `cooldownExpired`
  - 保留 `typingDetected` / `typingKey*` 仅用于兼容兜底
  - `optionWindowExpired`、`voiceExitDelayElapsed` 不再作为主路径语义
- Transitions:
  - 按下 `Option` 立即请求切到 `Voice IME`
  - 松开 `Option` 立即请求切回 `Primary IME`
  - `cooldown` 期间忽略自动切换事件
- Scores / Thresholds:
  - 不引入 score
  - 只保留毫秒级可选 delay 作为防抖
- Cooldown:
  - 语义保持不变
  - 自动切换在 `cooldown` 内保持抑制

## Affected Log Fields

- `trigger`
- `reason`
- `source_state`
- `target_state`
- `timer_kind`
- `timer_delay_seconds`

`reason` 将切换到新的固定语义：

- `pressed_option_switch_to_voice`
- `released_option_switch_to_primary`
- `entered_cooldown_after_manual_switch`
- `cooldown_expired`
- `ignored_event_in_current_state`

## Affected Settings

- 删除 `optionPendingWindow`
- 删除 `voiceExitDelay`
- 新增 `voiceActivationDelay`
- 新增 `releaseReturnDelay`
- 保留 `cooldownDuration`
- `typingKeyWhitelist` 继续保留在内部配置，不暴露设置页

## Compatibility

- Rust CLI JSON 配置字段需要改名
- Rust / C / Swift FFI 枚举需要同步改名
- `UserDefaults` 需要迁移旧 key：
  - `optionPendingWindow -> voiceActivationDelay`
  - `voiceExitDelay -> releaseReturnDelay`
- 旧测试里依赖 `optionPending` / `voiceActive` / `optionWindowExpired` / `voiceExitDelayElapsed` 的断言需要整体替换

## Observability Changes

- 自动切换解释字段继续由 Rust diagnostic 产出
- Swift 执行层继续补输入法执行结果与 cooldown 状态
- `cooldown` 的进入、重置、到期仍需保持可观测
- degrade / recover 日志不应受这次状态机重构影响

## Test Impact

- Rust transition tests 需要重写主路径
- Rust bridge / CLI 一致性测试需要同步新状态和新 timer kind
- Swift AppModel / settings store / keyboard mapping / input source switching 测试需要整体迁移
- README 行为描述需要同步

## FFI Review Required

- Yes / No
- Why:
  - Yes。本次会修改 Rust / Swift FFI 状态枚举、事件枚举、timer kind 和配置字段，属于明确的 boundary change。
