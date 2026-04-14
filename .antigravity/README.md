# Antigravity Harness

This directory contains the rules and skills for the Antigravity AI assistant.

## Rules
- `rules.md`: This file contains global rules that Antigravity MUST follow (copied from `AGENTS.md`). It defines project-specific architectural boundaries, token saving policies, and core check-up procedures.

## Skills
The `skills/` directory contains custom executable scripts and instructions that act as 'skills' for the AI.
When you need to perform an operation defined here, read the `SKILL.md` inside the respective skill directory to understand how to execute it.

Available skills:
- `api-lib-sync`: API definition synchronization and generation.
- `prompt-hybridizer`: Prompt aggregation or combination operations.
- `refactor-long-file-srp`: Tools to refactor heavy or long Dart/Flutter files respecting Single Responsibility Principle.
- `soi-optimizer`: Utilities for SOI optimization.
- `soi-playbook-autoload`: Autoload logic for playbook rules.

### How to use
When explicitly asked to run a skill, Antigravity will view the corresponding `SKILL.md` inside `.antigravity/skills/<skill-name>/` to learn the exact terminal commands and steps required for that skill.
