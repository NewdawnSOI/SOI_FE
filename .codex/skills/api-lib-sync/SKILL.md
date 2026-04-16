---
name: api-lib-sync
description: "Synchronize `lib/api` wrappers with the generated contract under `api/generated`. Use when regenerated APIs or DTOs changed, when wrapper drift between `api/generated/lib/**` and `lib/api/**` must be audited, or when Codex needs a generated-first baseline sync for services, controllers, models, `api.dart`, or `api_client.dart`."
---

# API Lib Sync

Treat `api/generated/lib/**` as the source of truth for wrapper sync.
Never edit `api/generated/**` unless the user explicitly asks for regeneration or generated patching.

## Workflow

1. Choose the sync mode.
   - Use the fast path for a narrow diff.
   - Use a full baseline audit when the user asks for a full, exhaustive, generated-first pass.
2. Run the bundled impact script before broad code reads.
3. Classify every generated API and model file before editing:
   - aligned
   - stale
   - missing wrapper
   - transport or helper only
   - intentional skip or manual follow-up
4. Read only the generated files and wrapper files needed to resolve each mismatch.
   - Prefer `rg`, `sed`, and parallel shell reads over full-directory scans.
   - Read [references/mapping-rules.md](references/mapping-rules.md) when ownership is ambiguous or when running a full audit.
5. Update wrapper-layer code with `apply_patch`.
   - Sync `lib/api/models/*.dart`
   - Sync `lib/api/services/*.dart`
   - Sync `lib/api/controller/*.dart`
   - Update `lib/api/api.dart` and `lib/api/api_client.dart` when public wrapper ownership changes
6. Verify with targeted formatting, analysis, and tests.

## Impact Script

Run the bundled script first.

```bash
scripts/api_change_impact.sh <repo-root>
```

Use branch-to-branch diff mode when needed.

```bash
scripts/api_change_impact.sh <repo-root> <base-ref> <head-ref>
```

Use a full generated-contract audit when the task is exhaustive.

```bash
scripts/api_change_impact.sh <repo-root> --full-audit --include-untracked
```

Useful flags:

```bash
scripts/api_change_impact.sh <repo-root> --include-untracked
scripts/api_change_impact.sh <repo-root> --wide-openapi
scripts/api_change_impact.sh <repo-root> --full-audit
```

Use the script output as the hard scope for deeper review.
If only `api/openapi.yaml` changed and generated deltas are absent, regenerate first before claiming precise wrapper sync.

## Classification Rules

Resolve every generated artifact explicitly before editing wrappers.

For generated API files:

- Map each file to its owning service, controller, and public wrapper surface.
- Compare method names, params, nullability, pagination, and response envelopes.
- Mark each generated method as wrapped, intentionally service-only, intentionally skipped, missing, or stale.

For generated model files:

- Decide whether the file is a domain wrapper candidate, request-only DTO, transport/helper DTO, aggregate-backed model, or intentional skip.
- Check field-level mapping for renamed fields, nullability, enums, and nested DTO changes.
- Do not force false 1:1 symmetry for DTOs that should stay service-local.

Do not mark a file as aligned until every generated method or field has an explicit ownership decision.

## Editing Rules

- Generated contracts win over stale wrapper code.
- Preserve app-facing ergonomics only when they still faithfully represent the generated contract.
- Keep exception mapping intentional; do not hide transport failures behind business-state fallbacks unless the app already requires that behavior.
- Prefer minimal wrapper edits over opportunistic cleanup outside the impacted contract surface.

## Verification

Run targeted checks for touched files unless the audit spans many wrapper domains.

```bash
dart format <changed-files>
dart analyze <changed-files>
flutter test <relevant-tests>
```

Add or update regression coverage when the sync changes:

- DTO mapping
- error classification
- controller branching
- service/controller coverage for newly wrapped generated methods

## Report

Summarize:

- which mode ran
- which generated APIs or models were stale or missing before the sync
- which files changed and why
- which skips were intentional
- which validations ran
- any remaining ambiguity or follow-up risk
