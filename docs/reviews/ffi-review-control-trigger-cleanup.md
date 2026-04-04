# FFI Boundary Review Checklist

## Boundary Summary

本次边界变更把 Rust / Swift / C FFI 的切换事件从 `OptionPressed / OptionReleased` 重命名为 `ControlPressed / ControlReleased`，同时同步结构化诊断 `trigger` / `reason`。事件值数量、顺序和所有权方向不变，只调整命名与对应的字符串内容。

## Checklist

- [x] Ownership direction is explicit
- [x] Lifetime boundary is explicit
- [x] Thread affinity is explicit
- [x] Enum mapping is complete
- [x] Error code set is stable
- [x] Diagnostic fields are aligned
- [x] Replay strategy exists
- [x] Testability remains intact

## Risks

- 历史测试和任何依赖旧 `optionPressed` 字符串的外部脚本会失配
- 结构化日志字段重命名后，旧日志查询关键字需要一起更新

## Required Follow-ups

- 更新 Rust transition tests
- 更新 Swift bridge tests
- 更新 README 与设计文档中的事件名和 reason 示例
