# Audio System - Features Specification

## 📖 문서 목적

이 문서는 SOI 앱의 **음성 시스템**을 백엔드로 마이그레이션하기 위한 **기능 명세서**입니다.

각 API의 **Request Parameters**와 **Response**를 평문으로 정리하여, 백엔드 개발자가 자유롭게 구현할 수 있도록 합니다.

---

## 🎯 기능 개요

| 순번 | 기능                 | 엔드포인트                                     | 설명                          |
| ---- | -------------------- | ---------------------------------------------- | ----------------------------- |
| 1    | 음성 업로드          | `POST /api/v1/audios`                          | 음성 파일 + 메타데이터 업로드 |
| 2    | 카테고리 음성 목록   | `GET /api/v1/categories/{categoryId}/audios`   | 카테고리별 음성 조회          |
| 3    | 사용자 음성 목록     | `GET /api/v1/users/{userId}/audios`            | 사용자별 음성 조회            |
| 4    | 음성 상세 조회       | `GET /api/v1/audios/{audioId}`                 | 특정 음성 상세 정보           |
| 5    | 파형 데이터 조회     | `GET /api/v1/audios/{audioId}/waveform`        | 파형 데이터 별도 조회         |
| 6    | 음성 메타데이터 수정 | `PUT /api/v1/audios/{audioId}`                 | 파일명, 설명 수정             |
| 7    | 음성 삭제            | `DELETE /api/v1/audios/{audioId}`              | 음성 및 Storage 파일 삭제     |
| 8    | 실시간 음성 알림     | WebSocket `/ws/categories/{categoryId}/audios` | 새 음성 업로드 실시간 알림    |

---

## 📦 Feature 1: 음성 업로드

### Request

**Method**: `POST /api/v1/audios`

**Content-Type**: `multipart/form-data`

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

**Form Data**:

- **audioFile** (File, Required)

  - 음성 파일 바이너리
  - 형식: AAC (.m4a, .aac), MP3 (.mp3), WAV (.wav)
  - 크기: 1KB ~ 10MB
  - 길이: 1초 ~ 300초 (5분)

- **categoryId** (String, Required)

  - 음성이 속할 카테고리 UUID
  - 현재 사용자가 해당 카테고리의 멤버여야 함

- **waveformData** (Array of Float, Required)

  - 파형 데이터 배열 (Flutter에서 추출)
  - 포인트 개수: 50~500개
  - 각 값 범위: 0.0 ~ 1.0
  - 예: [0.1, 0.5, 0.8, 0.9, 0.7, ...]

- **description** (String, Optional)
  - 음성 설명
  - 최대 500자

### Response

**Success (201 Created)**:

