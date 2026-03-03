# SOI AI Agent Playbook v2 (Execution Checklist)

이 문서는 `SOI` 프로젝트 전용 AI 개발 지침서다.  
원칙은 간단하다: 문서보다 코드가 우선이며, 모든 변경은 최소 범위로 안전하게 수행한다.

## User Context
- 사용자는 `SOI`의 Flutter 앱 개발자다.
- 사용자는 Flutter/Dart, REST API, OpenAPI, Provider 상태관리, 비동기 처리에 익숙하다.
- 사용자는 성능, 안정성, 유지보수성을 우선한다.

## Caution
- 본 문서는 `SOI` 프로젝트 전용이다.
- 최종 의사결정권자는 인간 개발자다.
- 민감정보(`.env`, 키/토큰, 개인정보)는 로그/문서에 노출하지 않는다.
- 문서와 코드가 충돌하면 코드(현재 브랜치)를 기준으로 작업한다.

## 0. Source Of Truth & Scope
### 규칙
- 현재 브랜치 코드가 단일 진실 소스다.
- 작업 전 `git branch --show-current`로 브랜치 컨텍스트를 확인한다.
- 본 문서는 운영 가이드이며, 실제 계약은 `api/openapi.yaml` + `api/generated` + `lib/api`로 검증한다.

### 근거 파일
- `lib/main.dart`
- `api/openapi.yaml`
- `api/generated/`
- `lib/api/`

### 실패 시 리스크
- 문서만 믿고 구현하면 실제 API 계약과 불일치할 수 있다.
- 이전 브랜치 가정으로 작업하면 회귀를 유발한다.

### 검증 방법
- `git branch --show-current`
- `git status --short`
- 계약 변경 시 `./.codex/skills/api-lib-sync/scripts/api_change_impact.sh <repo-root>`

## 1. Project Snapshot (폴더 구조 기준)
### 규칙
- SOI는 Flutter 클라이언트 + REST/OpenAPI 기반 구조다.
- API 생성 클라이언트(`api/generated`)와 앱 래퍼(`lib/api`)를 분리해 유지한다.
- 앱 엔트리/부트스트랩은 `lib/main.dart`를 기준으로 해석한다.
- 구조 스냅샷은 파일 개수 대신 "프로젝트 폴더 구조"로 관리한다.

### 근거 파일
- 엔트리/초기화: `lib/main.dart`
- 의존성: `pubspec.yaml`
- API 생성 패키지: `api/generated/pubspec.yaml`

### 구조(현재 프로젝트 폴더 트리)
```text
SOI/
├─ .claude/
│  └─ skills/
├─ .codex/
│  └─ skills/
├─ .github/
│  └─ appmod/
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
│  └─ dev/
├─ figma_assets/
├─ functions/
│  └─ lib/
├─ ios/
│  ├─ Flutter/
│  ├─ Runner/
│  ├─ Runner.xcodeproj/
│  ├─ Runner.xcworkspace/
│  ├─ RunnerTests/
│  ├─ SOI/
│  ├─ SOITests/
│  └─ SOIUITests/
├─ lib/
│  ├─ api/
│  │  ├─ controller/
│  │  ├─ models/
│  │  └─ services/
│  ├─ theme/
│  ├─ utils/
│  └─ views/
│     ├─ about_archiving/
│     │  ├─ models/
│     │  ├─ screens/
│     │  │  ├─ archive_detail/
│     │  │  └─ category_edit/
│     │  └─ widgets/
│     │     ├─ archive_card_widget/
│     │     ├─ category_edit_widget/
│     │     └─ wave_form_widget/
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
│     │     ├─ common/
│     │     └─ pages/
│     ├─ about_notification/
│     │  └─ widgets/
│     ├─ about_onboarding/
│     ├─ about_profile/
│     ├─ about_setting/
│     └─ common_widget/
│        ├─ about_comment/
│        ├─ about_more_menu/
│        ├─ api_photo/
│        │  └─ extension/
│        └─ report/
├─ linux/
│  ├─ flutter/
│  └─ runner/
├─ macos/
│  ├─ Flutter/
│  ├─ Runner/
│  ├─ Runner.xcodeproj/
│  ├─ Runner.xcworkspace/
│  └─ RunnerTests/
├─ public/
│  ├─ .well-known/
│  └─ assets/
├─ test/
│  ├─ api/
│  │  ├─ controller/
│  │  └─ services/
│  └─ views/
├─ web/
│  ├─ icons/
│  └─ splash/
└─ windows/
   ├─ flutter/
   └─ runner/
```

