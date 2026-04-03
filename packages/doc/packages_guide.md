# Packages Guide

이 문서는 `packages/` 폴더가 무엇을 위한 공간인지, 각 하위 폴더가 어떤 역할을 맡는지, 그리고 메인 앱이 패키지와 어떻게 소통하는지를 쉽게 설명하는 안내서입니다.

대학생이 처음 팀 프로젝트 구조를 읽는다는 기준으로, "이 폴더는 왜 있는가?", "어디를 먼저 보면 되는가?", "앱과 어떤 식으로 연결되는가?"를 중심으로 정리했습니다.

## 1. 한눈에 보기

`packages/`는 메인 앱에서 떼어내어 관리하는 별도 단위들을 모아 둔 공간입니다.

- 메인 앱 `lib/`:
  화면, 상태관리, 라우팅, 앱 전체 흐름을 담당
- `packages/`:
  메인 앱이 재사용하거나 분리해서 관리하고 싶은 기능 묶음을 담당

쉽게 비유하면:

- `lib/`는 "본관"
- `packages/`는 "별관"
- 각 패키지는 "특정 기능만 맡는 전문 연구실"에 가깝습니다

## 2. 현재 폴더 구조

현재 `packages/` 아래 구조는 다음과 같습니다.

```text
packages/
├─ build/
│  └─ ios/
│     └─ XCBuildData/
├─ doc/
└─ soi_media_native/
   ├─ hook/
   ├─ lib/
   ├─ src/
   ├─ test/
   ├─ third_party/
   ├─ pubspec.yaml
   ├─ ffigen.yaml
   └─ README.md
```

각 폴더를 아주 짧게 요약하면:

- `packages/build/`
  빌드 중 생성된 산출물 임시 공간입니다.
- `packages/doc/`
  패키지 구조와 사용법을 설명하는 문서 공간입니다.
- `packages/soi_media_native/`
  SOI 앱이 사용하는 네이티브 미디어 처리 전용 패키지입니다.

## 3. 각 폴더 설명

### 3-1. `packages/build/`

이 폴더는 사람이 직접 기능을 개발하는 곳이라기보다, 빌드 과정에서 생기는 결과물이 놓이는 공간입니다.

주요 특징:
- 직접 비즈니스 로직을 작성하는 폴더가 아닙니다.
- `ios/XCBuildData` 같은 경로는 Xcode 또는 iOS 빌드 시스템이 사용하는 캐시/중간 산출물일 가능성이 큽니다.
- 보통 "소스의 진실"은 여기 있지 않고, 실제 소스는 다른 폴더에 있습니다.

쉽게 말해:
- `build/`는 "요리 결과가 잠깐 놓이는 조리대"
- 진짜 레시피는 `lib/`, `src/`, `hook/` 같은 소스 폴더에 있습니다

### 3-2. `packages/doc/`

이 폴더는 패키지 관련 문서를 모아 두는 공간입니다.

추천 용도:

- 패키지 구조 설명
- 패키지 간 의존 관계 설명
- 메인 앱과 패키지의 연결 방식 설명
- 새 팀원이 처음 읽는 온보딩 문서
- "이 패키지를 수정할 때 어디를 봐야 하나?" 같은 실무 가이드

즉, 코드를 실행하는 공간이 아니라 "이해를 돕는 설명서 공간"입니다.

### 3-3. `packages/soi_media_native/`

이 폴더는 메인 앱이 사용하는 별도 Dart/Flutter 패키지입니다.

역할:

- 이미지 크기 probe
- 네이티브 이미지 압축
- 웨이브폼 샘플링/인코딩/디코딩

왜 별도 패키지로 분리했는가:

- 메인 앱 `lib/`에 네이티브 FFI 구현을 직접 섞지 않기 위해
- 미디어 처리라는 전문 기능을 독립적으로 관리하기 위해
- 테스트와 빌드 경계를 분리하기 위해
- 추후 재사용 가능성을 높이기 위해

## 4. `soi_media_native` 내부 구조

`packages/soi_media_native`는 아래처럼 이해하면 쉽습니다.

```text
packages/soi_media_native/
├─ hook/
│  └─ build.dart
├─ lib/
│  ├─ soi_media_native.dart
│  └─ soi_media_native_bindings_generated.dart
├─ src/
│  ├─ soi_media_native.c
│  └─ soi_media_native.h
├─ test/
│  └─ soi_media_native_test.dart
├─ third_party/
│  ├─ stb/
│  └─ libwebp/
├─ pubspec.yaml
├─ ffigen.yaml
└─ README.md
```

각 하위 폴더의 의미는 다음과 같습니다.

### `hook/`

