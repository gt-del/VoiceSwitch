# FFI Boundary Review Checklist

## Boundary Summary

本次边界变化包括：

- `VSState` 删除 `OptionPending`、`VoiceActive`，新增/保留 `IdlePrimary`、`VoiceHeld`、`Cooldown`
- `VSEvent` 保留 `optionPressed` / `optionReleased` / `manualSwitchDetected` / `cooldownExpired`，typing 事件继续保留兼容
- `VSTimerKind` 改为 `VoiceActivationDelay`、`ReleaseReturnDelay`、`Cooldown`
- `VSConfiguration` 字段改为 `voice_activation_delay`、`release_return_delay`、`cooldown_duration`
- 诊断 `reason` 语义切换为新的固定集合

## Checklist

- [x] Ownership direction is explicit
- [x] Lifetime boundary is explicit
- [x] Thread affinity is explicit
- [x] Enum mapping is complete
- [x] Error code set is stable
- [x] Diagnostic fields are aligned
- [x] Replay strategy exists
- [x] Testability remains intact

## Risks

- 旧 Swift 枚举 raw mapping 若未同步，会导致桥接返回 unknown raw value。
- C 头文件若未同步，FFI bridge 会在编译期直接失配。
- CLI 与 FFI 若字段名不同步，会破坏现有“一致性测试”。

## Required Follow-ups

- Rust `ffi.rs`、C 头文件和 Swift `RustEngineBridge.swift` 必须同一批提交更新。
- 保留 `typingKey*` 兼容映射，但不要重新进入主流程判定。
- 用 CLI/FFI 一致性测试覆盖新状态和新 timer kind。
