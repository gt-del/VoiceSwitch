# VoiceSwitch AGENTS

## 1. 项目定位

VoiceSwitch 是一个运行于 macOS 的菜单栏常驻工具，用于根据用户输入行为在常规输入法和语音输入法之间自动切换。

本文件是项目级协作约束。

- `README.md` 是产品与工程设计主文档。
- `AGENTS.md` 只负责协作约束、角色边界、门禁规则与长期维护要求。
- 不要把 `AGENTS.md` 写成设置说明书、实现教程或 README 的重复版。

## 2. 项目目标与非目标

### 2.1 目标

- 按输入行为模式切换输入法，而不是按 App 或网站切换。
- 在未检测到语音行为时，默认偏向 Primary IME。
- 在检测到语音触发行为后切换到 Voice IME。
- 在恢复正常打字后自动回切到 Primary IME。
- 始终保留用户手动切换输入法的最高优先级。

### 2.2 非目标

- 不做按应用或域名切换。
- 不做云同步。
- 不做跨平台版本。
- 不做通用语音软件识别框架。
- 不做输入内容层面的文本处理。

## 3. 架构边界

### 3.1 SwiftUI / AppKit 负责

- 菜单栏 UI
- 设置页 UI
- 权限申请与系统引导
- macOS 原生 API 薄封装
- 开机启动
- Swift 到 Rust 的桥接编排

### 3.2 Rust Core 负责

- 核心状态机
- 行为分类器
- 规则引擎
- cooldown / 去抖 / 评分逻辑
- 配置校验
- 日志与诊断核心模型

### 3.3 分层原则

- Core 只消费抽象事件，不直接消费 AppKit 生命周期语义。
- 平台层负责把系统事件转换为领域事件，不定义状态机语义。
- UI 层负责展示和命令编排，不形成第二套规则源。
- 所有自动切换都必须可解释，且可通过日志回放关键原因。

## 4. 术语表

- `state machine semantics`
  指状态、事件、转移条件、评分阈值、cooldown 语义及其解释含义。
- `abstract event`
  指脱离具体 macOS API 细节后的领域事件，例如 `optionPressed`、`manualSwitchDetected`、`permissionUnavailable`。
- `manual override`
  指用户手动切换输入法后，自动切换逻辑必须让位的行为。
- `cooldown`
  指 manual override 后的一段抑制自动切换时间窗。
- `degrade path`
  指缺权限、输入源失效、监听失效等异常下的降级处理路径。
- `recover path`
  指从异常或降级状态恢复到可工作状态的路径。
- `observability`
  指能从日志和诊断信息中解释自动切换、异常、降级和恢复过程的能力。
- `rule source`
  指定义业务语义的唯一规则来源。本项目的状态机语义只能由 Rust core 定义。

## 5. 决策优先级

1. 状态机语义由 Rust core 定义。
2. 平台事实、系统限制和恢复可能性由 macos-systems 提出。
3. FFI 形状由边界设计决定，变更必须经过 FFI 审查 skill。
4. UI 层只能展示 core 输出、映射文案、触发用户命令，不得形成第二规则源。
5. QA 可以要求补可测性和可观测性，但不能改变业务语义。

## 6. 变更分类

- `Semantic change`
  状态、事件、转移、评分规则、cooldown 语义变化。
- `Boundary change`
  FFI 类型、错误码、线程归属、桥接协议变化。
- `Platform change`
  仅指 Event Tap、权限、输入源、启动项、监听初始化/恢复变化；不含 FFI，不含 UI 文案。
- `Presentation change`
  菜单栏、设置页、调试文案、权限引导 UI 变化。
- `Observability change`
  日志字段、自动切换解释字段、诊断文案、恢复证据变化。

## 7. 改动门禁映射表

| 变更类型 | 必触发 skill | 可选触发 skill |
| --- | --- | --- |
| `Semantic change` | `generate-state-machine-change-proposal` | `review-rust-swift-ffi-boundary`（若波及边界）, `review-log-observability`（若波及解释字段或日志 schema）, `sync-setting-docs`（若波及设置或校验规则） |
| `Boundary change` | `review-rust-swift-ffi-boundary` | `generate-state-machine-change-proposal`（若语义变化）, `review-log-observability`（若诊断字段跨边界变化）, `macos-permission-test-checklist`（若恢复链路受影响） |
| `Platform change` | `macos-permission-test-checklist` | `review-log-observability`（若降级或恢复证据变化）, `review-rust-swift-ffi-boundary`（若桥接协议被迫变化）, `sync-setting-docs`（若设置或校验规则受影响） |
| `Presentation change` | `sync-setting-docs`（设置页、设置语义、validation rule 相关）, `macos-permission-test-checklist`（权限引导相关）, `review-log-observability`（调试/诊断文案相关） | `generate-state-machine-change-proposal`（若暴露出语义变更）, `review-rust-swift-ffi-boundary`（若 UI 改动倒逼边界变化） |
| `Observability change` | `review-log-observability` | `generate-state-machine-change-proposal`（若解释字段语义受状态机影响）, `review-rust-swift-ffi-boundary`（若诊断字段跨边界变化）, `macos-permission-test-checklist`（若权限/恢复证据变化） |

说明：

- 一个具体改动可以同时命中多个变更类型。
- 只要命中某类变更，就必须执行该类的必触发 skill。
- 若认为某条门禁不适用，必须在任务上下文中显式说明原因。

## 8. 代码归属边界

### 8.1 Rust Core

- 可以定义状态、事件、转移、评分、cooldown、诊断模型。
- 不得直接定义菜单栏状态文案、设置页字段文案、权限引导文案。
- 不得把 macOS 平台 API 语义作为核心规则前提。

### 8.2 macOS Systems

- 可以提出平台事实、桥接需求、恢复建议。
- 不得擅自扩展状态语义。
- 不得直接定义 FFI 类型形状、错误码集合、回调协议。

### 8.3 Swift UI

- 可以展示状态、触发用户命令、映射 UI 文案。
- 不得在 ViewModel 或桥接层新增与状态机语义等价的二次判定逻辑。
- 不得基于本地计时器、键序列、权限状态自行推导业务状态。

### 8.4 QA / Regression

- 可以要求补测试点、日志字段、可测性接口。
- 不得定义产品行为、状态语义或交互规则。

## 9. 日志与 FFI 原则

### 9.1 日志与诊断原则

- 每次自动切换必须可解释。
- 关键日志至少应覆盖 `trigger`、`reason`、`source_state`、`target_state`。
- manual override、cooldown 边界、degrade path、recover path 必须可观测。
- 日志字段 schema 变化必须检查历史可读性和工具兼容性。

### 9.2 FFI 原则

- FFI 只暴露稳定、可映射、可回放、可测试的边界类型。
- 错误码必须稳定且可枚举。
- 生命周期、线程归属、所有权方向必须显式。
- 平台对象语义不得直接穿透为 core 规则前提。

## 10. 项目内 Agent / Skill 使用约定

- 项目级 agent 定义文件位于 `.codex/agents/`。
- 项目级 skill 定义文件位于 `.codex/skills/`。
- 执行相关任务时必须显式读取对应定义文件，不依赖工具自动发现。
- 自定义 agent 和 skill 的内容必须服从本文件定义的术语、门禁与边界。
