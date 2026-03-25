# SOI AI Agent Playbook v2 (Execution Checklist)

This document is the AI execution guide for the `SOI` project.  
The core principle is simple: code is the source of truth, and all changes must be scoped and safe.

## User Context
- The user is a Flutter app developer for `SOI`.
- The user is comfortable with Flutter/Dart, REST APIs, OpenAPI, Provider-based state management, and async flows.
- The user prioritizes performance, reliability, and maintainability.

## Caution
- This guide is specific to `SOI`.
- Final decision authority belongs to the human developer.
- Never expose sensitive data (`.env`, keys/tokens, personal information) in logs or docs.
- If docs and code conflict, follow code on the current branch.

## 0. Source Of Truth & Scope
### Rules
- The current branch code is the single source of truth.
- Check branch context before work with `git branch --show-current`.
- This document is an operating guide; actual contracts must be verified via `api/openapi.yaml` + `api/generated` + `lib/api`.

### Evidence Files
- `lib/main.dart`
- `api/openapi.yaml`
- `api/generated/`
- `lib/api/`

### Risks If Ignored
- Implementing from docs alone can diverge from real API contracts.
- Branch-assumption mistakes can introduce regressions.

### Verification
- `git branch --show-current`
- `git status --short`
- For contract changes: `./.codex/skills/api-lib-sync/scripts/api_change_impact.sh <repo-root>`

## 1. Project Snapshot (Folder Structure Based)
### Rules
- SOI combines a Flutter client, a local OpenAPI/generated workspace, and Firebase Functions.
- App bootstrap responsibilities are split across `lib/main.dart`, `lib/app/*`, and `lib/app/push/*`.
- Keep generated API client (`api/generated`) and app wrapper (`lib/api`) responsibilities separated.
- Validate the snapshot against the current workspace, excluding transient outputs such as `build/`, `.dart_tool/`, `ios/Pods/`, and `functions/node_modules/`.
- Some directories such as `api/` can exist in the workspace even when tracked-tree-only commands do not surface them, so prefer `find`/`rg --files` for structure verification.

### Evidence Files
- Entry/bootstrap: `lib/main.dart`
- App constants/locales: `lib/app/app_constants.dart`
- Provider assembly: `lib/app/app_providers.dart`
- Route map: `lib/app/app_routes.dart`
- App container/layout shell: `lib/app/app_container_builder.dart`
- Dependencies: `pubspec.yaml`
- Generated client package: `api/generated/pubspec.yaml`

### Structure (Current Workspace Folder Tree)
```text
SOI/
├─ .claude/
│  └─ skills/
├─ .codex/
│  └─ skills/
├─ .omc/
│  └─ sessions/
├─ .serena/
│  ├─ cache/
│  └─ memories/
├─ .vscode/
├─ android/
│  ├─ app/
│  ├─ fastlane/
│  └─ gradle/
├─ api/
│  └─ generated/
│     ├─ doc/
│     ├─ lib/
│     │  ├─ api/
│     │  ├─ auth/
│     │  └─ model/
│     └─ test/
├─ assets/
│  ├─ app_launch_video/
│  ├─ fonts/
│  ├─ icon/
│  └─ translations/
├─ docs/
├─ figma_assets/
├─ functions/
│  └─ lib/
├─ ios/
│  ├─ Flutter/
│  ├─ Runner/
│  ├─ Runner.xcodeproj/
│  ├─ Runner.xcworkspace/
│  ├─ RunnerTests/
│  └─ fastlane/
├─ lib/
│  ├─ api/
│  │  ├─ controller/
│  │  ├─ models/
│  │  └─ services/
│  ├─ app/
│  │  └─ push/
│  ├─ theme/
│  ├─ utils/
│  └─ views/
│     ├─ about_archiving/
│     │  ├─ screens/
│     │  └─ widgets/
│     ├─ about_camera/
│     │  ├─ models/
│     │  ├─ services/
│     │  └─ widgets/
│     ├─ about_feed/
│     │  ├─ manager/
│     │  └─ widgets/
│     ├─ about_friends/
│     │  ├─ dialogs/
│     │  └─ widgets/
│     ├─ about_login/
│     │  └─ widgets/
│     ├─ about_notification/
│     │  ├─ services/
│     │  └─ widgets/
│     ├─ about_onboarding/
│     ├─ about_profile/
│     │  ├─ services/
│     │  └─ widgets/
│     ├─ about_setting/
│     └─ common_widget/
│        ├─ about_comment/
│        ├─ about_more_menu/
│        ├─ api_photo/
│        │  ├─ services/
│        │  └─ widgets/
│        └─ report/
├─ public/
│  ├─ .well-known/
│  └─ assets/
└─ test/
   ├─ api/
   │  ├─ controller/
   │  ├─ models/
   │  └─ services/
   ├─ app/
   │  └─ push/
   └─ views/
      ├─ about_archiving/
      ├─ about_camera/
      ├─ about_feed/
      ├─ about_friends/
      ├─ about_login/
      ├─ about_notification/
      ├─ about_profile/
      └─ common_widget/
```

