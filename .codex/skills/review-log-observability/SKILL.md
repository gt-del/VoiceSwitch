---
name: review-log-observability
description: Use when VoiceSwitch changes logging schema, automatic switch explanation fields, diagnostic evidence, or degrade and recover observability and log stability must be reviewed.
---

# Review Log Observability

当日志字段、解释字段、诊断文案或恢复证据变化时，先做可观测性审查。

## 何时触发

- 状态、事件、错误路径、恢复路径变化
- 日志字段 schema 变化
- 自动切换解释字段变化

其中明确包括：

- 字段新增
- 字段删除
- 字段改名
- 字段语义变化
- `trigger` / `reason` / `source_state` / `target_state` / `manual_override` / `cooldown_boundary` 任一语义变化

## 输入工件

- 当前日志字段和诊断字段
- 拟议变更说明
- 相关状态机或平台变更上下文

## 固定步骤

1. 列出本次变化涉及的字段和解释语义。
2. 检查关键解释字段是否仍完整覆盖自动切换行为。
3. 检查 degrade path / recover path 是否仍有足够证据。
4. 检查字段 schema 稳定性，避免改名或语义漂移破坏已有消费方。
5. 明确 QA、调试视图、回放工具是否需要同步。

## 输出工件

- 使用 [observability-review-checklist.md](/Users/didi/Code/github/VoiceSwitch/.codex/skills/review-log-observability/templates/observability-review-checklist.md)

## 验收标准

- 关键解释字段覆盖完整
- degrade / recover 证据覆盖明确
- schema 稳定性检查有明确结论
- 明确列出受影响的 QA 或调试消费方
