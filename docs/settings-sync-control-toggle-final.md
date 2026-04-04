# Settings Sync Checklist

## Setting Summary

- Name:
  - `switchToVoiceDelay`
  - `switchToPrimaryDelay`
  - `cooldownDuration`
- Default:
  - `0.00s`
  - `0.00s`
  - `5.0s`
- Validation rule:
  - `switchToVoiceDelay` / `switchToPrimaryDelay`: `0.0...0.3`
  - `cooldownDuration`: `0.5...30.0`
- User-visible meaning:
  - 第一次按左 Control 切到语音输入法，第二次按左 Control 切回普通输入法

## Sync Checklist

- [x] README is updated if user-facing behavior changed
- [ ] AGENTS.md long-term constraints are updated if needed
- [x] Settings explanation is aligned
- [x] Debug copy is aligned
- [x] Validation rule is documented
- [x] Default value is documented
- [x] Existing config compatibility impact is assessed

## Notes

- `AGENTS.md` 无需修改，因为长期约束、边界和门禁没有变化。
- 旧配置兼容性不受影响；字段名、默认值、保存方式都没改。
- 仅用户文案从“规则描述”收口为最终 toggle 语义。