### Risks If Ignored
- Mixing generated/client and wrapper responsibilities causes large breakage on regeneration.
- Missing the `lib/app`/`lib/app/push` split can send edits to the wrong bootstrap/locale/provider/push/route layer.
- Misunderstanding bootstrap order can break login/deep-link/cache behavior.

### Verification
- `find . -maxdepth 2 -type d \( -path './.git' -o -path './build' -o -path './.dart_tool' -o -path './ios/Pods' -o -path './api/generated/.dart_tool' \) -prune -o -maxdepth 2 -type d | sort`
- `find lib -maxdepth 3 -type d | sort`
- `find test -maxdepth 3 -type d | sort`

## 2. API Integration Rules (api-lib-sync Embedded)
### Rules
- Always start contract-change work with the impact detection script.
- Never manually edit generated code (`api/generated/**`).
- Apply OpenAPI changes in this order: `regen -> patch -> wrapper sync`.
- Wrapper sync responsibilities:
- generated `api/model` changes -> `lib/api/models/*`
- generated `api/api` changes -> `lib/api/services/*`
- semantic service changes -> `lib/api/controller/*`
- Contract checklist:
- request: parameter names/types/nullability/required
- response: `success/data/message` envelope + `data` nullability
- error: separate transport failure from business absence

### Evidence Files
- Impact script: `./.codex/skills/api-lib-sync/scripts/api_change_impact.sh`
- Regeneration: `regen_api.sh`
- Generated patch: `api/patch_generated.sh`
- Generator config: `api/config.yaml`
- Wrapper layers: `lib/api/models/`, `lib/api/services/`, `lib/api/controller/`

### Risks If Ignored
- Direct generated hotfixes are lost on next regeneration.
- DTO drift not absorbed by wrapper layers causes runtime parsing failures.
- Treating all `404` as null can misclassify transport failures as business cases.

### Verification
- Impact check:
```bash
./.codex/skills/api-lib-sync/scripts/api_change_impact.sh <repo-root>
```
- Regeneration:
```bash
./regen_api.sh
```
- Wrapper checks:
```bash
dart analyze lib/api/models lib/api/services lib/api/controller
```

## 3. Provider/State Management Rules (Current Version)
### Rules
- The baseline state stack is `provider ^6.1.5 + ChangeNotifier`.
- Global Provider-owned objects are lifecycle-owned by the app root (`lib/main.dart` + `lib/app/app_providers.dart`); never dispose them in screens.
- `UserController` is injected inside `buildAppProviders()` via `ChangeNotifierProvider.value` with a preloaded instance.
- `AnalyticsService` is injected as a shared app-wide `Provider.value`; do not recreate it in screens.
- Global registered controllers:
- `UserController`
- `CategoryController`, `CategorySearchController`
- `PostController`, `FeedDataManager`
- `FriendController`, `CommentController`, `MediaController`
- `NotificationController`, `ContactController`
- `ReportController`, `AudioController`, `CommentAudioController`
- `FeedDataManager` is global cache owner; in `feed_home`, call only `detachFromPostController()`.
- For frame-phase conflict zones, schedule state updates post-frame (`MediaController._scheduleNotify`).
- After async gaps, check `mounted` and visibility (`TickerMode`, `RouteAware`) before reusing context.
- On user switch, compare `FeedDataManager._lastUserId`, then apply `reset(notify: false)` + `forceRefresh`.

