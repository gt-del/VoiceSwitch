# Rust Core Change Checklist

## Change Summary

本次 Rust 侧只做兼容层命名收口，明确旧 ABI 字段名只存在于 FFI 入口；核心状态机语义保持 control toggle，不引入新的平台依赖。

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
