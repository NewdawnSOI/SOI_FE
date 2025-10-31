# SOI 개발 가이드

SOI 프로젝트의 실용적인 개발 가이드 모음입니다.

## 📚 문서 목록

### [백엔드-프론트엔드 API 협업 워크플로우](./backend-frontend-api-workflow.md) ⭐ 필독

**대상:** 전체 팀 (백엔드 + 프론트엔드)

**내용:**

- 서버 직접 실행 없이 개발하는 방법
- Dev Server 사용 전략 (90% 권장)
- Swagger/OpenAPI 설정 및 사용법
- Mock Server 활용 (백엔드 서버 없을 때)
- 백엔드/프론트엔드 각자 해야할 일
- 실전 시나리오 3가지
- 트러블슈팅

**핵심 포인트:**

```bash
# 백엔드 개발자
1. Springdoc OpenAPI 설정
2. Controller 애노테이션 추가
3. Dev 서버 배포
4. 프론트 팀에 알림

# 프론트엔드 개발자
1. make update-api  ← 이것만 하면 끝!
2. flutter run --dart-define=ENV=dev
```

---

## 🎯 빠른 시작

### 프론트엔드 개발자

```bash
# 1. OpenAPI Generator 설치
brew install openapi-generator

# 2. API 클라이언트 생성
make update-api

# 3. 앱 실행 (Dev 서버)
flutter run --dart-define=ENV=dev
```

### 백엔드 개발자

```java
// 1. build.gradle에 의존성 추가
implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.3.0'

// 2. OpenApiConfig 클래스 생성

// 3. Controller에 애노테이션 추가
@Tag(name = "Category")
@Operation(summary = "카테고리 조회")
```

---

## 💡 자주 묻는 질문

### Q: 백엔드 서버를 로컬에서 실행해야 하나요?

**A:** 아니요! Dev 서버를 사용하면 됩니다.

```bash
# 대부분 이렇게만 하면 됩니다
flutter run --dart-define=ENV=dev
```

### Q: 백엔드가 서버를 끄면 개발 못하나요?

**A:** Mock Server를 사용하면 됩니다.

```bash
# Prism Mock Server 실행
prism mock openapi.yaml

# Flutter 앱 실행 (Mock 서버 대상)
flutter run --dart-define=ENV=local
```

### Q: API가 변경되면 어떻게 하나요?

**A:** 한 줄 명령어로 해결됩니다.

```bash
make update-api
```

### Q: API 클라이언트를 수동으로 작성해야 하나요?

**A:** 아니요! 자동 생성됩니다.

```bash
# OpenAPI 스펙에서 자동 생성
make generate-api

# 생성된 API 사용
final api = CategoryApi(dio);
final response = await api.getCategories();
```

---

## 📞 문의

- **기술 문의:** GitHub Issues
- **긴급 문의:** Slack #soi-dev

---

**Last Updated:** 2025-10-31
