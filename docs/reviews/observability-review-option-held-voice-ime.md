# Observability Review: Option Held Voice IME

## 范围

本次审查只覆盖本轮补充项引入的可观测性变化：

- 设置保存失败的用户日志与诊断日志
- 用户日志 / 诊断日志分层
- 日志 ring buffer 上限
- 日志导出格式
- 权限阻塞原因与恢复提示的展示收口

本次没有修改 Rust core 的 `trigger` / `reason` / `source_state` / `target_state` 语义。

## 字段变化

保留不变：

- `trigger`
- `reason`
- `source_state`
- `target_state`
- `action`
- `current_input_source`
- `target_input_source`
- `cooldown_status`

新增或扩展的观测面：

- `AppLogLevel`
  - `user`
  - `diagnostic`
- 导出日志头部包含：
  - `generated_at`
  - `version`
  - `build`
  - `status`
  - `permissions`
  - `listener`
  - `runtime_executable_path`
  - `bundle_identifier`
  - `bundle_path`

新增诊断场景：

- `trigger=settings_save reason=validation_failed`
- `trigger=launch_at_login reason=applied`
- `trigger=launch_at_login reason=apply_failed`

## 覆盖检查

- 自动切换主路径解释字段仍由 Rust diagnostic 提供，未漂移
- degrade path 仍覆盖：
  - 辅助功能权限缺失
  - 输入监听权限缺失
  - 运行对象不匹配
  - 监听未运行
  - 输入法目标失效
- recover path 仍覆盖：
  - `app_activation` 自动恢复
  - `retryKeyboardMonitoring` 兜底恢复
  - `automation_state` 的 `running` / `restarted` / `disabled` / `stopped_due_to_blocking_issue`

## 稳定性结论

- Rust core 结构化诊断字段未改名
- Swift 侧新增的是日志层级与导出格式，不影响现有 FFI 或 Rust 回放
- ring buffer 只影响保留条数，不影响单条日志 schema

## 受影响消费方

- 主窗口日志页：新增日志筛选与导出
- QA：需要关注导出日志头部和分层筛选
- 排障流程：默认界面不再直接暴露完整路径，完整路径转移到导出日志

## 结论

本轮 observability 变化与当前代码一致，主状态机解释字段保持稳定，新增的日志分层和导出能力不会改变原有切换语义，只提高默认可读性并控制长期日志容量。
