# SOI AGENTS (Always-On Rules for Codex)

이 파일은 SOI 작업에서 Codex가 항상 적용해야 하는 최소 강제 규칙이다.
상세 설명은 `docs/AI_AGENT_PLAYBOOK.md`, `docs/AI_AGENT_PLAYBOOK.en.md`에 두고,
일반 작업에서는 이 파일을 기본 규칙으로 사용한다.

## 0. Token 절약 운영 정책
- 기본값: 매 요청마다 플레이북 전체를 다시 읽지 않는다.
- 우선순위: `AGENTS.md` -> 필요한 코드 파일 -> 필요한 경우에만 플레이북 특정 섹션 부분 조회.
- 플레이북 부분 조회가 필요한 경우:
  - OpenAPI/DTO 계약 변경
  - 미디어 압축/캐시/성능 튜닝
  - 로컬라이제이션 정책 변경
  - 배포 전 고위험 점검 시나리오 점검
- 문서와 코드가 충돌하면 현재 브랜치 코드를 따른다.

## 1. Source of Truth
- 단일 진실 소스: 현재 브랜치 코드.
- 작업 시작 전 반드시 확인:
  - `git branch --show-current`
  - `git status --short`
- 민감정보(`.env`, 키/토큰, 개인정보)를 로그/문서에 남기지 않는다.

## 2. 기본 작업 순서
- 목표/범위를 1-3줄로 명확화.
- 영향 파일만 탐색.
- 최소 변경으로 구현.
- 관련 검증 명령 실행.
- 결과 보고(변경 파일, 검증 결과, 잔여 리스크).

## 3. 아키텍처 경계 (항상 준수)
- `api/generated/**`는 생성 코드이므로 수동 수정 금지.
- 책임 분리:
  - `lib/app`: 앱 부트스트랩, 전역 Provider 조립, 라우트/로케일/레이아웃 상수
  - `lib/api/models`: 도메인 모델/매핑
  - `lib/api/services`: API 호출/DTO/예외 변환
  - `lib/api/controller`: UI 상태/흐름 오케스트레이션
  - `lib/utils`: 공용 유틸/캐시 인프라
  - `lib/views`: 화면/UI
- API 계약 변경 처리 순서:
  1. 영향 탐지: `./.codex/skills/api-lib-sync/scripts/api_change_impact.sh <repo-root>`
  2. regen: `./regen_api.sh`
  3. patch: `api/patch_generated.sh`
  4. wrapper 동기화(`lib/api/models`, `lib/api/services`, `lib/api/controller`)
  5. 테스트/분석

## 4. Provider/상태관리 강제 규칙
- 전역 Provider 소유 객체는 앱 루트(`lib/main.dart` + `lib/app/app_providers.dart`)가 lifecycle owner다.
- 화면에서 전역 컨트롤러 dispose 금지.
- `FeedDataManager`는 전역 캐시 owner:
  - 화면(`feed_home`)에서는 `detachFromPostController()`만 호출.
- async gap 이후 context 재사용 시 `mounted`/가시성(`TickerMode`, `RouteAware`) 확인.
- 사용자 전환 시 캐시 분리:
  - `FeedDataManager._lastUserId` 변경 감지 후 `reset(notify: false)` + `forceRefresh`.

## 5. 미디어 성능 가드레일 (정량)
- 앱 이미지 캐시:
  - debug: `maximumSize=50`, `maximumSizeBytes=50MB`
  - release: `maximumSize=30`, `maximumSizeBytes=30MB`
- 업로드 압축 기준:
  - 이미지: 목표 `<= 1MB`
  - 비디오: 기준 `<= 50MB`
- 비디오 자동재생 임계값: 가시성 `>= 0.6`에서만 재생.
- 썸네일 캐시:
  - `VideoThumbnailCache`: Memory -> Disk -> Generate (메모리 LRU `120`개, `12MB`)
  - `MediaController` 비디오 썸네일 key 매핑 LRU: `100`개
- 금지:
  - dispose 시 전역 `imageCache.clear()` 호출 금지 (현재 항목 evict만 허용)
- 대용량 로그는 `kDebugMode`에서만 허용.

## 6. 캐싱 핵심 규칙 (요약)
- `PostController`: key `userId:categoryId:page`, TTL `1h`, 에러 시 stale fallback 허용.
- `CategoryController`: TTL `30s`, user/filter 기준 캐시.
- `NotificationController`: TTL `30s`(전체 알림), 친구 알림은 최근 결과 캐시.
- 아카이브 카테고리 포스트: TTL `30m`, stale-while-revalidate.
- `MediaController` presigned URL: TTL `55m`, in-flight dedupe.
- `CameraService`: 갤러리 첫 이미지 `5s`, 권한 상태 `10s` 캐시.
- 사용자 전환 이벤트와 TTL 만료 이벤트를 분리 처리한다.