### 실패 시 리스크
- generated/client와 wrapper 책임이 섞이면 재생성 시 대량 파손이 발생한다.
- 엔트리 초기화 순서 오해 시 로그인/딥링크/캐시 동작이 깨진다.

### 검증 방법
- `git ls-tree -d --name-only HEAD | sort`
- `find lib -type d | sort`
- `find api -type d | sort`

## 2. API 연동 운영 규칙 (api-lib-sync 내재화)
### 규칙
- API 계약 변경 추적은 반드시 영향 탐지 스크립트부터 시작한다.
- 생성 코드(`api/generated/**`)는 수동 수정하지 않는다.
- OpenAPI 변경 반영은 `regen -> patch -> wrapper sync` 순서로 처리한다.
- wrapper 동기화 책임:
- generated `api/model` 변경 -> `lib/api/models/*`
- generated `api/api` 변경 -> `lib/api/services/*`
- 서비스 의미 변경 -> `lib/api/controller/*`
- 계약 체크리스트:
- 요청: 파라미터명/타입/nullable/필수 여부
- 응답: `success/data/message` envelope 및 `data` nullability
- 오류: transport failure와 business absence를 분리

### 근거 파일
- 영향 탐지 스크립트: `./.codex/skills/api-lib-sync/scripts/api_change_impact.sh`
- regen 오케스트레이션: `regen_api.sh`
- 생성 코드 패치: `api/patch_generated.sh`
- generator 설정: `api/config.yaml`
- wrapper 계층: `lib/api/models/`, `lib/api/services/`, `lib/api/controller/`

### 실패 시 리스크
- 생성 코드 직접 hotfix는 다음 regen에서 유실된다.
- 서비스/컨트롤러가 DTO 변경을 흡수하지 못하면 런타임 파싱 실패가 난다.
- `404`를 무조건 null 처리하면 네트워크 장애를 비즈니스 케이스로 오분류할 수 있다.

### 검증 방법
- 영향 탐지:
```bash
./.codex/skills/api-lib-sync/scripts/api_change_impact.sh <repo-root>
```
- 재생성:
```bash
./regen_api.sh
```
- wrapper 점검:
```bash
dart analyze lib/api/models lib/api/services lib/api/controller
```

## 3. Provider/상태관리 규칙 (현재 버전 반영)
### 규칙
- 기본 상태관리 스택은 `provider ^6.1.5 + ChangeNotifier`다.
- 전역 Provider 소유 객체는 `lib/main.dart`의 `MultiProvider`가 lifecycle owner이며, 화면에서 dispose하지 않는다.
- `UserController`는 preloaded 인스턴스를 `ChangeNotifierProvider.value`로 주입한다.
- 전역 등록 컨트롤러:
- `UserController`
- `CategoryController`, `CategorySearchController`
- `PostController`, `FeedDataManager`
- `FriendController`, `CommentController`, `MediaController`
- `NotificationController`, `ContactController`
- `AudioController`, `CommentAudioController`
- `FeedDataManager`는 전역 캐시 유지 목적이므로 화면(`feed_home`)에서는 `detachFromPostController()`만 호출한다.
- build 프레임 중 상태 갱신 충돌 가능 구간은 post-frame 스케줄링으로 처리한다(`MediaController._scheduleNotify`).
- async gap 이후 `BuildContext` 재사용은 `mounted`/가시성(`TickerMode`, `RouteAware`)을 확인한다.
- 사용자 전환 시 `FeedDataManager._lastUserId` 비교 후 `reset(notify: false)` + `forceRefresh`를 적용한다.

