# FFI Media Processing Guide

## 목적

이 문서는 SOI의 미디어 처리 구조를 주니어 개발자도 빠르게 이해하고 유지보수할 수 있도록 정리한 가이드입니다.

현재 구조의 핵심 원칙은 두 가지입니다.

1. `packages/soi_media_native`는 **FFI가 필요한 순수 native 기능만** 담당합니다.
2. `lib/utils/media_processing`는 **앱에서 쓰는 단일 진입점**만 제공합니다.

이 원칙 때문에 예전처럼 `legacy/native/factory/plugin bridge`를 여러 겹으로 따라갈 필요가 없습니다.

---

## 현재 의존성 구조

```text
UI / Service / Cache
  -> lib/utils/media_processing/media_processing_backend.dart
    -> packages/soi_media_native/lib/soi_media_native.dart
      -> packages/soi_media_native/src/soi_media_native.c
        -> stb + libwebp

UI / Service / Cache
  -> lib/utils/media_processing/media_processing_backend.dart
    -> video_compress / video_thumbnail
```

한 줄로 정리하면:

- 이미지 메타데이터 읽기, 이미지 압축, 웨이브폼 처리: `FFI 패키지`
- 비디오 압축, 비디오 썸네일: `Flutter 플러그인`

---

## 파일별 역할

### Flutter 앱 쪽

#### [media_processing_backend.dart](/Users/minchanpark/Documents/SOI/lib/utils/media_processing/media_processing_backend.dart)

앱이 사용하는 **단일 미디어 처리 API**입니다.

- `MediaProcessingBackend`
  - 앱 코드가 의존하는 공통 계약입니다.
  - 테스트에서는 `FakeMediaProcessingBackend`가 이 계약을 구현합니다.
- `DefaultMediaProcessingBackend`
  - 실제 운영 구현입니다.
  - 이미지와 웨이브폼은 `soi_media_native`를 사용합니다.
  - 비디오는 `video_compress`, `video_thumbnail`를 사용합니다.

이 파일만 보면 앱이 어떤 미디어 기능을 어디에 맡기는지 바로 알 수 있어야 합니다.

#### [waveform_codec.dart](lib/utils/media_processing/waveform_codec.dart)

웨이브폼을 화면과 API에서 편하게 쓰기 위한 **얇은 편의 래퍼**입니다.

- `encodeOrNull`
- `encodeOrEmpty`
- `decodeOrNull`
- `decodeOrEmpty`
- `sample`

핵심 규칙은 여기서 “편하게” 제공하고, 실제 샘플링/인코딩 로직은 `MediaProcessingBackend`가 담당합니다.

### FFI 패키지 쪽

#### [soi_media_native.dart](/Users/minchanpark/Documents/SOI/packages/soi_media_native/lib/soi_media_native.dart)

`C` 함수를 Dart에서 안전하게 호출하기 위한 **패키지 공개 API**입니다.

담당 기능:

- `probeImage`
- `compressImage`
- `sampleWaveform`
- `encodeWaveform`
- `decodeWaveform`

이 파일에는 비디오나 썸네일 로직이 없습니다.
FFI 패키지는 이제 이미지와 웨이브폼만 책임집니다.

#### [soi_media_native_bindings_generated.dart](/Users/minchanpark/Documents/SOI/packages/soi_media_native/lib/soi_media_native_bindings_generated.dart)

`C ABI`와 Dart를 연결하는 **낮은 레벨 바인딩 선언**입니다.

- `soi_probe_image`
- `soi_compress_image`
- `soi_sample_waveform`

여기는 “기계적으로 연결”하는 레이어입니다.
앱 로직을 넣지 않습니다.

#### [build.dart](/Users/minchanpark/Documents/SOI/packages/soi_media_native/hook/build.dart)

FFI 패키지 빌드 스크립트입니다.

역할:

- `src/soi_media_native.c` 컴파일
- vendored `libwebp` 소스 포함
- `stb` 헤더 포함

이미지 압축에 필요한 native 소스를 한 라이브러리로 묶는 역할만 합니다.

#### [soi_media_native.h](/Users/minchanpark/Documents/SOI/packages/soi_media_native/src/soi_media_native.h)

`Dart <-> C` 사이 ABI 계약 헤더입니다.

여기에 선언된 함수만 Dart에서 직접 호출합니다.

#### [soi_media_native.c](/Users/minchanpark/Documents/SOI/packages/soi_media_native/src/soi_media_native.c)

실제 native 구현입니다.

담당 기능:

- PNG/JPEG/WEBP 헤더 probe
- 이미지 decode
- 비율 유지 resize
- WEBP/JPEG/PNG encode
- 웨이브폼 샘플링

이미지 압축 정책을 바꾸고 싶으면 이 파일을 먼저 봅니다.

---

## 왜 이렇게 단순화했나

이전 구조는 아래 요소가 함께 있어서 추적 비용이 컸습니다.

- legacy backend
- native backend
- backend factory
- package 내부 plugin bridge
- app 내부 waveform wrapper

이제는 아래처럼 정리되었습니다.

