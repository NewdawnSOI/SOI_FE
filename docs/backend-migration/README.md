# Firebase → Spring Boot 백엔드 마이그레이션 완전 가이드

SOI 앱의 Firebase 기반 아키텍처를 Spring Boot REST API 백엔드로 전환하는 완전한 실전 가이드입니다.

## 🎯 한눈에 보기

**현재**: Flutter → Firebase SDK → Firestore (실시간 스트림)  
**변경**: Flutter → REST API → Spring Boot → Database (요청/응답)

### 핵심 변화

- ✅ **프론트엔드**: 비즈니스 로직 90% 제거, UI에만 집중
- ✅ **백엔드**: 모든 로직 중앙화, 보안 강화
- ✅ **자동화**: OpenAPI로 API 클라이언트 자동 생성
- ⚠️ **트레이드오프**: 실시간성 감소 (polling/FCM으로 대체)

---

## 📖 문서 구성

### [1. main.dart 수정 가이드](./01-main-dart-setup.md) ✅

**내용:**

- 현재 main.dart 구조 분석 (15 Controllers, Firebase 초기화)
- EnvironmentConfig 설정 (dev/staging/prod)
- ApiConfig + Dio 인터셉터 (Auth, Error, Logging)
- 수정된 main.dart (API 클라이언트 DI)
- Controller 수정 예시 (Stream → Future)
- VSCode launch.json 설정
- pubspec.yaml 변경사항
- 실행 및 트러블슈팅

**읽어야 하는 사람:** 프론트엔드 개발자 (필수)

---

### [2. Firebase → Spring Boot 마이그레이션](./02-firebase-to-springboot.md) ✅

**내용:**

- 4단계 마이그레이션 전략
- 완전한 Spring Boot 프로젝트 구조
- Category 도메인 전체 구현 (Entity, DTO, Repository, Service, Controller)
- OpenAPI 애노테이션 예시
- Firestore → PostgreSQL 마이그레이션 스크립트
- build.gradle 설정

**읽어야 하는 사람:** 백엔드 개발자 (필수), 프론트엔드 개발자 (참고)

---

### [3. 아키텍처 비교](./03-architecture-comparison.md) ✅

**내용:**

- Firebase vs Spring Boot 아키텍처 다이어그램
- Category 도메인 상세 비교 (데이터 저장, 조회, 멤버 추가)
- 실제 코드 Before/After (150줄 → 30줄)
- 성능 비교 (3850ms → 250ms, 15배 개선)
- 비용 비교 ($2,530/월 → $240/월, 90% 절감)
- 보안 비교 (Security Rules vs Spring Security)
- 유지보수성 비교

**읽어야 하는 사람:** 전체 팀 (이해를 위해 필수)

---

### [4. 백엔드/프론트엔드 역할 분리](./04-responsibility-division.md) ✅

**내용:**

- 백엔드/프론트엔드 책임 표
- 비즈니스 로직 이관 예시 (친구 확인, 사진 업로드)
- 데이터 검증 분리 (클라이언트 vs 서버)
- 보안 역할 (인증/권한)
- 복잡도 비교 (Firebase 5회 호출 → API 1회 호출)
- "어디에 구현할까?" 체크리스트

**읽어야 하는 사람:** 전체 팀 (협업 가이드)

---

### [5. Flutter 프로젝트 구조 변경](./05-flutter-structure-changes.md) ✅

**내용:**

- 전체 구조 Before/After
- 파일별 상세 변경 (main.dart, Controllers, Services, Repositories, Models)
- 파일 수 변화 (60개 → 35개 + 자동 생성)
- pubspec.yaml 변경사항 (Firebase → Dio + soi_api)
- 마이그레이션 단계별 체크리스트
- 도메인별 우선순위 (Auth → Category → Photo)
- Category 마이그레이션 실전 예시 (620줄 → 140줄, 77% 감소)

