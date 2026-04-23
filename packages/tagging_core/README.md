# tagging_core

`tagging_core` is the shared Dart engine for anchored tagging flows.

It keeps only the reusable tagging behavior:

- draft staging
- anchor position math
- save request creation
- overlay/thread cache orchestration

It does not include platform UI, API clients, or service-specific tagging rules.

## Install

```yaml
dependencies:
  tagging_core:
    git:
      url: https://github.com/minchanpark/tagging_core.git
      ref: v0.1.0
```

## What this package contains

- shared tagging models such as `TagEntry`, `TagDraft`, and `TagContent`
- save contracts such as `TagSaveRequest`
- query and mutation ports for service adapters
- the session controller that coordinates draft state and cached entries

## What stays outside this package

- input UI
- overlay rendering widgets
- service-specific metadata such as profile, emoji, or reply policy
- API mapping and persistence code
