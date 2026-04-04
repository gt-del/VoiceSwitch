# Rust Core Change Checklist

## Change Summary

第六阶段 6A 为 Rust core 引入参数结构、结构化诊断字段和最小时间窗事件。

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
