# State Machine Change Proposal

## Background

第六阶段需要把 `optionPendingWindow`、`cooldownDuration`、`voiceExitDelay` 收敛为可配置参数，并把日志字段升级为稳定结构。当前最小实现仍使用：

- `optionReleased -> voiceActive`
- `voiceActive + typingDetected -> idlePrimary`

这与 `README.md` 中的时间窗设计不一致，也无法让 `optionPendingWindow` 与 `voiceExitDelay` 真实生效。

## Current Behavior

- `idlePrimary + optionPressed -> optionPending`
- `optionPending + optionReleased -> voiceActive`
- `optionPending + typingDetected -> idlePrimary`
- `voiceActive + typingDetected -> idlePrimary`
- `manualSwitchDetected -> cooldown`
- `cooldownExpired -> idlePrimary`

诊断字段只有 `message`，日志在 Swift 层以字符串拼接，字段稳定性不足。

## Proposed Change

- 在 Rust core 新增参数结构 `EngineConfiguration`
- 在状态机中新增事件：
  - `optionWindowExpired`
  - `voiceExitDelayElapsed`
- 将最小闭环调整为：
  - `idlePrimary + optionPressed -> optionPending`
  - `optionPending + optionWindowExpired -> voiceActive`
  - `optionPending + optionReleased -> idlePrimary`
  - `optionPending + typingDetected -> idlePrimary`
  - `voiceActive + typingDetected -> idlePrimary`
  - `voiceActive + optionReleased -> voiceActive`，由 Swift 调度 `voiceExitDelayElapsed`
  - `voiceActive + voiceExitDelayElapsed -> idlePrimary`
  - `manualSwitchDetected -> cooldown`
  - `cooldownExpired -> idlePrimary`
- 将 Rust `DiagnosticEntry` 升级为稳定字段：
  - `trigger`
  - `reason`
  - `sourceState`
  - `targetState`

## Affected Semantics

- States:
  - 保持 `idlePrimary`、`optionPending`、`voiceActive`、`cooldown`
- Events:
  - 新增 `optionWindowExpired`
  - 新增 `voiceExitDelayElapsed`
- Transitions:
  - `optionReleased` 不再直接激活 `voiceActive`
  - `optionWindowExpired` 成为进入 `voiceActive` 的触发条件
  - `voiceExitDelayElapsed` 成为 `voiceActive` 的延迟退出触发条件
- Scores / Thresholds:
  - 仍不引入复杂评分，仅参数化时间窗
- Cooldown:
  - 语义不变，但时间长度从 Swift 常量转为 Rust 定义配置

## Affected Log Fields

- `trigger`
- `reason`
- `source_state`
- `target_state`
- `action`
- `current_input_source`
- `target_input_source`
- `cooldown_status`

## Affected Settings

- `optionPendingWindow`
- `cooldownDuration`
- `voiceExitDelay`

## Compatibility

- Swift bridge 需要传入配置
- Rust CLI 入参需要增加配置
- 现有基于 `diagnostic.message` 的测试需要迁移到结构化字段

## Observability Changes

- 自动切换解释字段改为 Rust 产出的稳定字段
- Swift 仅补充输入法执行结果与 cooldown 状态

## Test Impact

- Rust transition tests 需要覆盖新增事件
- Swift settings store / app model / bridge tests 需要覆盖配置透传
- 后续 UI/launch-at-login/权限恢复测试需要补充

## FFI Review Required

- Yes / No
- Why:
  - No。当前仍沿用 CLI bridge，只是扩展 CLI 输入结构；正式 FFI 替换留到 6B。