### 근거 파일
- Provider 등록/앱 루트: `lib/main.dart`
- 전역 피드 캐시 소유권: `lib/views/about_feed/feed_home.dart`
- 사용자 전환 리셋/지연 갱신: `lib/views/about_feed/manager/feed_data_manager.dart`
- 프레임 충돌 완화 notify 패턴: `lib/api/controller/media_controller.dart`
- 의존성 버전: `pubspec.yaml`

### 실패 시 리스크
- 전역 객체를 화면에서 dispose하면 `disposed object` 오류 또는 캐시 유실이 발생한다.
- 가시성/라이프사이클 무시 시 숨겨진 탭에서 중복 로딩 또는 stale UI가 발생한다.
- 사용자 전환 시 이전 사용자 피드/카테고리 캐시가 노출될 수 있다.

### 검증 방법
- `rg -n "ChangeNotifierProvider|FeedDataManager|ChangeNotifierProvider<UserController>\.value" lib/main.dart`
- `rg -n "detachFromPostController|reset\(|_lastUserId|TickerMode|mounted" lib/views/about_feed/manager/feed_data_manager.dart lib/views/about_feed/feed_home.dart`
- `rg -n "_scheduleNotify|addPostFrameCallback" lib/api/controller/media_controller.dart`

## 4. 미디어 성능 가드레일 (정량 기준 재검증)
### 규칙
- 앱 이미지 캐시 한도:
- debug: `maximumSize=50`, `maximumSizeBytes=50MB`
- release: `maximumSize=30`, `maximumSizeBytes=30MB`
- 이미지 업로드는 `_maxImageSizeBytes=1MB` 기준으로 점진 압축한다.
- 이미지 점진 압축 파라미터: quality `85 -> 40`(step 10), dimension `2200 -> 960`(scale 0.85), fallback `quality=35`, `dimension=1024`.
- 비디오는 `_maxVideoSizeBytes=50MB` 기준이며 `1.5Mbps -> 1.0Mbps -> 0.8Mbps -> MediumQuality` 순으로 압축 시도한다.
- 카메라 비디오 녹화 기본 최대 길이는 `30초`다.
- 비디오 썸네일은 `Memory -> Disk -> Generate` 3-tier 캐시를 사용한다.
- 3-tier 메모리 캐시는 `maxEntries=120`, `maxBytes=12MB` LRU를 유지한다.
- 아카이브 그리드 썸네일 프리페칭은 초기 버스트 방지를 위해 최대 4개 비디오까지만 선행한다.
- 비디오 자동 재생은 노출 비율 `>= 0.6`에서만 재생하고, 미만이면 일시정지한다.
- URL 회전(presigned 재발급) 시 이미지 깜빡임 방지를 위해 `cacheKey=postFileKey`, `useOldImageOnUrlChange=true`를 유지한다.
- dispose 시 전역 `imageCache.clear()`는 금지하고, 현재 항목만 `evict`한다.
- 대용량 payload 로그는 `kDebugMode` 가드 하에서만 허용한다.

### 근거 파일
- 이미지 캐시 설정: `lib/main.dart`
- 이미지/비디오 압축 상수: `lib/views/about_camera/services/photo_editor_media_processing_service.dart`
- 업로드 파이프라인/캐시 evict: `lib/views/about_camera/photo_editor_screen.dart`, `lib/views/about_camera/photo_editor_screen_upload.dart`
- 카메라 녹화 기본 길이: `lib/api/services/camera_service.dart`
- 3-tier 썸네일 캐시: `lib/utils/video_thumbnail_cache.dart`
- 비디오 노출 임계값/이미지 깜빡임 완화: `lib/views/common_widget/api_photo/extension/api_photo_display_widget_media.dart`
- 아카이브 썸네일 프리페치 상한: `lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart`

### 실패 시 리스크
- 캐시 과다/과소 설정 시 메모리 압박 또는 재디코딩 비용 증가가 발생한다.
- 압축 규칙 미준수 시 업로드 실패(413) 또는 프레임 드랍이 발생한다.
- visibility/lifecycle 제어 누락 시 백그라운드 재생으로 배터리·CPU가 증가한다.
- URL 회전 시 캐시 키 규칙을 깨면 쉬머/깜빡임 회귀가 발생한다.