### Evidence Files
- App root/provider wiring: `lib/main.dart`, `lib/app/app_providers.dart`
- Global feed cache ownership: `lib/views/about_feed/feed_home.dart`
- User-switch reset/deferred refresh: `lib/views/about_feed/manager/feed_data_manager.dart`
- Frame-safe notify pattern: `lib/api/controller/media_controller.dart`
- Dependency version: `pubspec.yaml`

### Risks If Ignored
- Disposing global objects from screens can trigger `disposed object` errors or cache loss.
- Ignoring visibility/lifecycle checks can cause duplicate fetches or stale hidden-tab UI.
- Missing user-switch invalidation can leak previous-user data.

### Verification
- `rg -n "buildAppProviders|ChangeNotifierProvider<|FeedDataManager" lib/main.dart lib/app/app_providers.dart`
- `rg -n "detachFromPostController|reset\(|_lastUserId|TickerMode|mounted" lib/views/about_feed/manager/feed_data_manager.dart lib/views/about_feed/feed_home.dart`
- `rg -n "_scheduleNotify|addPostFrameCallback" lib/api/controller/media_controller.dart`

## 4. Media Performance Guardrails (Quantitative Recheck)
### Rules
- App image cache limits:
- debug: `maximumSize=50`, `maximumSizeBytes=50MB`
- release: `maximumSize=30`, `maximumSizeBytes=30MB`
- Image uploads use `_maxImageSizeBytes=1MB` as the target via progressive compression.
- Progressive image compression parameters: quality `85 -> 40` (step 10), dimension `2200 -> 960` (scale 0.85), fallback `quality=35`, `dimension=1024`.
- Video size budget is `_maxVideoSizeBytes=50MB`, with staged attempts `1.5Mbps -> 1.0Mbps -> 0.8Mbps -> MediumQuality`.
- Default camera video max duration is `30 seconds`.
- Video thumbnails use a `Memory -> Disk -> Generate` 3-tier cache.
- 3-tier memory cache limits are `maxEntries=120`, `maxBytes=12MB` (LRU).
- Archive grid thumbnail prefetch is capped at 4 videos to reduce startup burst.
- Video autoplay only when visible fraction is `>= 0.6`; pause below that.
- To avoid flicker during presigned URL rotation, keep `cacheKey=postFileKey` and `useOldImageOnUrlChange=true`.
- Never call global `imageCache.clear()` on dispose; evict only the current assets.
- Large payload logs are allowed only under `kDebugMode`.

### Evidence Files
- Image cache config: `lib/main.dart`
- Image/video compression constants: `lib/views/about_camera/services/photo_editor_media_processing_service.dart`
- Upload pipeline/cache evict: `lib/views/about_camera/photo_editor_screen.dart`, `lib/views/about_camera/services/photo_editor_upload_flow_service.dart`, `lib/views/about_camera/services/photo_editor_upload_service.dart`
- Camera recording default duration: `lib/api/services/camera_service.dart`
- 3-tier thumbnail cache: `lib/utils/video_thumbnail_cache.dart`
- Visibility threshold/flicker mitigation: `lib/views/common_widget/api_photo/widgets/api_photo_media_content.dart`, `lib/views/common_widget/api_photo/widgets/api_photo_circle_avatar.dart`
- Archive prefetch cap: `lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart`

### Risks If Ignored
- Over/under-sized cache settings can cause memory pressure or repeated decode costs.
- Missing compression guards can cause upload failures (413) or frame drops.
- Missing visibility/lifecycle control can increase background battery/CPU usage.
- Breaking cache-key behavior on URL rotation can reintroduce shimmer/flicker regressions.

### Verification
- `rg -n "maximumSize|maximumSizeBytes" lib/main.dart`
- `rg -n "_maxImageSizeBytes|_maxVideoSizeBytes|_initialCompressionQuality|_fallbackCompressionQuality" lib/views/about_camera/services/photo_editor_media_processing_service.dart`
- `rg -n "visibleFraction >= 0.6|cacheKey: postFileKey|useOldImageOnUrlChange" lib/views/common_widget/api_photo/widgets/api_photo_media_content.dart lib/views/common_widget/api_photo/widgets/api_photo_circle_avatar.dart`
- `rg -n "_maxEntries|_maxBytes|take\(4\)" lib/utils/video_thumbnail_cache.dart lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart`

