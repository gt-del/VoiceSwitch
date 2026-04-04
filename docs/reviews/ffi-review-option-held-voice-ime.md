# FFI Review: Option Held Voice IME

## 范围

本次审查只覆盖本轮补充项是否改变 Rust / Swift 边界。

涉及代码：

- `RustCore/tests/transition_tests.rs`
- `Sources/VoiceSwitchKit/VoiceSwitchAppModel.swift`
- `Sources/VoiceSwitchKit/UserDefaultsSettingsStore.swift`
- `Sources/VoiceSwitchApp/*`

## 边界检查

### 1. FFI 类型是否变化

没有变化。

本轮未修改：

- `VSState`
- `VSEvent`
- `VSTimerKind`
- Rust core FFI 配置结构
- Rust diagnostic FFI 映射

### 2. 错误码与枚举映射是否变化

没有变化。

本轮新增的设置校验错误、日志分层和导出能力都发生在 Swift 应用层，没有穿透到 Rust FFI。

### 3. 所有权 / 生命周期 / 线程归属是否变化

没有变化。

- Rust core 仍然只负责状态机转移和诊断结果
- Swift 仍然持有调度器、监听器和平台对象
- 新增的自动保存 debounce 仍在 `@MainActor` 模型内协调

### 4. 日志 / 诊断字段跨边界是否变化

没有变化。

- Rust 产出的 `DiagnosticEntry` 结构未改
- Swift 只在应用层新增日志级别与导出格式

### 5. 回放、测试与排障能力是否受影响

未受损。

- FFI 与 CLI 一致性测试仍保留
- Rust core 主路径语义额外增加了矩阵和序列表驱动测试
- Swift 应用层新增的是存储校验和日志治理，不会改变 FFI 结果

## 结论

本轮补充项没有产生 Rust / Swift FFI boundary change。对应 review 结论是“无边界漂移”，当前无需调整 FFI 类型、错误码或桥接映射。
