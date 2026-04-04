# State Machine Change Proposal

## Background

本轮只做“左 Control 双击切换输入法”的最终收口，不扩功能，不改权限模型，不改窗口结构，不改自动保存，不改 Launch at Login，不改日志分层，不改 FFI 对外边界。

## Current Behavior

- Rust 主状态机已经以 `controlPressed` 作为 toggle 主路径。
- Swift AppModel 当前直接把 `KeyboardEventSummary.mappedBehavior` 转发给 engine bridge。
- FFI ABI 仍保留旧字段名 `voice_activation_delay` / `primary_return_delay`。
- 个别表层文案和兼容说明还没有完全把“第二次按下直接切回”说清楚。

## Proposed Change

- 固定最终语义为：
  - `idlePrimary + controlPressed -> voiceMode + switchToVoice`
  - `voiceMode + controlPressed -> idlePrimary + switchToPrimary`
  - `* + manualSwitchDetected -> cooldown + enterCooldown`
  - `cooldown + cooldownExpired -> idlePrimary + noOp`
- `controlReleased` 仅保留兼容，不驱动主切换。
- 旧 ABI 名称只留在 bridge / FFI 兼容层，Swift / Rust 内部继续使用 toggle 语义名称。

## Affected Semantics

- States:
  - 无新增状态，继续使用 `idlePrimary` / `voiceMode` / `cooldown`
- Events:
  - 主事件仍为 `controlPressed`
  - `controlReleased` 降为兼容事件
- Transitions:
  - 主切换完全由两次 `controlPressed` 驱动
- Scores / Thresholds:
  - 无变化
- Cooldown:
  - 无变化

## Affected Log Fields

- 无 schema 变化
- `trigger=controlReleased` 仍可能出现，但只代表兼容事件，不代表主切换

## Affected Settings

- `switchToVoiceDelay`
- `switchToPrimaryDelay`
- `cooldownDuration`
- 仅用户说明文案同步为 toggle 语义，默认值和校验范围不变

## Compatibility

- FFI C 接口、导出 enum/struct、ABI 保持不变
- 兼容保留 `controlReleased`
- 兼容保留 `voice_activation_delay` / `primary_return_delay`

## Observability Changes

- 无日志分层变化
- 无字段 schema 变化
- 仅 README / UI / 测试中的行为说明统一

## Test Impact

- 补充 Swift 回归测试，证明 AppModel 连续两次左 `Control` 都直接转发 `controlPressed`
- 保留 `controlReleased` 不驱动主切换的测试
- Rust / Swift 测试都继续覆盖 cooldown 与 typing no-op

## FFI Review Required

- No
- Why:
  - 本次不改 FFI 对外边界，只在 bridge / FFI 兼容层显式承接旧命名