## 7. 로컬라이제이션 정책 (Always-Known)
- 활성 locale 정책 기준: `ko`, `es`.
- locale 부트스트랩 소스는 `lib/app/app_constants.dart`의 `supportedLocales`이며, `lib/main.dart`에서 소비한다.
- `fallbackLocale`은 `ko`를 유지하고, `startLocale`은 기기 언어가 `es`일 때만 `es`, 그 외는 `ko`다.
- 사용자 노출 문자열 변경 시 `ko/es` 동시 반영.
- `en/ja/zh` 번역 파일은 현재 비활성 보조 자산이다. 관련 키를 건드리면 함께 동기화하거나, 제외 이유를 결과에 명시한다.
- 키 네임스페이스 유지: `common.*`, `camera.editor.*` 등 기존 패턴.
- `Text`/`RichText` 등 사용자 노출 문자열을 새로 만들거나 변경할 때 하드코딩 금지, 반드시 로컬라이제이션 키(`tr()`)를 사용한다.
- 로컬라이즈 키를 추가/수정한 경우 `ko/es` 리소스를 같은 턴에서 함께 갱신한다.

## 8. 고위험 파일 (수정 시 강화 점검)
- `lib/main.dart`
- `lib/app/app_constants.dart`
- `lib/app/app_container_builder.dart`
- `lib/app/app_providers.dart`
- `lib/app/app_routes.dart`
- `lib/views/about_feed/manager/feed_data_manager.dart`
- `lib/views/about_feed/feed_home.dart`
- `lib/views/about_camera/photo_editor_screen.dart`
- `lib/views/about_camera/photo_editor_screen_upload.dart`
- `lib/views/about_camera/services/photo_editor_media_processing_service.dart`
- `lib/views/common_widget/api_photo/api_photo_display_widget.dart`
- `lib/views/common_widget/api_photo/extension/api_photo_display_widget_media.dart`
- `lib/views/about_archiving/screens/archive_detail/api_category_photos_screen.dart`
- `lib/api/services/*.dart`, `lib/api/models/*.dart`, `lib/api/controller/media_controller.dart`

고위험 파일 변경 시 필수:
- 무엇이 깨질 수 있는지 먼저 명시
- 최소 검증 명령 실행
- 미검증 리스크를 결과에 명시

## 9. API/인터페이스/타입 변경 체크리스트
- generated DTO 변경 감지 시, 도메인 모델/서비스/컨트롤러를 동시에 갱신.
- 회귀 우선 타입/필드:
  - Comment: `PHOTO`, `REPLY`, `parentId`, `replyUserId`, `fileKey`
  - Notification: `COMMENT_REPLY_ADDED`, `relatedId`, `categoryIdForPost`
  - Post: `TEXT_ONLY`, `MULTIMEDIA`, `savedAspectRatio`, `isFromGallery`, `postType`
- 요청/응답 nullability와 enum 매핑 누락 방지.

## 10. 최소 검증 명령 (기본 세트)
```bash
flutter test \
  test/api/services/user_service_test.dart \
  test/api/services/post_service_test.dart \
  test/api/services/comment_service_test.dart \
  test/api/services/notification_service_test.dart \
  test/api/controller/user_controller_test.dart \
  test/api/controller/post_controller_test.dart \
  test/api/controller/comment_controller_test.dart

dart analyze lib/main.dart lib/app lib/api lib/views/about_feed lib/views/about_camera lib/views/about_archiving lib/views/common_widget
```

필요 시 추가 점검:
```bash
flutter test \
  test/api/models/comment_post_model_test.dart \
  test/views/about_feed/manager/feed_data_manager_test.dart \
  test/views/common_widget/api_photo/api_photo_tag_overlay_test.dart

rg -n "TEXT_ONLY|MULTIMEDIA|PHOTO|REPLY|COMMENT_REPLY_ADDED|savedAspectRatio|isFromGallery" lib/api
rg -n "supportedLocales|koreanLocale|spanishLocale|buildAppProviders|buildAppRoutes|buildAppContainer" lib/main.dart lib/app
rg -n "visibleFraction >= 0.6|cacheKey: widget.post.postFileKey" lib/views/common_widget/api_photo/extension/api_photo_display_widget_media.dart
```

