---
name: generate-state-machine-change-proposal
description: Use when VoiceSwitch changes states, events, transitions, scoring rules, or cooldown semantics and a semantic change proposal must be written before implementation.
---

# Generate State Machine Change Proposal

在修改 VoiceSwitch 状态机语义之前，先产出一份结构化提案。

## 何时触发

- 新增、删除、重命名状态
- 新增、删除、重命名事件
- 修改状态转移条件
- 修改评分阈值、去抖逻辑、cooldown 语义
- 修改 automatic switch 的解释含义

## 输入工件

- [README.md](/Users/didi/Code/github/VoiceSwitch/README.md) 中相关设计段落
- 当前需求、缺陷或产品决策
- 相关状态、事件、日志字段上下文

## 固定步骤

1. 对齐当前行为，禁止直接从“想要的结果”跳到新语义。
2. 明确这次变更属于哪些语义层：状态、事件、转移、评分、cooldown、解释字段。
3. 用模板写出当前行为和拟议变更，避免模糊描述。
4. 明确影响面：FFI、日志、测试、兼容性。
5. 判断是否必须追加 `review-rust-swift-ffi-boundary`。

## 输出工件

- 使用 [proposal-template.md](/Users/didi/Code/github/VoiceSwitch/.codex/skills/generate-state-machine-change-proposal/templates/proposal-template.md)

## 验收标准

- 明确写出当前行为与拟议变更
- 明确列出状态、事件、字段影响面
- 明确兼容性与测试影响
- 明确是否需要 FFI review