- **id**: 생성된 음성 고유 ID (UUID)
- **categoryId**: 카테고리 ID
- **userId**: 업로더 ID
- **fileName**: 파일명 (자동 생성 또는 원본 파일명)
- **audioUrl**: 음성 파일 공개 URL (Supabase Storage 또는 AWS S3, 여기가 아니더라도 더 편한 것 사용하시면 됩니다!
- **durationInSeconds**: 음성 길이 (초)
- **fileSizeInBytes**: 파일 크기 (bytes)
- **format**: 파일 형식 (AAC, MP3, WAV)
- **status**: 업로드 상태 (UPLOADED)
- **description**: 설명
- **createdAt**: 생성 시각
- **uploadedAt**: 업로드 완료 시각
- **user**: 업로더 정보
  - id: 사용자 ID
  - nickname: 닉네임
  - profileImageUrl: 프로필 이미지 URL

**Error Responses**:

- **400 Bad Request**: 파일 크기/길이/형식 오류, 파형 데이터 검증 실패
- **403 Forbidden**: 카테고리 멤버가 아님
- **429 Too Many Requests**: Rate limiting (분당 10개 제한)
- **500 Internal Server Error**: Storage 업로드 실패

### 비즈니스 규칙

1. **파일 검증**:

   - 크기: 1KB ~ 10MB
   - 형식: MIME type 확인 (audio/aac, audio/mpeg, audio/wav)
   - 길이: 음성 메타데이터에서 추출하여 1~300초 검증

2. **카테고리 멤버십**: 요청자가 해당 카테고리의 멤버인지 확인

3. **Storage 업로드**: Supabase Storage 또는 AWS S3에 업로드 후 공개 URL 생성

4. **파형 저장**: 별도 테이블에 waveformData 저장 (audio와 1:1 관계)

5. **실시간 알림**: 업로드 성공 시 WebSocket으로 카테고리 멤버들에게 알림

## � Feature 2: 카테고리별 음성 목록 조회

### Request

**Method**: `GET /api/v1/categories/{categoryId}/audios`

**Path Parameters**:

- **categoryId** (UUID, Required): 조회할 카테고리 ID

**Query Parameters**:

- **page** (Integer, Optional): 페이지 번호 (0부터 시작, 기본값: 0)
- **size** (Integer, Optional): 페이지당 개수 (1~100, 기본값: 20)
- **sort** (String, Optional): 정렬 방식 (기본값: createdAt,desc)
  - 예: createdAt,desc 또는 fileName,asc

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

- **content**: 음성 목록 배열

  - id: 음성 고유 ID
  - categoryId: 카테고리 ID
  - userId: 업로더 ID
  - fileName: 파일명
  - audioUrl: 음성 파일 공개 URL
  - durationInSeconds: 음성 길이 (초)
  - fileSizeInBytes: 파일 크기 (bytes)
  - format: 파일 형식 (AAC, MP3, WAV)
  - status: 업로드 상태 (UPLOADED)
  - description: 설명
  - createdAt: 생성 시각
  - uploadedAt: 업로드 완료 시각
  - user: 업로더 정보 (id, nickname, profileImageUrl)

- **pageable**: 페이징 정보

  - pageNumber: 현재 페이지 번호
  - pageSize: 페이지 크기
  - sort: 정렬 정보

- **totalElements**: 전체 요소 개수
- **totalPages**: 전체 페이지 수
- **last**: 마지막 페이지 여부
- **first**: 첫 페이지 여부
- **empty**: 빈 결과 여부

**Error Responses**:

- **404 Not Found**: 카테고리가 존재하지 않음
- **403 Forbidden**: Private 카테고리인데 멤버가 아님

### 비즈니스 규칙

1. **카테고리 멤버십**: 요청자가 해당 카테고리의 멤버인지 확인 (Public 카테고리는 제외 가능)

2. **필터링**: status가 UPLOADED인 음성만 조회

3. **정렬**: 기본적으로 최신순 (createdAt DESC)

4. **페이징**: 최대 100개까지 한번에 조회 가능

5. **성능 최적화**: 사용자 정보를 함께 조회하여 N+1 문제 방지

## 👤 Feature 3: 사용자별 음성 목록 조회

### Request

**Method**: `GET /api/v1/users/{userId}/audios` 또는 `GET /api/v1/users/me/audios`

**Path Parameters**:

- **userId** (UUID, Required): 조회할 사용자 ID
  - `me`: 현재 로그인한 사용자 (특별 키워드)

**Query Parameters**:

- **page** (Integer, Optional): 페이지 번호 (0부터 시작, 기본값: 0)
- **size** (Integer, Optional): 페이지당 개수 (1~100, 기본값: 20)
- **sort** (String, Optional): 정렬 방식 (기본값: createdAt,desc)

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

- **content**: 음성 목록 배열

  - id: 음성 고유 ID
  - categoryId: 카테고리 ID
  - categoryName: 카테고리 이름 (추가 정보)
  - userId: 업로더 ID
  - fileName: 파일명
  - audioUrl: 음성 파일 공개 URL
  - durationInSeconds: 음성 길이 (초)
  - fileSizeInBytes: 파일 크기 (bytes)
  - format: 파일 형식 (AAC, MP3, WAV)
  - status: 업로드 상태 (UPLOADED)
  - description: 설명
  - createdAt: 생성 시각
  - uploadedAt: 업로드 완료 시각

- **pageable**: 페이징 정보
- **totalElements**: 전체 요소 개수
- **totalPages**: 전체 페이지 수
- **last**: 마지막 페이지 여부
- **first**: 첫 페이지 여부

**Error Responses**:

- **404 Not Found**: 사용자가 존재하지 않음
- **403 Forbidden**: 다른 사용자의 private 음성을 조회하려는 경우

### 비즈니스 규칙

1. **접근 권한**:

   - 자신의 음성은 모두 조회 가능
   - 다른 사용자의 음성은 자신이 멤버인 카테고리의 음성만 조회 가능

2. **카테고리 정보 포함**: 사용자 관점이므로 카테고리 이름도 함께 제공

3. **필터링**: status가 UPLOADED인 음성만 조회

4. **정렬**: 기본적으로 최신순 (createdAt DESC)

5. **성능 최적화**: 카테고리 정보를 함께 조회하여 N+1 문제 방지

---

    """)

## 🔍 Feature 4: 음성 상세 조회

### Request

**Method**: `GET /api/v1/audios/{audioId}`

**Path Parameters**:

- **audioId** (UUID, Required): 조회할 음성 ID

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

- **id**: 음성 고유 ID
- **categoryId**: 카테고리 ID
- **categoryName**: 카테고리 이름
- **userId**: 업로더 ID
- **userName**: 업로더 닉네임
- **userProfileImageUrl**: 업로더 프로필 이미지
- **fileName**: 파일명
- **audioUrl**: 음성 파일 공개 URL
- **durationInSeconds**: 음성 길이 (초)
- **fileSizeInBytes**: 파일 크기 (bytes)
- **format**: 파일 형식 (AAC, MP3, WAV)
- **status**: 업로드 상태 (UPLOADED)
- **description**: 설명
- **createdAt**: 생성 시각
- **uploadedAt**: 업로드 완료 시각
- **viewCount**: 재생 횟수 (Optional)

**Error Responses**:

- **404 Not Found**: 음성이 존재하지 않음
- **403 Forbidden**: 카테고리 멤버가 아니어서 접근 불가

### 비즈니스 규칙

1. **접근 권한**: 요청자가 해당 음성의 카테고리 멤버인지 확인

2. **완전한 정보**: 카테고리와 사용자 정보를 포함한 전체 정보 반환

3. **재생 횟수**: 조회 시 viewCount 증가 (Optional)

4. **성능 최적화**: 카테고리, 사용자 정보를 함께 조회

## 📊 Feature 5: 파형 데이터 조회

### Request

**Method**: `GET /api/v1/audios/{audioId}/waveform`

**Path Parameters**:

- **audioId** (UUID, Required): 조회할 음성 ID

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

- **audioId**: 음성 ID
- **waveformData**: 파형 데이터 배열
  - Float 배열 (0.0 ~ 1.0)
  - 포인트 개수: 50~500개 (보통 100개)
- **sampleCount**: 전체 샘플 포인트 개수
- **createdAt**: 파형 생성 시각

**Error Responses**:

- **404 Not Found**: 음성 또는 파형 데이터가 존재하지 않음
- **403 Forbidden**: 카테고리 멤버가 아니어서 접근 불가

### 비즈니스 규칙

1. **별도 조회**: 파형 데이터는 크기가 크므로 별도 엔드포인트로 제공

2. **캐싱**: 파형 데이터는 변경되지 않으므로 클라이언트/서버 캐싱 권장 (Cache-Control 헤더)

3. **접근 권한**: 음성의 카테고리 멤버만 조회 가능

4. **성능 최적화**: 데이터베이스에 JSONB 또는 별도 테이블로 저장

## ✏️ Feature 6: 음성 정보 수정

### Request

**Method**: `PUT /api/v1/audios/{audioId}`

**Path Parameters**:

- **audioId** (UUID, Required): 수정할 음성 ID

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}
- `Content-Type`: application/json

**Body**:

- **fileName** (String, Optional): 새 파일명 (1~50자)
- **description** (String, Optional): 새 설명 (최대 500자)

### Response

**Success (200 OK)**:

- **id**: 음성 ID
- **fileName**: 수정된 파일명
- **description**: 수정된 설명
- **updatedAt**: 수정 시각
- (나머지 음성 정보 동일)

**Error Responses**:

- **400 Bad Request**: 파일명 길이 초과, 설명 길이 초과
- **403 Forbidden**: 작성자가 아니어서 수정 불가
- **404 Not Found**: 음성이 존재하지 않음

### 비즈니스 규칙

1. **작성자 권한**: 본인이 업로드한 음성만 수정 가능

2. **파일명 검증**: 1~50자, 빈 문자열 불가

3. **설명 검증**: 최대 500자

4. **수정 불가 필드**: audioUrl, durationInSeconds, fileSizeInBytes, format 등 메타데이터는 수정 불가

5. **업데이트 시각**: updatedAt 필드 자동 갱신

## �️ Feature 7: 음성 삭제

### Request

**Method**: `DELETE /api/v1/audios/{audioId}`

**Path Parameters**:

- **audioId** (UUID, Required): 삭제할 음성 ID

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (204 No Content)**:

- Body 없음 (성공적으로 삭제됨)

**Error Responses**:

- **403 Forbidden**: 작성자가 아니어서 삭제 불가
- **404 Not Found**: 음성이 존재하지 않음
- **500 Internal Server Error**: Storage 파일 삭제 실패

### 비즈니스 규칙

1. **작성자 권한**: 본인이 업로드한 음성만 삭제 가능

2. **Cascade 삭제**:

   - 데이터베이스 레코드 삭제
   - 파형 데이터 삭제
   - Storage 파일 삭제 (Supabase Storage 또는 AWS S3)
   - 관련 댓글/재생 기록 삭제 (Optional)

3. **트랜잭션**: 데이터베이스와 Storage 삭제는 원자적으로 처리

4. **비동기 처리**: Storage 파일 삭제는 비동기로 처리 가능 (실패 시 재시도)

5. **실시간 알림**: 삭제 시 WebSocket으로 카테고리 멤버들에게 알림

## 🎤 Feature 8: 실시간 음성 알림 (WebSocket)

### 연결

**Protocol**: WebSocket + STOMP

**Endpoint**: `ws://api.soi.com/ws` 또는 `wss://api.soi.com/ws`

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### 구독 (Subscribe)

**Topic**: `/topic/categories/{categoryId}/audios`

- 특정 카테고리의 음성 관련 실시간 이벤트 수신
- 카테고리 멤버만 구독 가능

### 메시지 형식

**새 음성 업로드 알림** (type: NEW_AUDIO):

- **type**: 이벤트 타입 ("NEW_AUDIO")
- **audioId**: 새로 업로드된 음성 ID
- **categoryId**: 카테고리 ID
- **userId**: 업로더 ID
- **userName**: 업로더 닉네임
- **fileName**: 파일명
- **durationInSeconds**: 음성 길이 (초)
- **createdAt**: 생성 시각

**음성 삭제 알림** (type: DELETE_AUDIO):

- **type**: 이벤트 타입 ("DELETE_AUDIO")
- **audioId**: 삭제된 음성 ID
- **categoryId**: 카테고리 ID
- **userId**: 삭제한 사용자 ID
- **deletedAt**: 삭제 시각

**음성 수정 알림** (type: UPDATE_AUDIO):

- **type**: 이벤트 타입 ("UPDATE_AUDIO")
- **audioId**: 수정된 음성 ID
- **categoryId**: 카테고리 ID
- **fileName**: 새 파일명
- **updatedAt**: 수정 시각

### 비즈니스 규칙

1. **멤버십 확인**: WebSocket 연결 시 카테고리 멤버 여부 확인

2. **이벤트 종류**:

   - NEW_AUDIO: 새 음성 업로드
   - DELETE_AUDIO: 음성 삭제
   - UPDATE_AUDIO: 음성 정보 수정

3. **재연결 처리**: 연결 끊김 시 자동 재연결 및 누락 메시지 동기화

4. **브로드캐스트**: 같은 카테고리의 모든 멤버에게 동시 전송

5. **성능**: Redis Pub/Sub 또는 메시지 큐를 사용한 확장 가능한 구조

---

## 🎯 API 엔드포인트 요약

| Method    | Endpoint                                    | 설명                                   |
| --------- | ------------------------------------------- | -------------------------------------- |
| POST      | /api/v1/audios                              | 음성 업로드 (파일 + 메타데이터 + 파형) |
| GET       | /api/v1/categories/{categoryId}/audios      | 카테고리별 음성 목록 (페이징)          |
| GET       | /api/v1/users/{userId}/audios               | 사용자별 음성 목록 (페이징)            |
| GET       | /api/v1/audios/{audioId}                    | 음성 상세 조회                         |
| GET       | /api/v1/audios/{audioId}/waveform           | 파형 데이터 조회                       |
| PUT       | /api/v1/audios/{audioId}                    | 음성 정보 수정                         |
| DELETE    | /api/v1/audios/{audioId}                    | 음성 삭제                              |
| WebSocket | /ws → /topic/categories/{categoryId}/audios | 실시간 알림                            |

---

## 📝 공통 규칙

### 인증

- 모든 API는 Firebase ID Token 인증 필요
- Header: `Authorization: Bearer {token}`

### 에러 응답 형식

- **400 Bad Request**: 요청 파라미터 검증 실패
- **401 Unauthorized**: 인증 토큰 없음 또는 만료
- **403 Forbidden**: 권한 없음
- **404 Not Found**: 리소스 없음
- **429 Too Many Requests**: Rate limit 초과
- **500 Internal Server Error**: 서버 오류

### 페이징 공통 파라미터

- **page**: 페이지 번호 (0부터 시작, 기본값: 0)
- **size**: 페이지 크기 (1~100, 기본값: 20)
- **sort**: 정렬 (기본값: createdAt,desc)

### 날짜/시간 형식

- ISO 8601 형식 사용 (예: 2025-10-22T14:30:00Z)
- 서버는 UTC 기준, 클라이언트에서 로컬 시간 변환

### 파일 크기 및 제한

- 음성 파일: 최대 10MB
- 음성 길이: 최대 5분 (300초)
- 파일명: 1~50자
- 설명: 최대 500자
- 파형 포인트: 50~500개
