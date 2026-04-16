---
name: soi-playbook-autoload
description: "Load and apply `.antigravity/rules.md` as the default SOI rule set for Codex work, consult `docs/AI_AGENT_PLAYBOOK.md` and `docs/AI_AGENT_PLAYBOOK.en.md` only when a task needs deeper policy detail, and keep those guidance files aligned when documentation maintenance is requested."
---

# SOI Playbook Autoload

Use `.antigravity/rules.md` as the first rule source for SOI work.
Treat the detailed Korean and English playbooks as targeted references, not files to reread in full on every task.

## Workflow

1. Check `.antigravity/rules.md` first.
   - If it is missing, fall back to `docs/AI_AGENT_PLAYBOOK.md`.
   - If both are missing, stop and report the missing guidance.
2. Build a short working checklist from the repo rules.
   - branch and status checks
   - role-comment requirements for edited declarations
   - API boundary rules
   - provider and lifecycle ownership
   - localization policy
   - media and cache guardrails
   - minimum validation commands
3. Reuse already gathered rule context instead of rereading the full playbooks every turn.
4. Deep-read only the sections that matter for the active task.

## Deep-Read Triggers

Consult `docs/AI_AGENT_PLAYBOOK.md` or `docs/AI_AGENT_PLAYBOOK.en.md` only when the task touches:

- OpenAPI or DTO contract changes
- media compression, caching, or performance tuning
- localization policy changes
- push, deep-link, or notification navigation policy
- high-risk release review scenarios
- documentation maintenance for `AGENTS.md`, `.antigravity/rules.md`, either playbook, or this skill

Use targeted reads with `rg` and `sed` around the needed section instead of loading whole files.

## Alignment Rule

When editing project guidance, keep these files aligned in the same turn whenever the shared policy changes:

- `.antigravity/rules.md`
- `docs/AI_AGENT_PLAYBOOK.md`
- `docs/AI_AGENT_PLAYBOOK.en.md`
- `.codex/skills/soi-playbook-autoload/SKILL.md`

Prefer current branch code when documentation and implementation disagree.

## Fallback

If only the detailed playbook exists, use it as the temporary source and note that `.antigravity/rules.md` should be restored or refreshed for efficient Codex work.
