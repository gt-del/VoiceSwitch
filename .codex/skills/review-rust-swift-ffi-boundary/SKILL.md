---
name: review-rust-swift-ffi-boundary
description: Use when VoiceSwitch changes Rust-Swift FFI types, error codes, ownership, lifetime, thread affinity, or callback protocols and the boundary must be reviewed before merging.
---

# Review Rust Swift FFI Boundary

在修改 VoiceSwitch 的 Rust / Swift 边界时，先做一次结构化边界审查。

## 何时触发

- 新增或修改 FFI 类型
- 新增或修改错误码
- 修改所有权方向
- 修改生命周期边界
- 修改线程归属
- 修改回调协议或桥接协议

## 输入工件

- 相关 Rust / Swift 边界定义
- 需求说明或提案文档
- 相关日志字段与诊断字段

## 固定步骤

1. 审查类型是否稳定、可映射、可测试。
2. 审查所有权、生命周期、线程归属是否显式。
3. 审查错误码与枚举映射是否完整。
4. 审查诊断字段与日志字段是否跨边界对齐。
5. 审查该边界是否仍允许回放、测试和排障。

## 输出工件

- 使用 `templates/ffi-review-checklist.md`

## 验收标准

- 所有权、生命周期、线程归属都有明确结论
- 枚举映射和错误码稳定性有明确结论
- 日志 / 诊断字段跨边界变化被单独说明