- 앱은 `DefaultMediaProcessingBackend` 하나만 사용
- 테스트만 `FakeMediaProcessingBackend` 사용
- FFI 패키지는 native 기능만 보유
- 비디오는 앱 레이어에서 직접 plugin 사용

즉, 개발자가 “지금 이 기능이 어디서 돌아가는지”를 찾기 쉬워졌습니다.

---

## 기능별 수정 포인트

### 1. 이미지 압축 정책을 바꾸고 싶을 때

먼저 볼 파일:

- [soi_media_native.c](/Users/minchanpark/Documents/SOI/packages/soi_media_native/src/soi_media_native.c)
- [soi_media_native.dart](/Users/minchanpark/Documents/SOI/packages/soi_media_native/lib/soi_media_native.dart)
- [media_processing_backend.dart](/Users/minchanpark/Documents/SOI/lib/utils/media_processing/media_processing_backend.dart)

보통 수정 위치:

- resize 규칙 변경: `soi_media_native.c`
- 출력 포맷 enum 추가: `soi_media_native.h`, `soi_media_native_bindings_generated.dart`, `soi_media_native.dart`, `media_processing_backend.dart`

### 2. 이미지 가로세로 비율 계산이 이상할 때

먼저 볼 파일:

- [media_processing_backend.dart](/Users/minchanpark/Documents/SOI/lib/utils/media_processing/media_processing_backend.dart)
- [soi_media_native.c](/Users/minchanpark/Documents/SOI/packages/soi_media_native/src/soi_media_native.c)

설명:

- 기본 경로는 native probe를 먼저 시도합니다.
- native가 모르는 포맷이면 Flutter codec fallback을 사용합니다.

### 3. 웨이브폼 인코딩/파싱 형식을 바꾸고 싶을 때

먼저 볼 파일:

- [soi_media_native.dart](/Users/minchanpark/Documents/SOI/packages/soi_media_native/lib/soi_media_native.dart)
- [waveform_codec.dart](/Users/minchanpark/Documents/SOI/lib/utils/media_processing/waveform_codec.dart)

설명:

- 실제 샘플링/인코딩 규칙은 FFI 패키지에 있습니다.
- 앱에서는 `WaveformCodec`가 null-safe 편의 메서드만 제공합니다.

### 4. 비디오 압축/썸네일 정책을 바꾸고 싶을 때

먼저 볼 파일:

- [media_processing_backend.dart](/Users/minchanpark/Documents/SOI/lib/utils/media_processing/media_processing_backend.dart)
- [video_thumbnail_cache.dart](/Users/minchanpark/Documents/SOI/lib/utils/video_thumbnail_cache.dart)

설명:

- 이 부분은 FFI 패키지가 아니라 Flutter 플러그인 경로입니다.
- 비디오 관련 수정은 `packages/soi_media_native`에서 찾지 않습니다.

---

## 테스트 전략

### 앱 쪽 테스트

앱 테스트는 `FakeMediaProcessingBackend`를 사용합니다.

파일:

- [fake_media_processing_backend.dart](/Users/minchanpark/Documents/SOI/test/support/fake_media_processing_backend.dart)

이 테스트 더블은 다음 목적에 맞습니다.

- 서비스가 올바른 파라미터를 넘기는지 검증
- 캐시가 중복 요청을 막는지 검증
- waveform 호출부가 같은 계약을 따르는지 검증

### 패키지 쪽 테스트

패키지 테스트는 실제 native 함수를 직접 호출합니다.

파일:

- [soi_media_native_test.dart](/Users/minchanpark/Documents/SOI/packages/soi_media_native/test/soi_media_native_test.dart)

이 테스트는 다음을 검증합니다.

- 이미지 probe 동작
- 이미지 압축 결과 파일 생성
- 웨이브폼 샘플링과 인코딩 규칙

---

## 주니어 개발자를 위한 운영 규칙

1. 이미지와 웨이브폼 문제는 먼저 `packages/soi_media_native`를 봅니다.
2. 비디오 문제는 먼저 `media_processing_backend.dart`를 봅니다.
3. 새로운 추상화는 쉽게 추가하지 않습니다.
4. 운영 구현은 `DefaultMediaProcessingBackend` 하나로 유지합니다.
5. 테스트용 분리는 `FakeMediaProcessingBackend` 하나면 충분합니다.

---

## 앞으로도 유지해야 할 단순화 원칙

새 기능을 추가할 때 아래 원칙을 지키면 구조가 다시 복잡해지지 않습니다.

- FFI 패키지에는 native 기능만 넣습니다.
- 앱 레이어에서만 Flutter plugin을 사용합니다.
- factory보다 명시적인 기본 구현 하나를 선호합니다.
- “실험용 백엔드”보다 “운영 구현 + 테스트 더블” 구조를 우선합니다.
- 웨이브폼 편의 함수는 `WaveformCodec`, 실제 처리 로직은 `MediaProcessingBackend`에 둡니다.

이 문서를 기준으로 구조가 다시 복잡해지기 시작하면, 새 레이어를 추가하기 전에 먼저 “정말 필요한가?”를 확인하는 것이 좋습니다.