### 검증 방법
- `rg -n "maximumSize|maximumSizeBytes" lib/main.dart`
- `rg -n "_maxImageSizeBytes|_maxVideoSizeBytes|_initialCompressionQuality|_fallbackCompressionQuality" lib/views/about_camera/services/photo_editor_media_processing_service.dart`
- `rg -n "visibleFraction >= 0.6|cacheKey: widget.post.postFileKey|useOldImageOnUrlChange" lib/views/common_widget/api_photo/extension/api_photo_display_widget_media.dart`
- `rg -n "_maxEntries|_maxBytes|take\(4\)" lib/utils/video_thumbnail_cache.dart lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart`

## 5. 캐싱 전략 매트릭스 (현재 코드 반영)
### 규칙
- 캐시는 소유자 단위로 key/TTL/무효화/폴백을 명시적으로 관리한다.
- 사용자 전환 이벤트와 TTL 만료 이벤트를 분리해 처리한다.
- stale-while-revalidate가 적용된 경로는 즉시 표시 캐시와 백그라운드 갱신 트리거를 함께 기록한다.

### 근거 파일
- `lib/views/about_feed/manager/feed_data_manager.dart`
- `lib/api/controller/post_controller.dart`
- `lib/api/controller/category_controller.dart`
- `lib/api/controller/notification_controller.dart`
- `lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart`
- `lib/api/controller/media_controller.dart`
- `lib/utils/video_thumbnail_cache.dart`
- `lib/api/services/camera_service.dart`

### 캐싱 매트릭스
| 소유자 | Key | TTL/한도 | 무효화 트리거 | 폴백 동작 | 근거 파일 |
|---|---|---|---|---|---|
| `FeedDataManager` | `_allPosts` + `_lastUserId` | 명시 TTL 없음(세션 캐시) | 사용자 전환(`_lastUserId` 변경), `reset()`, posts-changed 강제 새로고침 | `forceRefresh=false`이면 기존 목록 즉시 재사용 | `lib/views/about_feed/manager/feed_data_manager.dart` |
| `PostController` | `"$userId:$categoryId:$page"` | `1h` | `notifyPostsChanged()`, `clearAllCache()`, `invalidateCategoryCache()` | 에러 시 만료 캐시라도 반환 | `lib/api/controller/post_controller.dart` |
| `CategoryController` | `CategoryFilter`별 맵 + `_lastLoadedUserId` | `30s` | `invalidateCache()`, 사용자 변경, `forceReload=true` | 캐시 유효 시 API 생략 | `lib/api/controller/category_controller.dart` |
| `NotificationController` 전체 | `_cachedResult` + `_lastLoadedUserId` | `30s` | `invalidateCache()`, `refreshNotifications()` | 유효 캐시 즉시 반환 | `lib/api/controller/notification_controller.dart` |
| `NotificationController` 친구목록 | `_cachedFriendNotifications` | 명시 TTL 없음(최근 호출 결과) | `invalidateCache()`, 재조회 | 미스 시 API 호출 | `lib/api/controller/notification_controller.dart` |
| 아카이브 카테고리 포스트 | `"$userId:$categoryId"` | `30m` | `forceRefresh`, posts-changed, 캐시 키 제거 | 만료 캐시 표시 후 백그라운드 갱신 | `lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart` |
| `MediaController` presigned | `fileKey` | `55m` | 만료 시 제거 후 재요청 | in-flight 요청 공유(dedupe) | `lib/api/controller/media_controller.dart` |
| `MediaController` 비디오 썸네일 매핑 | `videoKey -> thumbnailKey` | LRU `100` | 초과 시 oldest 제거, `clearVideoThumbnailCache()` | 미스 시 생성/업로드 경로 사용 | `lib/api/controller/media_controller.dart` |
| `VideoThumbnailCache` | stable key(`postFileKey` 우선) | 메모리 LRU `120`, `12MB` + 디스크 캐시 | `clearMemory()`, 프로세스/임시파일 정리 | Memory miss -> Disk -> Generate | `lib/utils/video_thumbnail_cache.dart` |
| `CameraService` 갤러리 첫 이미지 | `_cachedFirstGalleryImage` | `5s` | 사진/비디오 촬영 후 `_invalidateGalleryCache()` | 미스 시 갤러리 재조회 | `lib/api/services/camera_service.dart` |
| `CameraService` 권한 상태 | `_cachedPermissionState` | `10s` | 만료, 접근권한 없음, 권한 상태 변화 | 미스 시 `requestPermissionExtend()` | `lib/api/services/camera_service.dart` |