## 11. 상세 문서 참조 위치
- 한국어 상세: `docs/AI_AGENT_PLAYBOOK.md`
- 영어 상세: `docs/AI_AGENT_PLAYBOOK.en.md`

## 12. 작업 시작 전 체크리스트
모든 구현/분석 작업 전 아래 항목을 순서대로 확인한다:
1. 현재 브랜치(`git branch --show-current`)와 변경 상태(`git status --short`) 확인.
2. 작업 목표를 1-3줄로 명확화.
3. 고위험 파일(§8) 해당 여부 확인 → 해당 시 무엇이 깨질 수 있는지 먼저 명시.
4. API 계약 변경 포함 여부 확인 → 포함 시 §3 처리 순서 따름.
5. 사용자 노출 문자열 변경 포함 여부 확인 → 포함 시 §7 로컬라이제이션 정책 따름.
6. 최소 변경으로 구현 후 §10 검증 명령 실행.

## 13. 앱 초기화 순서 (Boot Sequence)
`main()`의 초기화는 의존 순서가 있으므로 변경 시 주의:
1. `WidgetsFlutterBinding` + `EasyLocalization.ensureInitialized()`
2. `SharedPreferences` 로드 → 런치 비디오 표시 여부 결정
3. `.env` 로드 → `SoiApiClient.instance.initialize()`
4. `Firebase.initializeApp()` + FCM background handler 등록 (`supportsFirebaseMessaging` 조건부 — web/linux 제외)
5. `KakaoSdk.init()` → `AnalyticsService.create()` (Mixpanel)
6. `UserController().tryAutoLogin()` → 성공 시 `refreshCurrentUser()`
7. `FlutterNativeSplash.remove()` → `runApp()` → `buildAppProviders()` → `buildAppContainer()` → `buildAppRoutes()`
8. `_MyAppState.initState()` → `AppPushCoordinator.initialize()` (navigatorKey 전달)

규칙:
- 3번과 4번 사이에 Firebase 없이 API 호출이 가능한 이유: `SoiApiClient`는 Supabase 기반이며 Firebase 독립적.
- `FlutterNativeSplash`: `hasSeenLaunchVideo=true`면 auto-login 완료까지 스플래시 유지 후 제거.

## 14. 코드 분리 패턴
**Extension 파일 패턴**: 대형 화면은 `extension/` 디렉토리에 기능별로 분리.
- 예: `photo_editor_screen.dart` ← `extension/photo_editor_screen_view.dart` / `_init.dart` / `_upload_flow.dart` / `_category_flow.dart` / `_helpers.dart`
- 화면 수정 시 반드시 관련 `extension/` 파일 전체 확인 후 작업.

**카메라 서비스 두 계층** (혼용 금지):
- `lib/api/services/camera_service.dart` → 갤러리 접근/권한 (캐시: 갤러리 첫 이미지 5s, 권한 상태 10s)
- `lib/views/about_camera/services/` → 뷰 레이어 서비스 (업로드/미디어 처리)

**buildAppContainer** (`lib/app/app_container_builder.dart`):
- 전역 레이아웃 래퍼. textScaler 클램핑(`textScaleMin`/`textScaleMax`) + wide layout 대응.
- breakpoint/maxWidth 상수는 `AppConstant` 참조.

## 15. 싱글턴/전역 키 레퍼런스
| 심볼 | 위치 | 역할 |
|---|---|---|
| `SoiApiClient.instance` | `lib/api/api_client.dart` | OpenAPI 클라이언트 싱글턴. 직접 생성 금지. |
| `AppPushCoordinator.instance` | `lib/app/push/app_push_coordinator.dart` | FCM 코디네이터. `_MyAppState`가 초기화, `UserController` 리스너로 인증 상태 동기화. |
| `HomePageNavigationBar.rootKey` | `lib/views/home_navigator_screen.dart` | 탭 프로그래밍 전환용 GlobalKey. `AppRoute.homeNavigation`의 루트 키. |
| `AppRoute` | `lib/app/app_constants.dart` | Named route 상수 클래스. |
| `AppConstant` | `lib/app/app_constants.dart` | 이미지 캐시 크기, 텍스트 스케일, 딥링크 상수 등 정량 상수. |
| `appRouteObserver` | `lib/utils/app_route_observer.dart` | `MaterialApp.navigatorObservers`에 등록된 라우트 옵저버. |

이 파일은 "항상 적용되는 압축 규칙"이며, 상세 정책은 위 문서의 해당 섹션만 필요한 만큼 조회한다.
