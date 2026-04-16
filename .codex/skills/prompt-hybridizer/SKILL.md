---
name: prompt-hybridizer
description: "Rewrite a loose natural-language request into a compact hybrid prompt that mixes short prose with a minimal JSON contract. Use when the user explicitly asks to rewrite or standardize a prompt, prepare a handoff prompt for another agent, or make repeated execution more consistent without forcing a JSON-only format."
---

# Prompt Hybridizer

Turn a vague request into a small execution contract without stripping away the original intent.
Use this as an opt-in structuring step, not as the default response shape.

## Workflow

1. Extract only the facts that materially affect execution:
   - goal
   - task type
   - scope
   - constraints
   - validation
   - assumptions or risks
2. Build a compact JSON block with only the fields that help.
3. Wrap the JSON in a short natural-language instruction block so the result stays reusable and readable.
4. Default the rewritten prompt to English unless the user explicitly requests another language.
5. Use the hybrid prompt internally for execution unless the user specifically asked to receive the rewritten prompt as output.

## Contract Shape

Use this minimal schema and omit empty sections.

```json
{
  "goal": "single sentence target",
  "task_type": "code_change|analysis|docs|command|other",
  "scope": {
    "include": [],
    "exclude": []
  },
  "constraints": {
    "must": [],
    "must_not": []
  },
  "validation": [],
  "assumptions": [],
  "risks": []
}
```

## Rules

- Keep the contract short and concrete.
- Keep JSON keys stable.
- Avoid repeating the full user prompt inside JSON.
- Prefer omission over filler when details are unknown.
- Preserve file paths, command names, and technical identifiers exactly as written.
- Do not invent precise scope or validation details that the request never implied.

## Output Template

Use this shape when the user wants the rewritten prompt.

```text
Request summary:
<1-3 short sentences>

Execution contract:
{JSON block here}

Execution notes:
- Respect the contract, but prefer current code and explicit user instructions when they conflict.
- Keep changes minimal unless the request says otherwise.
- Report results, validation, and remaining risks.
```

## Execution Rule

Prefer using the hybrid prompt to guide the current Codex task instead of producing a handoff-only artifact.
Only hand the prompt back verbatim when the user asked for a rewritten prompt or when another agent truly needs the prompt text.
