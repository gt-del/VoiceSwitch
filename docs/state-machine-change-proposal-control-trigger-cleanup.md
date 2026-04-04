# State Machine Change Proposal

## Background

当前产品语义已经切到左 `Control` toggle 进入 / 退出 `Voice IME`，但 Rust core、FFI、Swift 抽象事件、结构化日志和测试里仍保留 `optionPressed / optionReleased` 这套历史命名，导致实现语义、诊断字段和文档长期不一致。

## Current Behavior

- 用户第一次轻按左 `Control` 后进入 `voiceHeld`
- 用户第二次轻按左 `Control` 后回到 `idlePrimary`
- 平台层把这两个切换点分别映射到内部 `optionPressed / optionReleased`
- Rust core 诊断 `trigger` 为 `optionPressed / optionReleased`
- 诊断 `reason` 为 `pressed_option_switch_to_voice / released_option_switch_to_primary`

## Proposed Change

- 把抽象事件从 `optionPressed / optionReleased` 全量重命名为 `controlPressed / controlReleased`
- Rust `InputBehavior`、FFI `VSEvent`、Swift `InputBehavior`、`KeyboardEventSummary` 和桥接映射全部同步改名
- 结构化日志 `trigger` 改为 `controlPressed / controlReleased`
- 结构化日志 `reason` 改为 `pressed_control_switch_to_voice / released_control_switch_to_primary`
- toggle 交互、状态机状态、转移条件、cooldown 语义保持不变

## Affected Semantics

- States:
  - 无变化
- Events:
  - `optionPressed -> controlPressed`
  - `optionReleased -> controlReleased`
- Transitions:
  - 进入 `voiceHeld` 的语义不变，只改事件名
  - 回到 `idlePrimary` 的语义不变，只改事件名
- Scores / Thresholds:
  - 无变化
- Cooldown:
  - 无变化

## Affected Log Fields

- `trigger`:
  - `optionPressed -> controlPressed`
  - `optionReleased -> controlReleased`
- `reason`:
  - `pressed_option_switch_to_voice -> pressed_control_switch_to_voice`
  - `released_option_switch_to_primary -> released_control_switch_to_primary`
- 原始键盘描述继续保留真实物理键：
  - `controlDown`
  - `controlUp`

## Affected Settings

- 无新增设置
- 现有触发键说明文案需要与 `control` 命名保持一致

## Compatibility

- 旧配置结构不受影响
- Rust / Swift 边界枚举命名将发生一次性不兼容改名
- 现有历史日志中的旧 `trigger` / `reason` 保留为历史记录，不做回写迁移

## Observability Changes

- 结构化日志与用户真实触发键一致，减少排障混淆
- 文档、测试、诊断字段不再出现“实际是 Control，但内部还叫 Option”的双轨语义

## Test Impact

- Rust transition tests 需要改用 `ControlPressed / ControlReleased`
- FFI bridge tests 需要改用新的枚举和值
- Swift keyboard / app model tests 需要改用新的事件和诊断字段
- README 与设计文档中的示例字段需要同步

## FFI Review Required

- Yes
- Why:
  - `VSEvent` 枚举命名和 Swift / Rust 边界映射会发生变化，需要单独确认枚举稳定性、日志字段对齐和测试回放能力
