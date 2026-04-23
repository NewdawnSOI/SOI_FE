# tagging_flutter

`tagging_flutter` is the Flutter surface package for anchored tagging flows.

It sits on top of `tagging_core` and provides Flutter-only pieces such as:

- overlay placement widgets
- drag handle widgets
- shared bubble and avatar rendering
- geometry helpers for Flutter layouts

It does not include platform-specific composer UI or service adapters.

## Install

```yaml
dependencies:
  tagging_core:
    git:
      url: https://github.com/minchanpark/tagging_core.git
      ref: v0.1.0
  tagging_flutter:
    git:
      url: https://github.com/minchanpark/tagging_flutter.git
      ref: v0.1.0
```

## What this package expects

- your app provides the input UI
- your service adapter maps API models to `TagEntry`
- your app chooses how to build avatars and expanded tag content
