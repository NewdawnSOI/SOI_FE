---
name: refactor-long-file-srp
description: "Refactor oversized source files into smaller single-responsibility units with shallow dependency chains while preserving behavior. Use when a user asks to split a long file, break up a god object, reduce coupling, extract helpers or services, or improve maintainability without changing product behavior."
---

# Refactor Long File SRP

Refactor large files into cohesive units with explicit ownership.
Preserve runtime behavior and keep the dependency graph easy to trace.

## Workflow

1. Inspect the target file and its immediate collaborators before editing.
   - Use `rg --files`, `rg`, `sed`, and parallel shell reads to understand ownership and call flow.
   - Run `update_plan` when the refactor spans multiple files or extraction stages.
2. Map the responsibilities that currently coexist in the file.
   - Separate orchestration, IO, mapping, formatting, state management, and UI concerns.
   - Decide which responsibilities should remain at the entrypoint and which should move.
3. Extract incrementally.
   - Extract pure functions first.
   - Extract helpers, services, widgets, or mappers next.
   - Keep each step compile-safe and behavior-preserving.
4. Keep dependency depth shallow.
   - Prefer constructor injection over hidden lookups.
   - Avoid daisy chains and circular dependencies.
   - Keep orchestration near the top-level entrypoint.
5. Validate after the refactor.
   - Run formatting, targeted analysis, and the most relevant tests.

## Design Rules

- Give each new type or module one clear reason to change.
- Prefer composition over inheritance unless polymorphism is required.
- Avoid passing wide context objects when a narrow value or interface is enough.
- Keep names aligned to role, such as `*Service`, `*Mapper`, `*Formatter`, `*Controller`, or `*Widget`.
- Preserve public APIs unless the user explicitly asked for interface changes.

## Extraction Heuristics

Use these as signals, not hard thresholds:

- file length above roughly 350-500 LOC
- class length above roughly 200-300 LOC
- method length above roughly 40-60 LOC
- branching depth above 3
- constructor dependencies above 5
- one file mixing 3 or more distinct concerns

## Acceptance Checklist

- Each extracted unit has a clear responsibility.
- The dependency chain is shorter or easier to follow.
- No circular dependency was introduced.
- Existing behavior still matches tests or the inspected flow.
- The final report explains what moved, what stayed, and any residual follow-up work.
