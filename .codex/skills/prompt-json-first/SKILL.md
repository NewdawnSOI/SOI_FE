---
name: prompt-json-first
description: Transform an incoming user request into a compact JSON execution contract, then execute from that contract. Use when users ask to structure prompts, filter requirements before implementation, reduce ambiguity, or enforce a consistent request-to-action workflow for coding, refactoring, analysis, or command tasks.
---

# Prompt Json First

## Overview

Convert each user request into a JSON contract first.  
Execute only after the contract is complete and internally consistent.

## Workflow

1. Parse the raw request into a JSON block in the response.
2. Validate contract completeness and contradictions.
3. Execute work strictly from the JSON contract.
4. Return outcomes mapped back to contract fields.

## JSON Contract

Use this shape unless the user asks for a different schema:

```json
{
  "goal": "single sentence target outcome",
  "task_type": "code_change|analysis|docs|command|other",
  "scope": {
    "include_files": [],
    "exclude_files": []
  },
  "constraints": {
    "must": [],
    "must_not": []
  },
  "validation": {
    "commands": []
  },
  "assumptions": [],
  "risks": [],
  "execution_plan": []
}
```

## Contract Rules

- Fill `goal`, `task_type`, and `execution_plan` always.
- Keep arrays short and concrete.
- Add only constraints explicitly stated or clearly implied by project rules.
- Record inferred details in `assumptions`.
- Record fragile points in `risks`.
- Keep schema stable across turns unless user asks to change it.
- If the task includes Flutter UI text creation/update, add localization constraints explicitly in `constraints.must` (no hardcoded user-visible text, use localization keys).

## Execution Rules

- Perform actions in `execution_plan` order.
- Run listed `validation.commands` when possible.
- If a required field is unknowable and high-risk, ask one concise clarification.
- If low-risk, proceed with an assumption and document it.
- For Flutter UI text changes, implement localized keys/usages and include locale resource update steps (`ko/es/en`) in `execution_plan`.

## Response Format

1. `JSON Contract` section with a fenced `json` block.
2. `Execution` section with actions taken.
3. `Validation` section with command results or blockers.
4. `Risks/Assumptions` section with unresolved items.