### 실패 시 리스크
- 만료 정책 누락 시 오래된 데이터 노출이 지속된다.
- 사용자 전환 무효화 누락 시 사용자 간 데이터 오염이 발생한다.
- fallback 정책 부재 시 일시 네트워크 장애에서 UX가 급격히 악화된다.

### 검증 방법
- `rg -n "_cache|cache|Duration\(|invalidate|clear|forceRefresh" lib/views/about_feed/manager/feed_data_manager.dart lib/api/controller/post_controller.dart lib/api/controller/category_controller.dart lib/api/controller/notification_controller.dart lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart lib/api/controller/media_controller.dart lib/utils/video_thumbnail_cache.dart lib/api/services/camera_service.dart`

## 6. 에러/예외 처리 규칙
### 규칙
- 서비스 레이어는 `SoiApiException` 계층(`BadRequest/Auth/Forbidden/NotFound/Server/Network`)으로 변환한다.
- transport 실패와 business 실패를 반드시 구분한다.
- `404 => null`은 명시 허용된 로그인 신규회원 시나리오에서만 사용한다.
- `getUser`, `getPostDetail` 등 조회 핵심 경로는 `NotFoundException` 또는 명시 에러로 처리한다.

### 근거 파일
- 예외 계층 정의: `lib/api/api_exception.dart`
- 사용자 서비스 transport 분류: `lib/api/services/user_service.dart`
- 서비스별 예외 매핑: `lib/api/services/*.dart`

### 실패 시 리스크
- transport 오류를 `null`로 오분류하면 UI가 잘못된 분기(신규 사용자 등)를 실행한다.
- 예외 계층이 흐트러지면 화면별 오류 메시지 정책이 일관성을 잃는다.

### 검증 방법
- `rg -n "_handleApiException|NetworkException|NotFoundException" lib/api/services`
- 최소 테스트:
```bash
flutter test test/api/services/user_service_test.dart test/api/controller/user_controller_test.dart
```

## 7. 로컬라이제이션 정책 (en 활성 locale 포함)
### 규칙
- 활성 locale 정책 기준은 `ko`, `es`, `en`이다.
- locale 정책/부트스트랩 변경 시 `lib/main.dart`의 `supportedLocales`에 `Locale('en')`을 포함한다.
- `fallbackLocale`은 `ko`를 유지하고, `startLocale`은 `es/en` 기기 언어를 우선 매핑한다.
- 사용자 노출 문자열 변경 시 `ko/es/en` 3개 번역 키를 동시에 반영한다.
- `ja/zh`는 보조 번역으로 유지하되, 활성 locale 정책과 분리 관리한다.
- 키 네임스페이스는 기존 패턴(`common.*`, `camera.editor.*`)을 유지한다.

### 근거 파일
- 로케일 부트스트랩: `lib/main.dart`
- 번역 파일: `assets/translations/ko.json`, `assets/translations/es.json`, `assets/translations/en.json`, `assets/translations/ja.json`, `assets/translations/zh.json`

### 실패 시 리스크
- `en.json`이 있어도 `supportedLocales`에 빠지면 영어 UI가 노출되지 않는다.
- 활성 locale 정책과 번역 파일 정책이 불일치하면 릴리즈 직전에 누락이 발견된다.
- 하드코딩 문자열 증가로 다국어 회귀 비용이 커진다.

### 검증 방법
- `ls -1 assets/translations`
- `rg -n "supportedLocales|fallbackLocale|startLocale|Locale\('en'\)" lib/main.dart`
- 수동 검증: 기기 언어 `en` 설정 후 앱 시작 시 영어 로케일 선택 여부 확인

