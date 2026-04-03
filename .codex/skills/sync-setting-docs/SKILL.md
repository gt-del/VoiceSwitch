---
name: sync-setting-docs
description: Use when VoiceSwitch adds or changes a setting, its default value, validation rule, meaning, or settings UI presentation and project documentation must stay in sync.
---

# Sync Setting Docs

新增或修改设置项后，同步长期文档与相关文案，避免实现和说明漂移。

## 何时触发

- 新增设置项
- 修改默认值
- 修改设置语义
- 修改设置页呈现
- 修改配置校验规则

## 输入工件

- 设置项定义或变更说明
- 默认值、validation rule、相关文案
- 相关 UI 或调试视图上下文

## 固定步骤

1. 明确该设置项的用途、默认值、取值约束和用户可见语义。
2. 检查 [README.md](/Users/didi/Code/github/VoiceSwitch/README.md) 是否需要同步。
3. 检查 [AGENTS.md](/Users/didi/Code/github/VoiceSwitch/AGENTS.md) 中是否存在与该设置项相关的长期约束。
4. 检查设置说明、调试文案、validation rule 说明是否一致。
5. 明确哪些内容属于 README，哪些属于 AGENTS，避免把 AGENTS 写成设置说明书。

## 输出工件

- 使用 [settings-sync-checklist.md](/Users/didi/Code/github/VoiceSwitch/.codex/skills/sync-setting-docs/templates/settings-sync-checklist.md)

## 验收标准

- 默认值、语义、validation rule 都有同步结论
- README 与调试文案是否更新有明确结论
- `AGENTS.md` 只更新长期约束，不写成设置说明书
