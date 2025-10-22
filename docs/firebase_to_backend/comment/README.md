# 음성/텍스트 댓글 시스템 (Comment System)

## 📋 개요

SOI 앱의 **음성/텍스트 댓글 시스템**은 사진에 음성 메모 또는 텍스트 댓글을 달고, 작성자의 프로필 이미지를 사진 위에 자유롭게 배치할 수 있는 기능입니다.

현재 **Firebase Firestore + Firebase Storage** 기반으로 구현되어 있으며, 이를 **Spring Boot + PostgreSQL + S3**로 마이그레이션하기 위한 명세서입니다.

---

## 🎯 핵심 기능

### 1. 음성 댓글 시스템

- **음성 녹음**: Flutter `audio_waveforms` 패키지로 실시간 녹음
- **파형 시각화**: 녹음 중 실시간 파형 데이터 수집 (List<double>)
- **프로필 배치**: 사진 위에 작성자 프로필 이미지를 드래그하여 위치 지정
- **상대 좌표**: 0.0~1.0 범위의 상대 좌표로 저장 (디바이스 독립적)
- **Firebase Storage 업로드**: AAC 포맷으로 음성 파일 저장

### 2. 텍스트 댓글 시스템

- **텍스트 입력**: 간단한 텍스트 메시지
- **프로필 배치**: 음성 댓글과 동일하게 위치 지정
- **통합 관리**: 음성 댓글과 같은 데이터 모델 사용 (type 필드로 구분)

### 3. 실시간 스트림

- **Firestore Snapshot**: 댓글 실시간 업데이트
- **캐싱**: Controller에서 사진별 댓글 캐시 관리

### 4. 알림 연동

- **음성 댓글 알림**: 댓글 작성 시 사진 업로더에게 알림
- **NotificationService 연동**: 알림 생성 실패 시에도 댓글은 저장

---

## 🏗️ 현재 아키텍처 (Firebase)

```
Flutter App
    ↓
CommentRecordController (ChangeNotifier)
    ↓
CommentRecordService (비즈니스 로직)
    ↓
CommentRecordRepository
    ↓
Firebase Firestore + Firebase Storage
```

### 데이터 흐름

```
[음성 댓글 생성]
1. 사용자 녹음 (audio_waveforms)
2. 로컬 파일 저장 (.aac)
3. Firebase Storage 업로드
4. Firestore에 메타데이터 저장
5. 알림 생성 (NotificationService)
6. 실시간 스트림으로 UI 업데이트

[텍스트 댓글 생성]
1. 사용자 텍스트 입력
2. Firestore에 직접 저장
3. 알림 생성
4. 실시간 스트림으로 UI 업데이트
```

---

## 🔄 마이그레이션 목표 (Spring Boot)

```
Flutter App
    ↓
CommentRecordController
    ↓
CommentRecordService (수정)
    ↓
CommentRecordRepository (HTTP Client로 변경)
    ↓
Spring Boot REST API
    ↓
PostgreSQL + AWS S3
```

### 주요 변경 사항

| 현재 (Firebase)         | 마이그레이션 후 (Spring Boot)  |
| ----------------------- | ------------------------------ |
| Firestore 실시간 스트림 | WebSocket 또는 SSE             |
| Firebase Storage        | AWS S3 또는 Azure Blob Storage |
| 클라이언트 직접 업로드  | 백엔드를 통한 업로드           |
| Firebase Admin SDK      | Spring Boot + PostgreSQL       |

---

## 📅 4주 마이그레이션 로드맵

### Week 1: API 설계 및 데이터베이스 구축

- [ ] PostgreSQL 스키마 설계 (comments, waveform_data 테이블)
- [ ] REST API 엔드포인트 정의 (8개)
- [ ] DTO 클래스 작성
- [ ] S3 연동 설정

### Week 2: 핵심 API 구현

- [ ] POST /photos/{photoId}/comments/audio - 음성 댓글 생성
- [ ] POST /photos/{photoId}/comments/text - 텍스트 댓글 생성
- [ ] GET /photos/{photoId}/comments - 댓글 조회
- [ ] DELETE /comments/{commentId} - 댓글 삭제

