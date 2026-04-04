# Rust Core Change Checklist

## Change Summary

Rust core 主状态机改为 `idlePrimary -> voiceHeld -> idlePrimary` 的按键保持模型，并保留 `cooldown` 作为手动切换抑制状态。旧的 `optionPending` / `voiceActive` / `optionWindowExpired` / `voiceExitDelayElapsed` 主路径语义被移除。

## Error Handling

- [x] Library-like errors use explicit error types
- [x] No unjustified unwrap/expect
- [x] Failure paths are explicit

## Ownership And Types

- [x] No unnecessary clone to satisfy borrow checker
- [x] Types express important invariants
- [x] Public interfaces are explicit

## Observability And Tests

- [x] Logging/tracing impact is documented
- [x] Replayability impact is documented
- [x] Tests added or updated

## Boundary Check

- [x] No macOS platform semantics leaked into core
- [x] No UI semantics leaked into core
- [x] No FFI boundary change left unreviewed
