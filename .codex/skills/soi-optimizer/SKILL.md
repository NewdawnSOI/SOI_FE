---
name: soi-optimizer
description: "Optimize performance-sensitive SOI Flutter code with minimal behavior change. Use when the user asks to optimize a screen, widget, controller, service, cache path, rendering path, rebuild pattern, memory use, or other slow SOI workflow; inspect related layers, edit code directly, add or update tests, and run validation."
---

# SOI Optimizer

Optimize SOI Flutter code without drifting outside the requested scope.
Use `.antigravity/rules.md` as the primary guardrail source and consult the detailed playbooks only when the optimization touches policy-heavy areas.

## Workflow

1. Inspect the requested file or flow first.
   - Check whether the target is a high-risk file under `.antigravity/rules.md`.
   - Read the immediate controller, service, model, manager, or widget collaborators that can explain the hot path.
2. Diagnose the actual bottleneck before editing.
   - Look for rebuild spread, repeated fetches, cache misses, synchronous work inside `build`, sequential async work that can be parallelized, oversized media work, and avoidable allocations.
   - Cross-check cache and lifecycle rules against `.antigravity/rules.md` sections 4 through 6.
3. Share a brief change plan before the first edit.
   - Name the file
   - Name the concrete problem
   - Name the smallest fix that should help
   - Call out what could break if the file is high risk
4. Apply the smallest fix that addresses the bottleneck.
   - Respect layer ownership and never edit `api/generated/**`.
   - Preserve UI behavior unless the user explicitly asked for a visual change.
   - Keep global provider ownership and disposal rules intact.
5. Add or update tests for the changed behavior.
6. Run validation and report the measured or expected improvement.

## Optimization Checklist

Inspect these areas when they match the target:

- rebuild scope: `Consumer`, `Selector`, `setState`, `AnimatedBuilder`, `ListenableBuilder`
- list rendering: `ListView.builder`, fixed extents, virtualization-friendly patterns
- caching: TTL alignment, in-flight dedupe, stale fallback, invalidation width
- async safety: `mounted` checks, subscription and timer cleanup, avoidable serial awaits
- media rules: image cache limits, thumbnail cache usage, autoplay threshold, upload compression flow
- allocation churn: repeated sorting, filtering, string building, or collection cloning in hot paths

## SOI Guardrails

- Do not edit `api/generated/**`.
- Do not dispose globally owned controllers from a screen.
- Do not call global `imageCache.clear()` during dispose.
- Do not add hardcoded user-facing strings; use existing localization patterns.
- Keep optimizations scoped to the requested path unless a directly related collaborator must also change.

## Verification

Run the default SOI validation set when the touched surface warrants it, plus any focused tests for the changed area.

```bash
dart analyze lib/main.dart lib/app lib/api lib/views/about_feed lib/views/about_camera lib/views/about_archiving lib/views/common_widget
dart analyze lib/views/about_notification

flutter test \
  test/api/services/user_service_test.dart \
  test/api/services/post_service_test.dart \
  test/api/services/comment_service_test.dart \
  test/api/services/notification_service_test.dart \
  test/api/controller/user_controller_test.dart \
  test/api/controller/post_controller_test.dart \
  test/api/controller/comment_controller_test.dart
```

Add narrower test commands when only a smaller area changed.

## Report

Summarize:

- changed files
- applied optimization
- validation results
- remaining risk or unmeasured assumptions
