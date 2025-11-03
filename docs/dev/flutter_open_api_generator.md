# Flutter OpenAPI Generator 사용 가이드

## 개요

이 문서는 SOI 프로젝트에서 OpenAPI Generator를 사용하여 API 클라이언트 코드를 생성하고 관리하는 방법을 설명합니다.

## 프로젝트 구조

- `openapi.yaml`: API 명세 파일
- `openapi-generator-config.yaml`: Generator 설정 파일
- `lib/api/generated/`: 생성된 API 클라이언트 코드 (별도 패키지)

## 필수 패키지

### 메인 프로젝트 (`pubspec.yaml`)

```yaml
dependencies:
  json_annotation: ^4.9.0

dev_dependencies:
  build_runner: ^2.10.1
  json_serializable: ^6.11.1
```

### API 패키지 (`lib/api/generated/pubspec.yaml`)

```yaml
environment:
  sdk: ">=3.8.0 <4.0.0"

dependencies:
  dio: ^5.9.0
  json_annotation: ^4.9.0

dev_dependencies:
  build_runner: 2.10.1
  json_serializable: ^6.11.1
```

## 코드 생성 워크플로우

### 1. OpenAPI 스키마 업데이트 및 코드 생성

```bash
# 1단계: OpenAPI Generator로 Dart 클라이언트 코드 생성
openapi-generator generate -c openapi-generator-config.yaml

# 2단계: API 패키지 내에서 build_runner 실행
cd lib/api/generated && dart run build_runner build --delete-conflicting-outputs
```

### 2. 전체 클린 빌드 (문제 발생 시)

```bash
# API 패키지 클린 빌드
cd lib/api/generated
flutter pub get
rm -rf lib/src/model/*.g.dart
dart run build_runner build --delete-conflicting-outputs

# 메인 프로젝트로 돌아가기
cd ../../..
flutter pub get
```

## 트러블슈팅

### 문제: `Target of URI hasn't been generated` 에러

**원인**: `.g.dart` 파일이 생성되지 않음

**해결**:

```bash
cd lib/api/generated
dart run build_runner build --delete-conflicting-outputs
```

### 문제: `InvalidType` 또는 `Could not generate fromJson` 에러

**원인**: API 패키지 내에서 build_runner가 실행되지 않음

**해결**:

1. `lib/api/generated/pubspec.yaml`의 SDK 버전이 `^3.8.0` 이상인지 확인
2. API 패키지 내에서 build_runner 실행

### 문제: `@CopyWith()` 관련 에러

**원인**: copy_with_extension과 json_serializable 간 충돌

**해결**: OpenAPI Generator 설정에서 `@CopyWith()` 사용 안 함 (현재 설정)

## 참고사항

- OpenAPI Generator가 생성한 코드는 `lib/api/generated`에 **별도 패키지**로 존재
- 따라서 해당 디렉토리 내에서도 build_runner를 실행해야 함
- `@CopyWith()` 어노테이션은 제거됨 (build_runner 충돌 방지)
- 생성된 `.g.dart` 파일들은 Git에 커밋하지 않음
