# Observability Review Checklist

## Change Summary

本次变更重写自动切换主路径语义，从“时间窗到期进入语音、typing 回切”改为“按住 Option 保持语音、松开立即回切”。因此 `reason`、`source_state`、`target_state` 的解释语义都会变化。

## Explanation Fields

- [x] `trigger` remains meaningful
- [x] `reason` remains meaningful
- [x] `source_state` remains meaningful
- [x] `target_state` remains meaningful
- [x] `manual_override` remains meaningful
- [x] `cooldown_boundary` remains meaningful

## Path Coverage

- [x] Error path evidence is sufficient
- [x] Degrade path evidence is sufficient
- [x] Recover path evidence is sufficient

## Diagnostic Copy Alignment

- [x] Diagnostic copy matches current field semantics
- [x] Debug UI copy matches current explanation fields

## Field Schema Stability

- [x] Field additions are intentional
- [x] Field removals are intentional
- [x] Field renames are documented
- [x] Field semantics did not drift silently
- [x] Historical logs remain readable
- [x] QA / debug tooling remains compatible

## Follow-ups

- 删除旧 reason：
  - `entered_option_pending`
  - `activated_voice_after_option_window`
  - `awaiting_voice_exit_delay`
- 新测试需要覆盖：
  - `pressed_option_switch_to_voice`
  - `released_option_switch_to_primary`
  - `entered_cooldown_after_manual_switch`
  - `cooldown_expired`
  - `ignored_event_in_current_state`
- `LogPanelView` 测试按钮要同步新主路径事件，避免调试 UI 继续暗示旧语义。