## 5. Caching Strategy Matrix (Current Code)
### Rules
- Manage cache keys/TTL/invalidation/fallback explicitly per owner.
- Handle user-switch invalidation separately from TTL expiry.
- For stale-while-revalidate paths, document both immediate cache display and background refresh triggers.

### Evidence Files
- `lib/views/about_feed/manager/feed_data_manager.dart`
- `lib/api/controller/post_controller.dart`
- `lib/api/controller/category_controller.dart`
- `lib/api/controller/notification_controller.dart`
- `lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart`
- `lib/api/controller/media_controller.dart`
- `lib/utils/video_thumbnail_cache.dart`
- `lib/api/services/camera_service.dart`

### Caching Matrix
| Owner | Key | TTL/Limit | Invalidation Trigger | Fallback Behavior | Evidence |
|---|---|---|---|---|---|
| `FeedDataManager` | `_allPosts` + `_lastUserId` | No explicit TTL (session cache) | user switch (`_lastUserId` change), `reset()`, forced refresh on posts-changed | immediate reuse when `forceRefresh=false` | `lib/views/about_feed/manager/feed_data_manager.dart` |
| `PostController` | `"$userId:$categoryId:$page"` | `1h` | `notifyPostsChanged()`, `clearAllCache()`, `invalidateCategoryCache()` | returns expired cache on errors | `lib/api/controller/post_controller.dart` |
| `CategoryController` | per-`CategoryFilter` map + `_lastLoadedUserId` | `30s` | `invalidateCache()`, user change, `forceReload=true` | skip API when cache is valid | `lib/api/controller/category_controller.dart` |
| `NotificationController` (all) | `_cachedResult` + `_lastLoadedUserId` | `30s` | `invalidateCache()`, `refreshNotifications()` | immediate return from valid cache | `lib/api/controller/notification_controller.dart` |
| `NotificationController` (friends) | `_cachedFriendNotifications` | No explicit TTL (latest-result cache) | `invalidateCache()`, re-fetch | API call on miss | `lib/api/controller/notification_controller.dart` |
| Archive category posts | `"$userId:$categoryId"` | `30m` | `forceRefresh`, posts-changed, explicit key remove | display stale cache then refresh in background | `lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart` |
| `MediaController` presigned | `fileKey` | `55m` | remove on expiry, then refetch | in-flight dedupe for concurrent requests | `lib/api/controller/media_controller.dart` |
| `MediaController` video-thumb map | `videoKey -> thumbnailKey` | LRU `100` | evict oldest on overflow, `clearVideoThumbnailCache()` | regenerate/upload path on miss | `lib/api/controller/media_controller.dart` |
| `VideoThumbnailCache` | stable key (`postFileKey` first) | memory LRU `120`, `12MB` + disk cache | `clearMemory()`, process/temp-file cleanup | Memory miss -> Disk -> Generate | `lib/utils/video_thumbnail_cache.dart` |
| `CameraService` first gallery asset | `_cachedFirstGalleryImage` | `5s` | `_invalidateGalleryCache()` after photo/video capture | re-query gallery on miss | `lib/api/services/camera_service.dart` |
| `CameraService` permission state | `_cachedPermissionState` | `10s` | expiry, no-access state, permission changes | `requestPermissionExtend()` on miss | `lib/api/services/camera_service.dart` |

### Risks If Ignored
- Missing expiry policies can keep stale data visible too long.
- Missing user-switch invalidation can contaminate data across users.
- Missing fallback rules can sharply degrade UX during transient network failures.

### Verification
- `rg -n "_cache|cache|Duration\(|invalidate|clear|forceRefresh" lib/views/about_feed/manager/feed_data_manager.dart lib/api/controller/post_controller.dart lib/api/controller/category_controller.dart lib/api/controller/notification_controller.dart lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart lib/api/controller/media_controller.dart lib/utils/video_thumbnail_cache.dart lib/api/services/camera_service.dart`

