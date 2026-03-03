---
name: soi-playbook-autoload
description: Load and apply `AGENTS.md` as the primary always-on rule set for SOI work, and read `docs/AI_AGENT_PLAYBOOK.md` only when deep detail is required.
---

# SOI Rules Autoload (Token-Efficient)

## Overview

Use `AGENTS.md` as the default rule source for SOI tasks.
Only read detailed playbook sections when the task actually needs them.

## Workflow

1. Validate primary rule file first.

```bash
test -f AGENTS.md
```

- If missing, fallback to `docs/AI_AGENT_PLAYBOOK.md`.
- If both are missing, stop and report missing required guidance files.

2. Compute fingerprint for change detection.

```bash
shasum AGENTS.md
```

3. Apply session load policy.

- If no cached fingerprint in this session:
  - Read `AGENTS.md` once.
  - Cache fingerprint + short checklist.
- If fingerprint matches:
  - Skip re-read.
  - Reuse cached checklist.
- If fingerprint changed:
  - Re-read `AGENTS.md`.
  - Refresh checklist.

4. Conditional deep-read policy for playbook docs.

Read `docs/AI_AGENT_PLAYBOOK.md` (partial section read, not full-file by default) only when task requires detailed contract/guardrail semantics:

- OpenAPI/DTO contract or regeneration work
- Media compression/cache/performance tuning
- Caching policy matrix reconciliation
- Localization policy changes
- High-risk release review scenarios

Guideline:
- Use targeted section reads (e.g., `rg`, `sed -n` around specific headings).
- Avoid full-file playbook reads unless absolutely necessary.

5. Build and keep a short execution checklist from AGENTS.

- Branch/source-of-truth checks (`git branch`, `git status`)
- API boundary rules (`api/generated` read-only, wrapper sync boundaries)
- Provider ownership/dispose rules for global controllers
- Media/caching guardrails and validation baseline

6. Execute the user request under the checklist.

- Prefer code-as-truth when docs and code conflict.
- Surface constraint violations early.
- Re-check AGENTS fingerprint in long-running sessions before critical steps.

## Fallback behavior

If `AGENTS.md` does not exist:
- Use `docs/AI_AGENT_PLAYBOOK.md` as the temporary source.
- Recommend creating/updating `AGENTS.md` for token-efficient operation.