## 8. 고위험 파일 및 점검 시나리오 (현 프로젝트 상세 분석)
### 규칙
- 아래 파일 수정 시 반드시 영향 분석 + 최소 검증 명령을 함께 수행한다.
- 고위험 변경은 "무엇이 깨질 수 있는지"를 먼저 문서화하고 시작한다.

### 고위험 파일 매트릭스
| 파일 | 위험 포인트 | 필수 체크포인트 |
|---|---|---|
| `lib/main.dart` | 앱 부트스트랩 순서, 전역 Provider 생명주기, 딥링크 처리 | `EasyLocalization` locale 목록, `_configureImageCache`, `SoiApiClient.initialize()`, URI 중복 방지(3초), route 등록 |
| `lib/views/about_feed/manager/feed_data_manager.dart` + `lib/views/about_feed/feed_home.dart` | 전역 피드 캐시 소유권/사용자 전환/탭 가시성 | `detachFromPostController`만 호출, `_lastUserId` 전환 리셋, `_pendingPostRefresh` 복귀 갱신 |
| `lib/views/about_camera/photo_editor_screen.dart` + `photo_editor_screen_upload.dart` + `services/photo_editor_media_processing_service.dart` | 백그라운드 업로드 파이프라인, 압축 수치, 임시파일/캐시 정리 | 1MB/50MB 가드, 업로드 후 `VideoCompress.deleteAllCache()`, `_evictCurrentImageFromCache`, 실패 시 원본 fallback |
| `lib/views/common_widget/api_photo/api_photo_display_widget.dart` + `extension/api_photo_display_widget_media.dart` + `extension/api_photo_display_widget_video.dart` | 비디오 lifecycle/가시성 기반 재생, 이미지 깜빡임 회귀 | `visibleFraction >= 0.6`, lifecycle pause, `cacheKey + useOldImageOnUrlChange` |
| `lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart` | stale 캐시 표시 + 백그라운드 페이징 동시성 | `_cacheTtl=30m`, `allowExpired` 동작, `generation` 가드, posts-changed 캐시 제거 |
| `lib/api/controller/media_controller.dart` + `lib/utils/video_thumbnail_cache.dart` | presigned URL 캐시 만료/중복요청/썸네일 LRU | presigned `55m`, in-flight dedupe, thumbnail LRU(100), 3-tier 캐시 상한 |
| `lib/api/services/post_service.dart` + `comment_service.dart` + `user_service.dart` | DTO/enum/nullability 매핑 및 예외 분류 | `postType/commentType` 매핑, `404` 처리 정책, `SocketException -> NetworkException` |
| `lib/api/models/post.dart` + `comment.dart` + `notification.dart` | generated DTO ↔ 도메인 모델 필드/enum 동기화 | `PostType`, `CommentType`, `AppNotificationType`, `savedAspectRatio/isFromGallery/parentId/replyUserId/fileKey` |

### 점검 시나리오
- 딥링크가 같은 URI로 연속 유입될 때 3초 내 중복 처리 방지 동작 확인.
- 로그인 사용자를 전환했을 때 피드/카테고리 캐시가 섞이지 않고 강제 재조회되는지 확인.
- 숨김 탭에서 posts-changed가 발생한 뒤 탭 복귀 시 1회만 새로고침되는지 확인.
- 50MB 초과 비디오 업로드 시 단계 압축 후 업로드/카테고리 커버 업데이트까지 완료되는지 확인.
- 비디오 셀의 노출 비율이 0.6 미만으로 내려가면 즉시 pause되는지 확인.
- 아카이브 진입 시 만료 캐시 즉시 표시 후 백그라운드 갱신으로 리스트가 교체되는지 확인.
- presigned URL 재발급 후에도 동일 `postFileKey`에서는 이미지 깜빡임이 없는지 확인.
- 댓글 타입(`PHOTO/REPLY`) 및 알림 타입(`COMMENT_REPLY_ADDED`)이 UI 분기에서 정상 처리되는지 확인.