**읽어야 하는 사람:** 프론트엔드 개발자 (필수)

---

### [6. OpenAPI/Swagger 자동화 완전 가이드](./06-openapi-automation.md) ✅

**내용:**

- Spring Boot OpenAPI 설정 (Springdoc, @Operation 애노테이션)
- OpenAPI 스펙 생성 및 다운로드
- OpenAPI Generator 설치 및 설정
- Makefile 자동화 (`make generate-api`, `make update-api`)
- 생성된 API 사용 예시 (CategoryApi, PhotoApi)
- CI/CD 자동화 (GitHub Actions)
- SOI 프로젝트 적용 시나리오
- 트러블슈팅

**읽어야 하는 사람:** 전체 팀 (핵심 자동화)

---

### [7. 개발 워크플로우 실전 시나리오](./07-development-workflow.md) ✅

**내용:**

- 시나리오 1: 새로운 API 추가 (사진 좋아요 기능)
  - 백엔드: Entity, DTO, Repository, Service, Controller, 배포
  - 프론트엔드: `make update-api`, Repository, Controller, UI
- 시나리오 2: 기존 API 수정 (멤버 프로필 이미지 추가)
- 시나리오 3: 에러 처리 (사용자 친화적 메시지)
- 타임라인 예시 (2일 완료)
- 커뮤니케이션 템플릿

**읽어야 하는 사람:** 전체 팀 (협업 필수)

---

### [8. 개발 환경 설정 가이드](./08-environment-setup.md) ✅

**내용:**

- 환경 구성 전략 (Dev 서버 90%, Mock 5%, 로컬 Docker 5%)
- Dev 서버 환경 (권장, 별도 설정 불필요)
- Mock 서버 (Prism) 사용법
- 로컬 Docker 환경 (docker-compose.yml, Dockerfile)
- 인증 토큰 관리 (테스트 계정, 자동 로그인)
- 환경별 비교 표
- 실전 시나리오별 환경 선택
- Makefile 명령어 모음
- 베스트 프랙티스

**읽어야 하는 사람:** 프론트엔드 개발자 (필수)

---

## 🎯 마이그레이션 목표

### 달성하려는 것

- ✅ 백엔드 로직 중앙화 (보안, 검증, 비즈니스 로직)
- ✅ 프론트엔드 단순화 (UI/UX에만 집중)
- ✅ API 자동화 (OpenAPI Generator)
- ✅ 확장 가능한 아키텍처

### 포기하는 것

- ⚠️ 실시간 스트림 (대신 polling/FCM 사용)
- ⚠️ Firebase 자동 오프라인 지원 (필요시 수동 구현)
- ⚠️ 클라이언트 직접 DB 접근

---

## 📊 현재 프로젝트 구조

```
lib/
├── main.dart                  # 앱 진입점
├── controllers/              # 15개 - ChangeNotifier 기반 상태 관리
│   ├── auth_controller.dart
│   ├── category_controller.dart
│   ├── friend_controller.dart
│   └── ...
├── services/                 # 17개 - 비즈니스 로직
│   ├── auth_service.dart
│   ├── category_service.dart
│   ├── friend_service.dart
│   └── ...
├── repositories/             # 12개 - Firebase 직접 접근
│   ├── auth_repository.dart
│   ├── category_repository.dart
│   ├── friend_repository.dart
│   └── ...
├── models/                   # 14개 - 데이터 모델
│   ├── category_data_model.dart
│   ├── friend_model.dart
│   └── ...
└── views/                    # UI 컴포넌트
    ├── about_archiving/
    ├── about_camera/
    ├── about_friends/
    └── ...
```

---

## 🔄 변경될 구조

