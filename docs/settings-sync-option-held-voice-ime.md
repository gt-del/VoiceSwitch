# Settings Sync Checklist

## Setting Summary

- Name:
  - `voiceActivationDelay`
  - `releaseReturnDelay`
  - `cooldownDuration`
- Default:
  - `voiceActivationDelay = 0.0`
  - `releaseReturnDelay = 0.0`
  - `cooldownDuration = 5.0`
- Validation rule:
  - `voiceActivationDelay: 0.0...0.3`
  - `releaseReturnDelay: 0.0...0.3`
  - `cooldownDuration: 0.5...30.0`
- User-visible meaning:
  - `Voice Activation Delay` 仅用于按下 `Option` 后的轻微防抖
  - `Release Return Delay` 仅用于松开 `Option` 后的轻微防抖
  - `Cooldown Duration` 表示手动切换后的自动切换抑制时长

## Sync Checklist

- [x] README is updated if user-facing behavior changed
- [x] AGENTS.md long-term constraints are updated if needed
- [x] Settings explanation is aligned
- [x] Debug copy is aligned
- [x] Validation rule is documented
- [x] Default value is documented
- [x] Existing config compatibility impact is assessed

## Notes

- `AGENTS.md` 当前长期约束未依赖旧参数名，不需要修改。
- `typingKeyWhitelist` 继续保留为内部配置，不暴露在设置页。
- `UserDefaultsSettingsStore` 需要做旧 key 到新 key 的兼容迁移。
