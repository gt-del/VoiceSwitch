# Control Trigger Semantic Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 VoiceSwitch 当前“左 Control toggle 切换”的真实产品语义，完整同步到 Rust、FFI、Swift、日志字段、文档和测试命名。

**Architecture:** 先用失败测试锁定新的 `controlPressed / controlReleased` 语义，再从 RustCore 事件和诊断字段向外推进到 FFI、Swift bridge、平台层与 UI。交互行为保持不变，只做命名和解释字段清理，避免再次引入行为漂移。

**Tech Stack:** RustCore, C FFI, Swift Package Manager, Swift Testing

---

### Task 1: 锁定新的事件命名测试

**Files:**
- Modify: `Tests/VoiceSwitchKitTests/KeyboardEventTapServiceTests.swift`
- Modify: `Tests/VoiceSwitchKitTests/RustEngineBridgeTests.swift`
- Modify: `Tests/VoiceSwitchKitTests/VoiceSwitchAppModelKeyboardEventTests.swift`
- Modify: `RustCore/tests/transition_tests.rs`

- [ ] 写失败测试，要求 Swift 和 Rust 统一使用 `controlPressed / controlReleased`
- [ ] 运行针对性测试，确认当前因旧命名失败
- [ ] 只改最小实现使这些测试转绿
- [ ] 再跑对应测试集确认没有多余回归

### Task 2: 重命名 RustCore 事件和诊断字段

**Files:**
- Modify: `RustCore/src/event.rs`
- Modify: `RustCore/src/engine.rs`
- Modify: `RustCore/tests/transition_tests.rs`

- [ ] 把 `OptionPressed / OptionReleased` 改成 `ControlPressed / ControlReleased`
- [ ] 把 `pressed_option_switch_to_voice / released_option_switch_to_primary` 改成 control 版本
- [ ] 运行 `cargo test --manifest-path RustCore/Cargo.toml`

### Task 3: 重命名 FFI 枚举和桥接映射

**Files:**
- Modify: `RustCore/src/ffi.rs`
- Modify: `Sources/VoiceSwitchFFI/include/voiceswitch_ffi.h`
- Modify: `Sources/VoiceSwitchKit/RustEngineBridge.swift`

- [ ] 把 `VSEventOptionPressed / Released` 改成 `VSEventControlPressed / Released`
- [ ] 更新 Rust <-> C <-> Swift 映射
- [ ] 运行 `swift test --filter RustEngineBridgeTests`

### Task 4: 重命名 Swift 抽象事件与平台层映射

**Files:**
- Modify: `Sources/VoiceSwitchKit/EngineModels.swift`
- Modify: `Sources/VoiceSwitchKit/KeyboardEventTapService.swift`
- Modify: `Sources/VoiceSwitchKit/VoiceSwitchAppModel.swift`

- [ ] 把 Swift 抽象事件改成 `controlPressed / controlReleased`
- [ ] 让左 `Control` toggle 编排继续成立
- [ ] 保持 `Option` 原始事件只作为豆包自己的键，不被 VoiceSwitch 使用
- [ ] 运行 `swift test --filter KeyboardEventTapServiceTests --filter VoiceSwitchAppModelKeyboardEventTests`

### Task 5: 清理文档和其余测试

**Files:**
- Modify: `README.md`
- Modify: `Tests/VoiceSwitchKitTests/*.swift`
- Modify: `docs/**/*.md`

- [ ] 更新 README 中的事件名、日志示例和交互描述
- [ ] 更新历史 proposal / review 文档中仍引用的当前主语义字段
- [ ] 运行全量 `swift test`

### Task 6: 全量验证

**Files:**
- Modify: 无

- [ ] 运行 `cargo test --manifest-path RustCore/Cargo.toml`
- [ ] 运行 `swift test`
- [ ] 检查 `rg -n "optionPressed|optionReleased|pressed_option|released_option|VSEventOption" README.md Sources RustCore Tests docs` 只剩历史归档文档或明确保留项