## 6. Error/Exception Rules
### Rules
- Service layer must map errors into `SoiApiException` hierarchy (`BadRequest/Auth/Forbidden/NotFound/Server/Network`).
- Always separate transport failures from business failures.
- `404 => null` is allowed only for explicitly-approved new-user login paths.
- Core lookup paths (`getUser`, `getPostDetail`) must throw `NotFoundException` or explicit errors.

### Evidence Files
- Exception hierarchy: `lib/api/api_exception.dart`
- User-service transport classification: `lib/api/services/user_service.dart`
- Service mappings: `lib/api/services/*.dart`

### Risks If Ignored
- Misclassifying transport failures as null can trigger wrong UI branches.
- Inconsistent exception hierarchy breaks screen-level message policies.

### Verification
- `rg -n "_handleApiException|NetworkException|NotFoundException" lib/api/services`
- Minimum tests:
```bash
flutter test test/api/services/user_service_test.dart test/api/controller/user_controller_test.dart
```

## 7. Localization Policy (Current Active Locale Baseline)
### Rules
- Active locale policy baseline is `ko`, `ja`, `zh`, `es`, `en`.
- The single source of truth for `supportedLocales` is `lib/app/app_constants.dart`, and `lib/main.dart` passes it into `EasyLocalization`.
- Keep `fallbackLocale` as `en`, and let `resolveSupportedLocale()` map system language to `ko/ja/zh/es`; otherwise default to English.
- For user-facing text changes, update all five active locale bundles (`ko/ja/zh/es/en`) together.
- If one locale is intentionally deferred, document the reason explicitly in the result.
- Preserve key namespaces (`common.*`, `camera.editor.*`).

### Evidence Files
- Locale bootstrap: `lib/main.dart`, `lib/app/app_constants.dart`
- Translation files: `assets/translations/ko.json`, `assets/translations/es.json`, `assets/translations/en.json`, `assets/translations/ja.json`, `assets/translations/zh.json`

### Risks If Ignored
- If you read only `supportedLocales` without `resolveSupportedLocale()`, you can misunderstand the real startup locale policy.
- Mismatched policy vs translation files causes late-stage release localization bugs.
- Hardcoded strings increase i18n regression cost.

### Verification
- `ls -1 assets/translations`
- `rg -n "supportedLocales|resolveSupportedLocale|fallbackLocale|startLocale|englishLocale|koreanLocale|japaneseLocale|chineseLocale|spanishLocale" lib/main.dart lib/app/app_constants.dart`
- Manual check: verify `ko/ja/zh/es` startup for matching device languages, and `en` fallback for all other languages

## 8. High-Risk Files & Review Scenarios (Detailed Current Analysis)
### Rules
- For these files, always run impact analysis and minimum verification commands with the change.
- Before implementation, explicitly document what could break.

