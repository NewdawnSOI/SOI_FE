---
name: api-lib-sync
description: Synchronize `lib/api` wrappers to the generated contract under `api/generated`. Use for fast diff-based sync or full baseline audits that compare every generated API/model against `lib/api` services, controllers, models, `api.dart`, and `api_client.dart`, then update wrappers from the generated source of truth.
---

# API Lib Sync

## Overview

Use this skill when `api/generated/lib` is the source of truth and `lib/api` must be brought back into alignment.
Focus on wrapper-layer consistency: request/response mapping, exception handling, controller behavior, and public wrapper surfaces.

Support two modes:

- Fast path: diff-based sync for changed generated contracts only
- Full baseline audit: compare every generated API/model against `lib/api` wrapper surfaces before editing

Prefer full baseline audit when the user asks for:

- "전체", "모든", "전수", "generated 기준"
- wrapper drift analysis across `api/generated/lib/**` and `lib/api/**`
- skill updates that should enforce generated-first syncing behavior

## Workflow

1. Choose sync mode: fast path or full baseline audit.
2. Build generated-to-wrapper inventory with the bundled script.
3. Classify every generated file before editing: aligned, stale, missing wrapper, transport/helper-only, or intentional app-local skip.
4. Read only the generated files and wrapper files required to resolve each mismatch.
5. Update `lib/api/models`, `lib/api/services`, `lib/api/controller`, plus `lib/api/api.dart` and `lib/api/api_client.dart` when needed.
6. Verify with targeted checks and summarize behavioral changes, intentional skips, and residual risks.

## Step 1: Build Inventory

Run the bundled script first in one of these modes.

```bash
scripts/api_change_impact.sh <repo-root>
```

For branch-to-branch diff:

```bash
scripts/api_change_impact.sh <repo-root> <base-ref> <head-ref>
```

For full generated-contract audit:

```bash
scripts/api_change_impact.sh <repo-root> --full-audit --include-untracked
```

Optional flags:

```bash
scripts/api_change_impact.sh <repo-root> --include-untracked
scripts/api_change_impact.sh <repo-root> --wide-openapi
scripts/api_change_impact.sh <repo-root> --full-audit
```

- Default mode excludes `api/generated/doc/**` and focuses on contract files only.
- Default mode keeps the scope narrow and does not auto-expand `openapi.yaml` changes to whole `lib/api/**`.
- Use `--wide-openapi` only when generated files are not available yet and broad review is explicitly needed.
- `--full-audit` inventories every generated API/model plus the wrapper surfaces that must stay aligned.

In full baseline audit, the inventory must cover:

- `api/generated/lib/api/*.dart` excluding backups
- `api/generated/lib/model/*.dart`
- `lib/api/api.dart`
- `lib/api/api_client.dart`
- `lib/api/models/*.dart`
- `lib/api/services/*.dart`
- `lib/api/controller/*.dart`

Do not start editing until each generated artifact is classified into one of:

- mapped wrapper exists and appears aligned
- mapped wrapper exists but is stale
- wrapper is missing and must be created/extended
- transport/helper DTO handled only inside services
- intentional app-local or product-local wrapper gap that should stay as-is, with an explicit note

## Step 2: Compare Generated Contracts to Wrappers

Use `api/generated/lib/**` as the source of truth. Compare generated contracts to the current wrapper implementation, not the other way around.

For each generated API file:

- Verify the corresponding `SoiApiClient` getter in `lib/api/api_client.dart`
- Verify service coverage in `lib/api/services/*_service.dart`
- Verify controller call sites and branching semantics in `lib/api/controller/*_controller.dart`
- Compare method names, HTTP intent, parameter names, required params, nullable params, pagination, and response envelopes

For each generated model file:

- Classify it as domain DTO vs transport/helper DTO
- Verify `fromDto` / `toDto` mapping and enum handling in `lib/api/models/*.dart` where a domain wrapper exists
- Verify service-side request DTO construction and response unwrapping even when no domain model file exists
- Verify aggregate wrappers that intentionally collapse multiple generated DTOs into one app model