네이티브 코드를 어떻게 빌드할지 정의하는 곳입니다.

- `build.dart`
  C 소스와 서드파티 라이브러리를 묶어 네이티브 라이브러리를 빌드하는 스크립트

쉽게 말하면:
- "네이티브 재료들을 어떻게 조립할지 적어 둔 조립 설명서"

### `lib/`

Dart 코드가 있는 공개 API 영역입니다.

- `soi_media_native.dart`
  메인 앱이 직접 호출하는 진짜 입구
- `soi_media_native_bindings_generated.dart`
  C 함수와 Dart를 연결하는 자동 생성 바인딩

쉽게 말하면:

- `lib/`는 "앱이 보는 정문"
- 메인 앱은 보통 여기만 보면 됩니다

### `src/`

실제 C 구현이 들어 있는 네이티브 소스 영역입니다.

- `soi_media_native.h`
  어떤 함수를 외부에 공개할지 적은 헤더
- `soi_media_native.c`
  실제 압축, probe, waveform 샘플링 같은 구현

쉽게 말하면:

- `src/`는 "엔진룸"
- 빠른 처리나 저수준 처리가 필요한 로직이 여기 있습니다

### `test/`

패키지 동작을 검증하는 테스트 공간입니다.

예:

- PNG 이미지 크기 probe가 잘 되는지
- waveform 샘플링이 예상대로 되는지
- 이미지 압축 결과 파일이 생성되는지

### `third_party/`

외부 오픈소스 라이브러리를 vendoring 해 둔 공간입니다.

- `stb/`
  이미지 decode/resize/write 보조 헤더
- `libwebp/`
  WebP 인코딩/디코딩 구현

이 폴더는 직접 기능을 설계하기보다는 "외부 엔진을 가져와 붙여 둔 곳"으로 보면 됩니다.

## 5. 메인 앱과 packages의 소통 구조

가장 중요한 부분입니다.

메인 앱은 `pubspec.yaml`에서 로컬 패키지를 의존성으로 등록합니다.

현재 메인 앱 루트 `pubspec.yaml`에는 다음처럼 연결되어 있습니다.

```yaml
dependencies:
  soi_media_native:
    path: packages/soi_media_native
```

이 뜻은:

- 메인 앱이 `packages/soi_media_native`를 로컬 패키지로 사용한다
- pub.dev에서 내려받는 것이 아니라 같은 저장소 안의 로컬 코드를 직접 참조한다

## 6. 소통 흐름을 그림으로 보기

### 6-1. 가장 단순한 흐름

```text
Flutter UI / Service
        ↓
lib/api/media_processing/media_processing_backend.dart
        ↓
package:soi_media_native/soi_media_native.dart
        ↓
generated FFI bindings
        ↓
C source (src/soi_media_native.c)
        ↓
stb / libwebp
```

이 흐름을 말로 풀면:

1. 앱 화면이나 서비스가 "이미지 압축해줘"라고 요청합니다.
2. 앱 내부의 `MediaProcessingBackend`가 그 요청을 받습니다.
3. 이 백엔드는 `soi_media_native` 패키지의 Dart API를 호출합니다.
4. 패키지의 Dart 코드는 FFI 바인딩을 통해 C 함수를 호출합니다.
5. C 구현은 `stb`, `libwebp` 같은 네이티브 라이브러리를 이용해 실제 처리를 수행합니다.
6. 결과가 다시 Dart로 올라오고, 최종적으로 앱이 그 결과를 사용합니다.

### 6-2. 실제 코드 기준 구조

```text
Main App
├─ lib/views/...                화면/UI
├─ lib/api/...                  앱 내부 서비스/컨트롤러
└─ lib/api/media_processing/
   └─ media_processing_backend.dart
           ↓ imports
package:soi_media_native/soi_media_native.dart
           ↓ uses
packages/soi_media_native/lib/soi_media_native.dart
           ↓ binds to
packages/soi_media_native/lib/soi_media_native_bindings_generated.dart
           ↓ calls
packages/soi_media_native/src/soi_media_native.c
```

핵심 포인트:

- 앱은 C 코드를 직접 호출하지 않습니다.
- 앱은 `MediaProcessingBackend`와 패키지의 Dart API를 통해 간접적으로 사용합니다.
- 즉, "앱 ↔ 패키지" 사이에 한 단계의 완충층이 있습니다.

## 7. 왜 이런 구조가 좋은가

이 구조의 장점은 분명합니다.

### 1. 역할 분리가 됩니다

- 메인 앱은 사용자 경험, 화면, 흐름에 집중
- 패키지는 성능이 중요한 미디어 처리에 집중