### High-Risk File Matrix
| File | Risk Focus | Mandatory Checkpoints |
|---|---|---|
| `lib/main.dart` + `lib/app/app_constants.dart` + `lib/app/app_providers.dart` + `lib/app/app_routes.dart` + `lib/app/app_container_builder.dart` | bootstrap order, active locale policy, global Provider lifecycle, route wiring, wide-layout container | `supportedLocales=[ko, ja, zh, es, en]`, `resolveSupportedLocale`, `fallbackLocale=en`, `buildAppProviders`, `buildAppRoutes`, `buildAppContainer`, `_configureImageCache`, URI dedupe (3s) |
| `lib/views/about_feed/manager/feed_data_manager.dart` + `lib/views/about_feed/feed_home.dart` | global feed cache ownership/user switching/tab visibility | only `detachFromPostController`, `_lastUserId` switch reset, `_pendingPostRefresh` resume refresh |
| `lib/views/about_camera/photo_editor_screen.dart` + `services/photo_editor_upload_flow_service.dart` + `services/photo_editor_upload_service.dart` + `services/photo_editor_media_processing_service.dart` | editor/compression/upload flow composition, temp-file/cache cleanup, category-cover propagation | 1MB/50MB guards, `VideoCompress.deleteAllCache()`, `_evictCurrentImageFromCache`, fallback-to-original on compression failures, text-only path split |
| `lib/views/common_widget/api_photo/api_photo_display_widget.dart` + `widgets/api_photo_media_content.dart` + `widgets/api_photo_comment_overlay.dart` + `widgets/api_photo_circle_avatar.dart` | video lifecycle/visibility playback, image/avatar flicker regressions, pending comment tag alignment | `visibleFraction >= 0.6`, `cacheKey=postFileKey`, `useOldImageOnUrlChange`, tag geometry clamp |
| `lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart` | stale cache display + background paging concurrency | `_cacheTtl=30m`, `allowExpired` behavior, `generation` guard, posts-changed cache removal |
| `lib/api/controller/media_controller.dart` + `lib/utils/video_thumbnail_cache.dart` | presigned cache expiry/dupe requests/thumbnail LRU | presigned `55m`, in-flight dedupe, thumbnail LRU(100), 3-tier limits |
| `lib/app/push/app_push_coordinator.dart` + `lib/views/about_notification/services/notification_navigation_handler.dart` | FCM/bootstrap, local-notification payload decode, authenticated-user sync, push-route resolution | `supportsFirebaseMessaging`, pending launch payload precedence, payload dedupe (5s), `PushNavigationAction` coverage, category/post route completeness |
| `lib/api/services/post_service.dart` + `comment_service.dart` + `user_service.dart` | DTO/enum/nullability mapping and exception classification | `postType/commentType` mapping, `404` policy, `SocketException -> NetworkException` |
| `lib/api/models/post.dart` + `comment.dart` + `notification.dart` | generated DTO to domain-model sync | `PostType`, `CommentType`, `AppNotificationType`, `savedAspectRatio/isFromGallery/parentId/replyUserId/fileKey` |

### Review Scenarios
- Verify deep-link duplicate suppression within 3 seconds for identical URI input.
- Verify `buildAppContainer` still enforces `wideLayoutBreakpoint=600` and `maxWidth=480` on tablet/web widths.
- Verify feed/category caches are fully separated after account switching.
- Verify one-time refresh on tab resume when posts-changed happened while hidden.
- Verify staged compression + upload + category-cover update for videos over 50MB.
- Verify immediate pause when video visible fraction drops below 0.6.
- Verify archive screen shows stale cache immediately then replaces it after background refresh.
- Verify no image flicker when presigned URL rotates for the same `postFileKey`.
- Verify UI branching for `PHOTO/REPLY` comments and `COMMENT_REPLY_ADDED` notifications.
- Verify background data-only pushes display local notifications only when visible content exists.
- Verify push taps enter category/detail flow only when `categoryId/postId` are complete, and otherwise fall back safely to notifications/root.

### Verification
- `rg -n "supportedLocales|resolveSupportedLocale|fallbackLocale|buildAppProviders|buildAppRoutes|buildAppContainer|deepLinkDuplicationWindowSeconds" lib/main.dart lib/app`
- `rg -n "_cacheTtl|allowExpired|generation|visibleFraction >= 0.6|cacheKey: postFileKey|_lastUserId|_pendingPostRefresh" lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart lib/views/common_widget/api_photo/widgets/api_photo_media_content.dart lib/views/common_widget/api_photo/widgets/api_photo_circle_avatar.dart lib/views/about_feed/manager/feed_data_manager.dart`

## 9. Test/Validation Section (Current Test Set)
### Rules
- Always run minimum verification commands for doc/code changes.
- For API/interface/type changes, run both service and controller unit tests.
- For media/cache/localization changes, run explicit manual regression scenarios.