```
lib/
├── main.dart                  # ✏️ 수정 - API 클라이언트 DI
├── config/                    # 🆕 새로 추가
│   ├── environment.dart      # 환경 설정
│   └── api_config.dart       # API URL 관리
├── api/                       # 🆕 새로 추가 (자동 생성)
│   └── generated/            # OpenAPI Generator 출력
│       ├── lib/
│       │   ├── api/          # CategoryApi, FriendApi 등
│       │   └── model/        # DTO 모델들
│       └── pubspec.yaml
├── controllers/               # ✏️ 수정 - Stream → Future
│   ├── auth_controller.dart
│   ├── category_controller.dart
│   └── ...
├── services/                  # ✏️ 대폭 간소화 - 비즈니스 로직 제거
│   ├── auth_service.dart
│   ├── category_service.dart
│   └── ...
├── repositories/              # ✏️ 수정 - Firebase → API 호출
│   ├── auth_repository.dart
│   ├── category_repository.dart
│   └── ...
├── models/                    # ✅ 거의 그대로 (일부 DTO 추가)
│   ├── category_data_model.dart
│   └── ...
└── views/                     # ✏️ 수정 - StreamBuilder → Consumer
    └── ...
```

---

## ⏱️ 예상 마이그레이션 일정

### Phase 1: 백엔드 구축 (2-3주)

- Spring Boot 프로젝트 생성
- Entity 및 Repository 구현
- Service 비즈니스 로직
- REST API Controller
- OpenAPI 스펙 생성

### Phase 2: Flutter 준비 (1-2주)

- API 클라이언트 레이어 추가
- 환경 설정
- Repository 수정
- Service 간소화

### Phase 3: 점진적 전환 (2-3주)

- 읽기 기능부터 시작
- StreamBuilder → Consumer 전환
- 쓰기 기능
- 초대 시스템

### Phase 4: 최적화 (1주)

- 캐싱 추가
- 성능 개선
- 버그 수정

**총 예상 기간**: 6-9주

---

## 🚀 빠른 시작

### 1. 문서 순서대로 읽기

```bash
# 1. main.dart 수정 방법 확인
open 01-main-dart-setup.md

# 2. 전체 마이그레이션 계획 이해
open 02-firebase-to-springboot.md

# 3. 실제 코드 비교
open 03-architecture-comparison.md

# ... 순서대로 진행
```

### 2. 백엔드 팀과 협의

- 개발 서버 URL 공유
- OpenAPI 엔드포인트 확인
- Docker Compose 파일 요청

### 3. 환경 설정

```bash
# OpenAPI Generator 설치
brew install openapi-generator

# 환경 변수 설정
cp .env.example .env
```

### 4. 첫 번째 API 테스트

```bash
# OpenAPI 스펙 다운로드
curl https://dev-api.soi.app/v3/api-docs.yaml -o openapi.yaml

# Flutter 클라이언트 생성
openapi-generator generate -i openapi.yaml -g dart-dio -o lib/api/generated

# 앱 실행 (Dev 서버 연결)
flutter run --dart-define=ENV=dev
```

---

## 💡 주요 개념

### 실시간 업데이트 대체

- **기존**: Firebase Stream (실시간)
- **변경**: Pull-to-refresh + FCM Push (약간의 지연 허용)
- **이유**: 사진 공유 앱 특성상 충분함

### 비즈니스 로직 위치

- **기존**: Flutter (클라이언트)
- **변경**: Spring Boot (서버)
- **예시**: 친구 확인, 차단 필터링, 권한 검증

### API 클라이언트 생성

- **기존**: 수동 작성
- **변경**: OpenAPI Generator로 자동 생성
- **장점**: 타입 안정성, 자동 동기화

---

## 📞 문의 및 기여

### 질문이 있으신가요?

- 각 문서의 "FAQ" 섹션 참고
- GitHub Issues에 질문 등록

### 개선 제안

- Pull Request 환영
- 실제 적용 사례 공유

---

## 📝 변경 이력

- 2025-10-21: 초안 작성
- 추후 업데이트 예정

---

## 다음 단계

👉 **[1. main.dart 수정 가이드로 이동](./01-main-dart-setup.md)**
