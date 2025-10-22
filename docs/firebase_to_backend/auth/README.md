# 인증 시스템 백엔드 마이그레이션 가이드

SOI 앱의 **인증 시스템**을 Firebase에서 **Firebase Authentication + Spring Boot 하이브리드** 구조로 마이그레이션하기 위한 종합 가이드입니다.

---

## 🎯 핵심 아키텍처

### Firebase Authentication (유지)

- **전화번호 SMS 인증** (Firebase가 처리)
- **Firebase UID 발급** (영구 식별자)
- **ID Token 생성** (인증 토큰)
- **자동 로그인** (Firebase Auth 세션)

### Spring Boot (신규)

- **Firebase ID Token 검증** (Firebase Admin SDK)
- **회원 정보 관리** (users 테이블)
- **프로필 이미지 관리** (S3 or Firebase Storage)
- **비즈니스 로직** (검색, 중복 확인, 탈퇴 처리)

---

## 📚 문서 구조

1. **[개요](./01-overview.md)** - 인증 기능 설명 및 시나리오
2. **[비즈니스 규칙](./02-business-rules.md)** - 검증 및 비즈니스 로직
3. **[API 엔드포인트](./03-api-endpoints.md)** - REST API 명세 (11개 엔드포인트)
4. **[데이터 모델](./04-data-models.md)** - Entity 및 DTO 설계
5. **[기능별 상세 명세](./05-features.md)** - 입력/처리/출력 프로세스

---

## 🚀 왜 하이브리드 구조인가?

### ✅ Firebase Authentication을 유지하는 이유

1. **인증 인프라 관리 불필요**

   - SMS 발송 인프라 구축/관리 불필요
   - 인증번호 검증 로직 구현 불필요
   - 전 세계 전화번호 형식 지원

2. **보안 처리 자동화**

   - reCAPTCHA 자동 처리
   - Rate Limiting 자동 적용
   - 봇 공격 방어

3. **자동 로그인 기능**

   - Firebase Auth 세션 관리
   - Refresh Token 자동 갱신
   - 멀티 디바이스 지원

4. **비용 효율적**
   - Firebase Auth는 무료 (월 10,000명까지)
   - SMS 발송 비용 최적화
   - 인프라 유지 비용 절감

### ✅ Spring Boot를 추가하는 이유

1. **비즈니스 로직 중앙 관리**

   - 친구 관계, 카테고리 권한 등
   - 복잡한 쿼리 및 트랜잭션
   - 데이터 무결성 보장

2. **확장성 및 성능**

   - 관계형 DB로 복잡한 쿼리 지원
   - 인덱스 최적화
   - 캐싱 전략 적용

3. **API 표준화**
   - RESTful API 설계
   - OpenAPI 명세
   - 자동 클라이언트 코드 생성

---

## 🔑 주요 기능

### 1. 회원가입

- Firebase 전화번호 인증
- Firebase UID 발급
- 백엔드에 사용자 정보 저장
- 프로필 이미지 업로드

### 2. 로그인

- Firebase 자동 로그인
- Firebase ID Token 획득
- 백엔드 인증 검증
- 사용자 정보 조회

### 3. 프로필 관리

- 프로필 이미지 업데이트
- 사용자 정보 수정
- 닉네임 변경

### 4. 사용자 검색

- 닉네임으로 검색
- 부분 일치 검색
- 페이지네이션

### 5. 계정 관리

- 계정 비활성화/활성화
- 회원 탈퇴
- 데이터 완전 삭제

---

## 📊 우선순위

### Phase 1: 핵심 인증 (1주)

- ✅ Firebase Admin SDK 설정
- ✅ ID Token 검증 필터
- ✅ 회원가입 API
- ✅ 로그인 API
- ✅ 사용자 정보 조회 API

### Phase 2: 프로필 관리 (1주)

- ✅ 프로필 이미지 업로드
- ✅ 사용자 정보 수정
- ✅ 닉네임 중복 확인

### Phase 3: 고급 기능 (1주)

- ✅ 사용자 검색
- ✅ 계정 비활성화/활성화
- ✅ 회원 탈퇴

### Phase 4: 최적화 (1주)

- ✅ 캐싱 전략
- ✅ 이미지 리사이징
- ✅ 성능 모니터링

**예상 기간**: 4주

---

## 🛠️ 기술 스택

### 백엔드

- **Framework**: Spring Boot 3.x
- **Language**: Java 17+
- **Auth**: Firebase Admin SDK
- **Database**: PostgreSQL or MySQL
- **ORM**: Spring Data JPA
- **Storage**: AWS S3 or Firebase Storage
- **Cache**: Redis (선택)

### 보안

- **인증**: Firebase ID Token
- **통신**: HTTPS
- **암호화**: AES-256
- **Rate Limiting**: Spring Cloud Gateway

---

## 📈 성능 목표

| 항목          | 현재 (Firebase) | 목표 (Spring Boot) |
| ------------- | --------------- | ------------------ |
| 회원가입 속도 | 2-3초           | **1-2초**          |
| 로그인 속도   | 1-2초           | **500ms-1초**      |
| 프로필 조회   | 500ms           | **100-300ms**      |
| 검색 속도     | 1-2초           | **200-500ms**      |
| 동시 사용자   | 100명           | **1,000명+**       |

---

## 🔒 보안 규칙

### 1. Firebase ID Token 검증

- 모든 API 요청에서 토큰 검증
- 만료된 토큰 자동 거부
- 변조된 토큰 탐지

### 2. 데이터 접근 제어

- 본인 정보만 수정 가능
- 관리자 권한 분리
- 민감 정보 암호화

### 3. Rate Limiting

- API 호출 제한 (분당 60회)
- 이미지 업로드 제한 (시간당 10회)
- 검색 요청 제한 (분당 30회)

---

## 🔄 마이그레이션 전략

### 1. 데이터 마이그레이션

```
Firestore users/{uid}
  ↓
PostgreSQL users (firebase_uid, nickname, name, ...)
```

### 2. 점진적 전환

- Phase 1: 신규 회원만 백엔드 사용
- Phase 2: 기존 회원 데이터 마이그레이션
- Phase 3: Firestore 읽기 전용 전환
- Phase 4: Firestore 완전 중단

### 3. 롤백 계획

- Firebase Authentication 유지 (롤백 가능)
- Firestore 백업 유지 (30일)
- 단계별 검증 체크포인트

---

## 📝 다음 단계

1. **[개요 문서](./01-overview.md)** 읽기 - 인증 시나리오 이해
2. **[비즈니스 규칙](./02-business-rules.md)** 검토 - 검증 로직 확인
3. **[API 엔드포인트](./03-api-endpoints.md)** 구현 - REST API 개발
4. **[데이터 모델](./04-data-models.md)** 설계 - DB 스키마 생성

---

## 🤝 관련 문서

- **[카테고리 마이그레이션](../category/README.md)** - 카테고리 기능 백엔드 전환
- **[백엔드 아키텍처](../01-main-dart-setup.md)** - 전체 시스템 구조
- **[OpenAPI 자동화](../06-openapi-automation.md)** - 클라이언트 코드 자동 생성
