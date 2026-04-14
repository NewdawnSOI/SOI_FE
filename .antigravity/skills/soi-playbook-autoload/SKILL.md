---
name: soi-playbook-autoload
description: Load and apply `.antigravity/rules.md` as the primary always-on rule set for SOI work, use the KR/EN playbooks as detailed references only when needed, and keep those rule docs aligned when maintaining project guidance.
---

# SOI Rules Autoload (Antigravity Context-Efficient)

## Overview

Use `.antigravity/rules.md` as the default rule source for SOI tasks.
Use `docs/AI_AGENT_PLAYBOOK.md` and `docs/AI_AGENT_PLAYBOOK.en.md` as detailed references only when the task actually needs deeper semantics or when documentation/rule maintenance is requested.

## Workflow

1. Validate primary rule file first using `list_dir` or `view_file` at `.antigravity/rules.md`.

- If missing, fallback to `docs/AI_AGENT_PLAYBOOK.md`.
- If both are missing, stop and report missing required guidance files.

2. Leverage Antigravity Persistent Context.

- Antigravity automatically absorbs injected `<user_rules>`. 
- Since Antigravity tracks conversation history, avoid reading full rule files repeatedly in the same session.

3. Apply session deep-read policy.

Read `docs/AI_AGENT_PLAYBOOK.md` / `docs/AI_AGENT_PLAYBOOK.en.md` (partial section read, not full-file by default) only when the task requires detailed contract/guardrail semantics:

- OpenAPI/DTO contract or regeneration work
- Media compression/cache/performance tuning
- Caching policy matrix reconciliation
- Localization policy changes
- Push/deep-link/notification navigation work
- High-risk release review scenarios
- Documentation/rule maintenance touching `AGENTS.md`, either playbook, or this skill itself

Guideline:
- Use targeted section reads (e.g., `rg`, `sed -n` around specific headings).
- When verifying structure, prefer current workspace commands such as `find` and `rg --files` over tracked-tree-only commands.
  - If the task edits guidance docs, keep `.antigravity/rules.md`, the Korean playbook, the English playbook, and this skill aligned in the same turn.
- Avoid full-file playbook reads unless absolutely necessary.

5. Build and keep a short execution checklist from rules.md.

- Branch/source-of-truth checks (`git branch`, `git status`)
- Role/responsibility comment rule for edited declarations (`.antigravity/rules.md` §2A)
- API boundary rules (`api/generated` read-only, wrapper sync boundaries)
- Provider ownership/dispose rules for global controllers
- Current locale policy (`ko/ja/zh/es/en`, `fallbackLocale=en`, `resolveSupportedLocale()`)
- Push/deep-link guardrails and route fallback checks
- Media/caching guardrails and validation baseline

6. Execute the user request under the checklist.

- Prefer code-as-truth when docs and code conflict.
- Surface constraint violations early.
  - Re-check rules.md structurally in long-running sessions before critical steps.

## Fallback behavior

If `.antigravity/rules.md` does not exist:
- Use `docs/AI_AGENT_PLAYBOOK.md` as the temporary source, and consult the English playbook only when a second-language cross-check is needed.
- Recommend creating/updating `.antigravity/rules.md` for efficient operation.