### 2. 코드가 덜 엉킵니다

FFI, C, 빌드 훅, 외부 네이티브 라이브러리를 메인 앱 코드 한가운데에 섞지 않아도 됩니다.

### 3. 테스트가 쉬워집니다

패키지 테스트와 앱 테스트를 어느 정도 분리할 수 있습니다.

### 4. 재사용 가능성이 생깁니다

나중에 다른 앱이나 다른 모듈에서도 같은 패키지를 재사용하기 쉬워집니다.

## 8. 수정할 때 어디를 보면 되는가

패키지 수정 시 "무엇을 바꾸고 싶은가?"에 따라 보는 위치가 달라집니다.

### 이미지 압축 규칙을 바꾸고 싶다

우선 확인:

- `packages/soi_media_native/lib/soi_media_native.dart`
- `packages/soi_media_native/src/soi_media_native.c`
- `lib/api/media_processing/media_processing_backend.dart`

### C 함수 시그니처가 바뀐다

우선 확인:

- `packages/soi_media_native/src/soi_media_native.h`
- `packages/soi_media_native/src/soi_media_native.c`
- `packages/soi_media_native/ffigen.yaml`
- `packages/soi_media_native/lib/soi_media_native_bindings_generated.dart`

주의:

- 헤더가 바뀌면 바인딩 재생성이 필요할 수 있습니다.

### 패키지 빌드가 깨진다

우선 확인:

- `packages/soi_media_native/hook/build.dart`
- `packages/soi_media_native/third_party/`
- 패키지 루트의 `pubspec.yaml`

### 앱에서 패키지를 어떻게 쓰는지 알고 싶다

우선 확인:

- 루트 `pubspec.yaml`
- `lib/api/media_processing/media_processing_backend.dart`
- `rg -n "package:soi_media_native|SoiMediaNativeClient" lib`

## 9. 새 팀원을 위한 빠른 읽기 순서

처음 읽는 사람에게 추천하는 순서는 다음과 같습니다.

1. 이 문서
2. `pubspec.yaml`
3. `lib/api/media_processing/media_processing_backend.dart`
4. `packages/soi_media_native/lib/soi_media_native.dart`
5. `packages/soi_media_native/src/soi_media_native.h`
6. `packages/soi_media_native/src/soi_media_native.c`
7. `packages/soi_media_native/test/soi_media_native_test.dart`

이 순서가 좋은 이유:

- 먼저 "연결 구조"를 이해하고
- 그 다음 "공개 API"를 보고
- 마지막에 "저수준 구현"으로 내려가기 때문입니다

## 10. 실무 가이드

### 가이드 1. `build/` 폴더는 보통 설명 대상이지, 수정 대상은 아닙니다

- 빌드 산출물이므로 소스의 기준점으로 삼지 않습니다.
- 구조 설명 문서에는 포함하되, 실제 수정 우선순위는 낮습니다.

### 가이드 2. 패키지의 정문은 `lib/`입니다

- 메인 앱에서 패키지를 사용할 때는 보통 `lib/`의 Dart API를 사용합니다.
- `src/`는 내부 구현이므로 바로 건드리기 전에 상위 Dart 계약을 먼저 봅니다.

### 가이드 3. C 코드를 수정하면 테스트와 바인딩을 같이 생각해야 합니다

- 헤더 변경
- 바인딩 재생성 필요 여부 확인
- Dart 측 시그니처 확인
- 패키지 테스트 재실행

### 가이드 4. 메인 앱과 패키지 사이에는 "계약"이 있습니다

현재 SOI에서는 그 계약을 주로 아래가 담당합니다.

- 메인 앱 쪽: `lib/api/media_processing/media_processing_backend.dart`
- 패키지 쪽: `packages/soi_media_native/lib/soi_media_native.dart`

즉, 두 파일은 같이 읽어야 이해가 빠릅니다.

## 11. 앞으로 문서를 더 확장한다면

`packages/doc/` 아래에 다음 문서를 추가하면 팀 온보딩이 더 쉬워집니다.

- `soi_media_native_walkthrough.md`
  `soi_media_native`만 깊게 설명하는 문서
- `package_change_checklist.md`
  패키지 수정 시 점검할 항목 체크리스트
- `ffi_flow_diagram.md`
  Dart FFI에서 C로 내려가는 구조만 따로 그림으로 설명한 문서

## 12. 한 줄 요약

`packages/`는 메인 앱 바깥으로 분리한 기능 묶음 공간이고, 현재 SOI에서는 `soi_media_native`가 핵심 패키지이며, 메인 앱은 `MediaProcessingBackend`를 통해 이 패키지와 안전하게 소통합니다.