Always compare these contract aspects:

- Endpoint changes: method, path, query/body shape, required params, nullable fields
- DTO changes: renamed fields, nullability, enum values, nested shape
- Error semantics: status code behavior and transport-vs-server failure cases
- Public wrapper surface changes: `lib/api/api.dart` exports and `lib/api/api_client.dart` getters

Prefer targeted reads (`rg`, line ranges) over full-file reads.
Do not read full `api/openapi.yaml` when it is minified unless absolutely required.

## Step 3: Apply Wrapper Sync

Generated contracts win when they conflict with stale wrapper code.

### Public wrapper surface

- Update `lib/api/api_client.dart` when generated API inventory, getter naming, or wrapper ownership changes
- Update `lib/api/api.dart` when exported wrappers/DTOs must match the generated client surface used by the app

### Models (`lib/api/models/*.dart`)

- Keep `fromDto` / `toDto` mapping aligned to generated DTO field names.
- Reflect nullability exactly; do not force unwrap if contract became nullable.
- If enum/source strings changed, update parsing and fallback handling.
- When generated DTOs are transport-only, keep the mapping in services instead of inventing unnecessary domain models.
- When one wrapper model aggregates multiple DTOs, document the mapping explicitly in the sync summary.

### Services (`lib/api/services/*_service.dart`)

- Match generated API method signatures and parameter names.
- Keep response unwrapping (`success`, `message`, `data`) consistent with DTO schema.
- Preserve or improve exception mapping (`ApiException` -> domain exceptions).
- Do not edit `api/generated`; adapt wrapper layer unless user explicitly asks regeneration.
- If a generated endpoint exists with no wrapper yet, create or extend the service wrapper unless the endpoint is intentionally unused and that choice is documented.
- Validate request DTO construction against the latest generated request models, even if the service API stays ergonomic for callers.

### Controllers (`lib/api/controller/*_controller.dart`)

- Align control flow with service semantics (e.g., `null` vs throw behavior).
- Prevent false business branching caused by transport errors.
- Keep state transitions (`_setLoading`, `_setError`, `notifyListeners`) deterministic.
- If wrapper coverage grows because new generated endpoints become app-facing, add controller entry points only where the app architecture expects them.

## Step 4: Verification

Run targeted checks for touched files only unless the audit changes many wrapper domains. In full baseline mode, `dart analyze lib/api` is acceptable when multiple wrapper surfaces changed.

```bash
dart format <changed-files>
dart analyze <changed-files>
flutter test <relevant-tests>
```

If no tests exist, add minimal regression tests for:

- response mapping correctness
- error classification boundaries (404 business case vs network failure)
- controller branching behavior

## Output Requirements

When finishing a sync task, report:

- Which mode was used: fast path or full baseline audit
- The generated-to-wrapper mismatch summary: aligned, updated, missing, intentional skip, manual follow-up
- Updated files and why each changed
- Any intentional behavioral contract changes
- Validation commands run and outcomes
- Risks or follow-up items (e.g., backend ambiguity, missing tests)

## Efficiency Guardrails

- Start with `scripts/api_change_impact.sh`; do not begin with wide `rg` over `lib/api/**`.
- In full baseline mode, do not trim the scope until every generated API/model has been classified.
- Skip non-contract generated changes (`api/generated/doc/**`) unless user asks for docs sync.
- If only `api/openapi.yaml` changed and generated client deltas are absent, report that regeneration is required before precise wrapper sync.
- Keep command count minimal: one inventory run, then targeted reads/edits.
- Do not assume a 1:1 file mapping for every DTO. Transport envelopes and app-local helper wrappers must be classified explicitly instead of forced into false symmetry.

## References

- Mapping rules and checklist: `references/mapping-rules.md`
- Impact detector script: `scripts/api_change_impact.sh`
