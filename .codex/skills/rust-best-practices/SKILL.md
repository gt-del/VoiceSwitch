---
name: rust-best-practices
description: Use when writing, reviewing, or modifying Rust code in VoiceSwitch, especially for error handling, API design, ownership, performance, tracing, and idiomatic implementation patterns.
---

# Rust Best Practices

这是为 VoiceSwitch vendoring 的 `rust-best-practices` 项目级版本。

来源依据：

- `majiayu000/claude-arsenal` 的 `rust-best-practices` skill 页面摘要
- Microsoft Pragmatic Rust Guidelines
- Rust 社区通用实践

本 skill 只提供 Rust 编码实践，不决定本仓库的状态机语义、FFI 边界或日志解释字段。

## 何时触发

- 编写新的 Rust 代码
- 修改现有 Rust 代码
- 审查或重构 Rust core 实现
- 处理错误边界、API 设计、性能、所有权与借用问题

## 核心原则

1. 用类型系统表达约束，尽量让非法状态不可表示。
2. 顺着 ownership 和 borrowing 工作，不用 `clone()` 逃避设计问题。
3. 显式优先于隐式，尤其是 fallibility、mutability、lifetime。
4. 优先零成本抽象，不为了“看起来简单”牺牲结构。
5. 早失败，清楚恢复，错误必须显式建模。

## 实现要求

### 错误处理

- library-like 代码优先用显式错误类型，推荐 `thiserror`
- 应用壳层或命令编排场景可用 `anyhow`
- 避免无理由 `unwrap()` / `expect()`
- 失败路径必须显式，不能把错误吞掉

### 所有权与借用

- 避免为绕过 borrow checker 滥用 `clone()`
- 优先重构作用域、借用方式或数据流
- 仅在有明确理由时使用共享所有权
- 避免默认把问题推给 `Arc<Mutex<_>>`

### API 与类型

- 公共接口必须清楚表达输入、输出和失败方式
- 优先用 domain types、新类型或枚举表达业务约束
- 避免用宽泛的 `String`、`Box<dyn Error>`、未约束结构承载核心语义

### 可观测性与测试

- 变更时要考虑 tracing 影响
- 变更时要考虑 replayability 影响
- 测试必须覆盖新增行为或调整后的失败路径
- 关键路径需要保留足够诊断信息

## 常见反模式

- `unwrap()` everywhere -> `?` + 明确错误类型
- 为满足编译器而到处 `clone()` -> 先重构借用和数据流
- `Box<dyn Error>` 乱用 -> 优先具体错误类型
- 过度使用 `Arc<Mutex<_>>` -> 优先消息传递、所有权拆分或更清晰的同步模型
- 把平台细节带进 core -> 保持抽象事件边界

## 项目边界提醒

- 本 skill 不决定状态、事件、转移和 cooldown 语义
- 本 skill 不决定日志解释字段
- 本 skill 不决定 Rust-Swift FFI 边界
- 这些内容仍由 `AGENTS.md` 和项目内门禁 skill 决定