### Evidence Files
- Service tests:
- `test/api/services/user_service_test.dart`
- `test/api/services/post_service_test.dart`
- `test/api/services/comment_service_test.dart`
- `test/api/services/notification_service_test.dart`
- `test/api/services/camera_service_test.dart`
- Controller tests:
- `test/api/controller/user_controller_test.dart`
- `test/api/controller/post_controller_test.dart`
- `test/api/controller/comment_controller_test.dart`
- `test/api/controller/notification_controller_test.dart`
- `test/api/controller/media_controller_test.dart`
- Model tests:
- `test/api/models/comment_post_model_test.dart`
- App/push tests:
- `test/app/push/app_push_coordinator_test.dart`
- View/widget tests:
- `test/views/about_feed/manager/feed_data_manager_test.dart`
- `test/views/common_widget/api_photo/api_photo_tag_overlay_test.dart`
- `test/views/about_camera/services/photo_editor_screen_init_service_test.dart`
- `test/views/about_camera/services/photo_editor_category_flow_service_test.dart`
- `test/views/about_camera/widgets/gallery_thumbnail_test.dart`
- `test/views/about_notification/services/notification_navigation_handler_test.dart`
- `test/views/about_profile/profile_tabs_test.dart`
- Critical change files:
- `lib/main.dart`
- `lib/app/**`
- `lib/api/models/*.dart`
- `lib/api/services/*.dart`
- `lib/views/about_camera/**`
- `lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart`
- `lib/views/common_widget/**`

### Risks If Ignored
- Enum/field expansion misses may ship to production unnoticed.
- Presigned URL/cache-key regressions may reintroduce image flicker.
- User-switch/cache-expiry regressions can degrade feed/archive UX.

### Verification
- Automated tests:
```bash
flutter test \
  test/api/services/user_service_test.dart \
  test/api/services/post_service_test.dart \
  test/api/services/comment_service_test.dart \
  test/api/services/notification_service_test.dart \
  test/api/controller/user_controller_test.dart \
  test/api/controller/post_controller_test.dart \
  test/api/controller/comment_controller_test.dart
```
- Focused model/view tests:
```bash
flutter test \
  test/api/models/comment_post_model_test.dart \
  test/views/about_feed/manager/feed_data_manager_test.dart \
  test/views/common_widget/api_photo/api_photo_tag_overlay_test.dart \
  test/api/controller/notification_controller_test.dart \
  test/api/controller/media_controller_test.dart \
  test/api/services/camera_service_test.dart \
  test/app/push/app_push_coordinator_test.dart \
  test/views/about_camera/services/photo_editor_screen_init_service_test.dart \
  test/views/about_camera/services/photo_editor_category_flow_service_test.dart \
  test/views/about_camera/widgets/gallery_thumbnail_test.dart \
  test/views/about_notification/services/notification_navigation_handler_test.dart \
  test/views/about_profile/profile_tabs_test.dart
```
- Static analysis:
```bash
dart analyze lib/main.dart lib/app lib/api lib/views/about_feed lib/views/about_camera lib/views/about_archiving lib/views/common_widget
```
- Change-point grep:
```bash
rg -n "TEXT_ONLY|MULTIMEDIA|PHOTO|REPLY|COMMENT_REPLY_ADDED|savedAspectRatio|isFromGallery" lib/api
rg -n "supportedLocales|resolveSupportedLocale|englishLocale|koreanLocale|japaneseLocale|chineseLocale|spanishLocale|buildAppProviders|buildAppRoutes|buildAppContainer" lib/main.dart lib/app
rg -n "visibleFraction >= 0.6|cacheKey: postFileKey|useOldImageOnUrlChange" lib/views/common_widget/api_photo/widgets/api_photo_media_content.dart lib/views/common_widget/api_photo/widgets/api_photo_circle_avatar.dart
```
- Manual regression:
- switch user and verify feed/category isolation
- upload large video and verify thumbnail generation/cache behavior
- verify matching startup for device languages `ko/ja/zh/es`, and `en` fallback for all other languages
- verify data-only/background push display conditions and push-tap route fallback