### Week 3: 부가 기능 및 최적화

- [ ] PUT /comments/{commentId}/position - 위치 업데이트
- [ ] PATCH /users/{userId}/comments/profile-image - 프로필 이미지 일괄 업데이트
- [ ] 실시간 업데이트 (WebSocket/SSE)
- [ ] 캐싱 전략 (Redis)

### Week 4: 테스트 및 배포

- [ ] 통합 테스트
- [ ] 성능 테스트 (10,000개 댓글 조회)
- [ ] Flutter 앱 수정 (Repository → HTTP)
- [ ] 점진적 배포 (A/B 테스트)

---

## 🎯 성능 목표

| 항목                   | 목표                     |
| ---------------------- | ------------------------ |
| 음성 댓글 생성         | < 2초 (파일 업로드 포함) |
| 텍스트 댓글 생성       | < 500ms                  |
| 댓글 목록 조회 (100개) | < 500ms                  |
| 실시간 업데이트 지연   | < 1초                    |
| 동시 사용자            | 10,000명                 |

---

## 🔒 보안 규칙

### 1. 권한 관리

- **댓글 생성**: 인증된 사용자만 가능
- **댓글 삭제**: 본인만 가능
- **댓글 수정**: 본인만 프로필 위치 수정 가능

### 2. 파일 업로드 제한

- **파일 크기**: 최대 10MB
- **파일 형식**: AAC, M4A, MP3, WAV만 허용
- **바이러스 검사**: S3 업로드 시 스캔

### 3. Rate Limiting

- **댓글 생성**: 사용자당 분당 10개
- **댓글 조회**: IP당 분당 100회

---

## 📚 문서 구조

이 디렉토리는 다음과 같은 문서들로 구성되어 있습니다:

1. **[01-overview.md](./01-overview.md)** - 주요 시나리오 및 데이터 플로우
2. **[02-business-rules.md](./02-business-rules.md)** - 비즈니스 규칙 및 검증 로직
3. **[03-api-endpoints.md](./03-api-endpoints.md)** - REST API 명세서
4. **[04-data-models.md](./04-data-models.md)** - 데이터베이스 스키마 및 DTO
5. **[05-features.md](./05-features.md)** - 기능별 상세 구현 가이드

---

## 🔗 관련 문서

- [인증 시스템](../auth/README.md)
- [사진 관리 시스템](../photo/README.md)
- [알림 시스템](../notification/README.md)

---

## 💡 주요 고려사항

### 1. 파형 데이터 저장

- **문제**: List<double> 파형 데이터가 크고 자주 조회되지 않음
- **해결**: 별도 테이블(waveform_data)로 분리하여 메인 테이블 크기 최적화

### 2. 상대 좌표 시스템

- **이유**: 디바이스마다 화면 크기가 다름
- **방법**: 0.0~1.0 범위로 정규화하여 저장 (DECIMAL(5,4))

### 3. Soft Delete

- **이유**: 댓글 삭제 후 복구 가능, 통계 데이터 보존
- **방법**: `is_deleted` 플래그 사용

### 4. 실시간 업데이트

- **Firebase**: Firestore Snapshot
- **Spring Boot**: WebSocket 또는 Server-Sent Events (SSE)
- **권장**: 초기에는 폴링, 나중에 WebSocket 추가

---

## 🚀 시작하기

1. [01-overview.md](./01-overview.md)에서 전체 흐름을 파악하세요
2. [02-business-rules.md](./02-business-rules.md)에서 비즈니스 규칙을 확인하세요
3. [03-api-endpoints.md](./03-api-endpoints.md)에서 API 명세를 확인하세요
4. [04-data-models.md](./04-data-models.md)에서 DB 스키마를 설계하세요
5. [05-features.md](./05-features.md)에서 구현 가이드를 참고하세요

---

**작성일**: 2025-01-15  
**버전**: 1.0.0  
**작성자**: SOI Development Team
