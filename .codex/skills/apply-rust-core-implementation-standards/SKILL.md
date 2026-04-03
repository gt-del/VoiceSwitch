---
name: apply-rust-core-implementation-standards
description: Use when VoiceSwitch changes Rust core code, state machine implementation, behavior classification, rule engine, config validation, or diagnostic models and Rust implementation standards must be applied.
---

# Apply Rust Core Implementation Standards

在修改 VoiceSwitch 的 Rust core 实现时，用这个 skill 把项目内 vendored 的 `rust-best-practices` 真正落到本仓库里。

## 何时触发

- 修改 Rust core 代码
- 修改状态机实现
- 修改行为分类器
- 修改规则引擎
- 修改配置校验
- 修改诊断模型

## 输入工件

- 当前 Rust 改动
- 相关 proposal / FFI 审查 / observability 审查结果
- `rust-best-practices` 的约束

## 固定步骤

1. 检查错误处理是否明确。
2. 检查是否存在无理由 `unwrap()` / `expect()`。
3. 检查是否存在无必要 `clone()`。
4. 检查类型是否能表达业务约束。
5. 检查 tracing / test / replayability 是否保持。
6. 检查本次改动是否误把平台细节带入 core。

## 输出工件

- 使用 `templates/rust-core-change-checklist.md`

## 验收标准

- 错误边界清楚
- 不变量有类型或显式校验支撑
- 无明显 borrow-checker 绕路写法
- 可观测性未退化
- 未越过 Rust core 边界