### 검증 방법
- `rg -n "_cacheTtl|allowExpired|generation|visibleFraction >= 0.6|cacheKey: widget.post.postFileKey|_lastUserId|_pendingPostRefresh" lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart lib/views/common_widget/api_photo/extension/api_photo_display_widget_media.dart lib/views/about_feed/manager/feed_data_manager.dart`

## 9. 테스트/검증 섹션 (현행 테스트셋 반영)
### 규칙
- 문서/코드 변경 시 최소 검증 명령을 항상 실행한다.
- API/인터페이스/타입 변경 시 서비스+컨트롤러 단위 테스트를 함께 실행한다.
- 미디어/캐시/로컬라이제이션 변경은 수동 회귀 시나리오를 명시적으로 점검한다.

### 근거 파일
- 서비스 테스트:
- `test/api/services/user_service_test.dart`
- `test/api/services/post_service_test.dart`
- `test/api/services/comment_service_test.dart`
- 컨트롤러 테스트:
- `test/api/controller/user_controller_test.dart`
- `test/api/controller/post_controller_test.dart`
- `test/api/controller/comment_controller_test.dart`
- 핵심 변경 파일:
- `lib/main.dart`
- `lib/api/models/*.dart`
- `lib/api/services/*.dart`
- `lib/views/about_camera/**`
- `lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart`

### 실패 시 리스크
- enum/필드 확장 누락을 배포 후 발견할 수 있다.
- presigned URL/캐시 키 변경 시 이미지 깜빡임 회귀가 재발할 수 있다.
- 사용자 전환/캐시 만료 회귀가 피드·아카이브 UX를 악화시킨다.

### 검증 방법
- 자동 테스트:
```bash
flutter test \
  test/api/services/user_service_test.dart \
  test/api/services/post_service_test.dart \
  test/api/services/comment_service_test.dart \
  test/api/controller/user_controller_test.dart \
  test/api/controller/post_controller_test.dart \
  test/api/controller/comment_controller_test.dart
```
- 정적 분석:
```bash
dart analyze lib/main.dart lib/api lib/views/about_feed lib/views/about_camera lib/views/about_archiving
```
- 변경 포인트 grep:
```bash
rg -n "TEXT_ONLY|MULTIMEDIA|PHOTO|REPLY|COMMENT_REPLY_ADDED|savedAspectRatio|isFromGallery" lib/api
rg -n "supportedLocales|Locale\('en'\)|visibleFraction >= 0.6|cacheKey: widget.post.postFileKey" lib/main.dart lib/views/common_widget/api_photo/extension/api_photo_display_widget_media.dart
```
- 수동 회귀:
- 사용자 전환 후 피드/카테고리 분리 확인
- 대용량 비디오 업로드 및 썸네일 생성/캐시 확인
- 영어(`en`) 기기 언어에서 로케일 선택/문구 노출 확인

## 10. 공용 API/인터페이스/타입 변경 대응 규칙 (현행 계약 반영)
### 규칙
- 생성 DTO 변경을 감지하면 앱 도메인 타입과 서비스 파라미터를 동시에 갱신한다.
- 생성 코드(`api/generated/**`)는 수정하지 않고 wrapper(`lib/api/**`)에서 흡수한다.
- 변경 처리 순서:
- `api/openapi.yaml` 변경 확인
- `./regen_api.sh` + `api/patch_generated.sh` 적용
- `lib/api/models` 매핑 업데이트
- `lib/api/services` 요청/응답/예외 변환 업데이트
- `lib/api/controller` 편의 메서드/기본값/타입 추론 업데이트
- 테스트 갱신
- 현재 계약 핵심 타입/필드(회귀 우선순위 상):
- `CommentReqDto`: `parentId`, `replyUserId`, `fileKey`, `commentType(EMOJI/TEXT/AUDIO/PHOTO/REPLY)`
- `CommentRespDto`: `replyUserName`, `userProfileKey`, `fileKey`, `waveFormData`, `commentType`
- `NotificationRespDto`: `type(COMMENT_REPLY_ADDED 포함)`, `relatedId`, `categoryIdForPost`, `categoryInvitedUsers`
- `PostCreateReqDto`/`PostUpdateReqDto`: `savedAspectRatio`, `isFromGallery`, `postType(TEXT_ONLY/MULTIMEDIA)`
- `PostRespDto`: `savedAspectRatio`, `isFromGallery`, `postType`, `is_active`
- 도메인 enum/모델 매핑은 다음 파일에서 단일 진실 소스로 관리한다:
- `lib/api/models/comment.dart`
- `lib/api/models/notification.dart`
- `lib/api/models/post.dart`