## 10. Shared API/Interface/Type Change Response Rules (Current Contract)
### Rules
- When generated DTO changes are detected, update domain types and service parameters together.
- Do not edit generated code (`api/generated/**`); absorb changes in wrapper (`lib/api/**`).
- Required processing sequence:
- confirm `api/openapi.yaml` change
- run `./regen_api.sh` + `api/patch_generated.sh`
- update mapping in `lib/api/models`
- update request/response/error transformations in `lib/api/services`
- update convenience/default/type inference logic in `lib/api/controller`
- update tests
- Current high-priority contract fields/types:
- `CommentReqDto`: `parentId`, `replyUserId`, `fileKey`, `commentType(EMOJI/TEXT/AUDIO/PHOTO/REPLY)`
- `CommentRespDto`: `replyUserName`, `userProfileKey`, `fileKey`, `waveFormData`, `commentType`
- `NotificationRespDto`: `type` (including `COMMENT_REPLY_ADDED`), `relatedId`, `categoryIdForPost`, `categoryInvitedUsers`
- `PostCreateReqDto`/`PostUpdateReqDto`: `savedAspectRatio`, `isFromGallery`, `postType(TEXT_ONLY/MULTIMEDIA)`
- `PostRespDto`: `savedAspectRatio`, `isFromGallery`, `postType`, `is_active`
- Treat these files as source-of-truth for domain enum/model mapping:
- `lib/api/models/comment.dart`
- `lib/api/models/notification.dart`
- `lib/api/models/post.dart`

### Evidence Files
- Generated models:
- `api/generated/lib/model/comment_req_dto.dart`
- `api/generated/lib/model/comment_resp_dto.dart`
- `api/generated/lib/model/notification_resp_dto.dart`
- `api/generated/lib/model/post_create_req_dto.dart`
- `api/generated/lib/model/post_resp_dto.dart`
- `api/generated/lib/model/post_update_req_dto.dart`
- Wrapper sync points:
- `lib/api/models/comment.dart`
- `lib/api/models/notification.dart`
- `lib/api/models/post.dart`
- `lib/api/services/comment_service.dart`
- `lib/api/services/post_service.dart`
- `lib/api/controller/comment_controller.dart`
- Related tests:
- `test/api/services/comment_service_test.dart`
- `test/api/services/post_service_test.dart`
- `test/api/controller/comment_controller_test.dart`
- `test/api/controller/post_controller_test.dart`

### Risks If Ignored
- Server may ship new fields but app silently drops behavior.
- Missing enum updates can force wrong default branches in parsing/rendering.
- DTO default-value drift can increase server-side 4xx validation failures.

### Verification
- `./.codex/skills/api-lib-sync/scripts/api_change_impact.sh <repo-root>`
- `rg -n "PHOTO|REPLY|COMMENT_REPLY_ADDED|TEXT_ONLY|MULTIMEDIA|savedAspectRatio|isFromGallery|parentId|replyUserId|fileKey|is_active" lib/api api/generated/lib/model`
- `flutter test test/api/services/comment_service_test.dart test/api/services/post_service_test.dart test/api/controller/comment_controller_test.dart test/api/controller/post_controller_test.dart`

## 11. Agent Workflow
### Rules
- Follow this sequence for every task.
- Restate goal/scope -> inspect impacted files -> implement minimal change -> review function/class role comments -> run validation -> report outcomes/risks
- Large refactors are not allowed unless explicitly requested.
- When editing comment-capable source files, add or refresh a 1-2 line role/responsibility comment above the owning function/class/widget declaration (`AGENTS.md §2A`).
- Skip generated/comment-free formats and document the skip reason in the final result.

### Evidence Files
- This full document

### Risks If Ignored
- Scope creep multiplies regression points and review cost.

### Verification
- Task report must include:
- change summary
- modified files
- major diffs
- validation commands/results
- skipped role-comment files/reasons (when applicable)
- remaining risks

## 12. Assumptions & Defaults
### Rules
- `AGENTS.md` is the compressed always-on rule set, and this document is the detailed v2 reference playbook.
- The English document (`docs/AI_AGENT_PLAYBOOK.en.md`) must stay section-by-section aligned with the Korean document.
- Keep style execution-checklist oriented.
- Prefer quantitative values for performance/cache policies.
- Prefer partial section reads when possible; re-read the full document only when editing the playbook itself or checking for structural drift.

### Evidence Files
- `docs/AI_AGENT_PLAYBOOK.md`
- `docs/AI_AGENT_PLAYBOOK.en.md`

### Risks If Ignored
- Narrative drift reduces automation/verification consistency.
- KR/EN divergence creates split operational standards and wrong implementation prompts.

### Verification
- On every change, cross-check section numbers/rules/verification commands between KR and EN docs.