### 근거 파일
- generated 모델:
- `api/generated/lib/model/comment_req_dto.dart`
- `api/generated/lib/model/comment_resp_dto.dart`
- `api/generated/lib/model/notification_resp_dto.dart`
- `api/generated/lib/model/post_create_req_dto.dart`
- `api/generated/lib/model/post_resp_dto.dart`
- `api/generated/lib/model/post_update_req_dto.dart`
- wrapper 반영:
- `lib/api/models/comment.dart`
- `lib/api/models/notification.dart`
- `lib/api/models/post.dart`
- `lib/api/services/comment_service.dart`
- `lib/api/services/post_service.dart`
- `lib/api/controller/comment_controller.dart`
- 관련 테스트:
- `test/api/services/comment_service_test.dart`
- `test/api/services/post_service_test.dart`
- `test/api/controller/comment_controller_test.dart`
- `test/api/controller/post_controller_test.dart`

### 실패 시 리스크
- 서버는 새 필드를 주는데 앱이 무시하면 기능 일부가 silent-fail 된다.
- enum 신규값 미반영 시 파싱/표시 로직이 기본값으로 잘못 분기할 수 있다.
- 요청 DTO 기본값 정책이 어긋나면 서버 유효성 검사에서 4xx가 증가한다.

### 검증 방법
- `./.codex/skills/api-lib-sync/scripts/api_change_impact.sh <repo-root>`
- `rg -n "PHOTO|REPLY|COMMENT_REPLY_ADDED|TEXT_ONLY|MULTIMEDIA|savedAspectRatio|isFromGallery|parentId|replyUserId|fileKey|is_active" lib/api api/generated/lib/model`
- `flutter test test/api/services/comment_service_test.dart test/api/services/post_service_test.dart test/api/controller/comment_controller_test.dart test/api/controller/post_controller_test.dart`

## 11. 작업 절차(Agent Workflow)
### 규칙
- 모든 작업은 아래 순서를 따른다.
- 목표/범위 재확인 -> 영향 파일 탐색 -> 최소 변경 구현 -> 검증 실행 -> 결과/리스크 보고
- 대규모 리팩터링은 사용자 명시 요청이 없으면 금지한다.

### 근거 파일
- 본 문서 전체

### 실패 시 리스크
- 범위가 커지면 회귀 지점이 폭증하고 리뷰 비용이 급증한다.

### 검증 방법
- 작업 보고 시 아래 항목을 포함한다.
- 변경 요약
- 수정 파일 목록
- 주요 변경점
- 실행한 검증 명령과 결과
- 남은 리스크

## 12. 가정 및 기본값
### 규칙
- 본 v2 문서는 `docs/AI_AGENT_PLAYBOOK.md` 단일 파일 기준으로 유지한다.
- 영어 문서(`docs/AI_AGENT_PLAYBOOK.en.md`)는 섹션 번호/규칙을 한국어 문서와 동기화한다.
- 문체는 실행 체크리스트 중심으로 유지한다.
- 성능/캐싱 정책은 정량 수치를 우선 반영한다.

### 근거 파일
- `docs/AI_AGENT_PLAYBOOK.md`
- `docs/AI_AGENT_PLAYBOOK.en.md`

### 실패 시 리스크
- 문서가 다시 서술형으로 퍼지면 자동화/검증 일관성이 떨어진다.
- 한/영 문서가 어긋나면 운영 기준이 분리되어 잘못된 구현 지시를 만들 수 있다.

### 검증 방법
- 변경 시 본 문서와 영어 문서의 섹션 번호/규칙/검증 명령을 교차검증한다.

<!-- codex-autoload-test-marker: 2026-03-03T00:00:00Z -->
