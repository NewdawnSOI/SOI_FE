# Category Photo Management - Features Specification

## 📖 문서 목적

이 문서는 SOI 앱의 **카테고리 사진 관리 시스템**을 백엔드로 마이그레이션하기 위한 **기능 명세서**입니다.

각 API의 **Request Parameters**와 **Response**를 평문으로 정리하여, 백엔드 개발자가 자유롭게 구현할 수 있도록 합니다.

---

## 🎯 기능 개요

| 순번 | 기능                       | 엔드포인트                                      | 설명                                |
| ---- | -------------------------- | ----------------------------------------------- | ----------------------------------- |
| 1    | 사진 업로드                | `POST /api/v1/photos`                           | 이미지 + 음성 메모 업로드           |
| 2    | 전체 사진 목록 (페이징)    | `GET /api/v1/photos`                            | 모든 카테고리 사진 무한 스크롤 조회 |
| 3    | 카테고리별 사진 목록       | `GET /api/v1/categories/{categoryId}/photos`    | 특정 카테고리의 사진 조회           |
| 4    | 사용자별 사진 목록         | `GET /api/v1/users/{userId}/photos`             | 특정 사용자가 업로드한 사진 조회    |
| 5    | 사진 상세 조회             | `GET /api/v1/photos/{photoId}`                  | 특정 사진의 상세 정보 조회          |
| 6    | 사진 정보 수정             | `PUT /api/v1/photos/{photoId}`                  | 사진 캡션 수정                      |
| 7    | 사진 삭제 (소프트 삭제)    | `DELETE /api/v1/photos/{photoId}`               | 사진을 삭제 상태로 변경 (30일 유지) |
| 8    | 삭제된 사진 목록 조회      | `GET /api/v1/users/{userId}/photos/deleted`     | 사용자가 삭제한 사진 목록 조회      |
| 9    | 사진 복원                  | `POST /api/v1/photos/{photoId}/restore`         | 삭제된 사진을 복원                  |
| 10   | 사진 통계 조회             | `GET /api/v1/categories/{categoryId}/photos/stats` | 카테고리 사진 통계 정보          |
| 11   | 실시간 사진 업데이트 알림  | WebSocket `/ws → /topic/categories/{categoryId}/photos` | 사진 업로드/삭제 실시간 알림 |

---

## 📦 Feature 1: 사진 업로드 (이미지 + 음성 메모)

### Request

**Method**: `POST /api/v1/photos`

**Content-Type**: `multipart/form-data`

**Headers**:
- `Authorization`: Bearer {Firebase ID Token}

**Form Data**:

- **imageFile** (File, Required)
  - 이미지 파일 바이너리
  - 형식: JPEG (.jpg, .jpeg), PNG (.png), HEIC (.heic)
  - 크기: 1KB ~ 10MB
  - 압축: 클라이언트에서 사전 압축 권장

- **audioFile** (File, Optional)
  - 음성 메모 파일 바이너리
  - 형식: AAC (.m4a, .aac), MP3 (.mp3)
  - 크기: 1KB ~ 10MB
  - 길이: 1초 ~ 300초 (5분)

- **categoryId** (String, Required)
  - 사진이 속할 카테고리 UUID
  - 현재 사용자가 해당 카테고리의 멤버여야 함

- **userId** (String, Required)
  - 업로더 사용자 ID

- **userIds** (Array of String, Required)
  - 카테고리 멤버 ID 목록
  - userId가 포함되어야 함

- **caption** (String, Optional)
  - 사진 설명/게시글
  - 최대 1000자

- **waveformData** (Array of Float, Optional - audioFile이 있는 경우 권장)
  - 음성 파형 데이터 배열 (클라이언트에서 추출)
  - 포인트 개수: 50~500개
  - 각 값 범위: 0.0 ~ 1.0
  - 예: [0.1, 0.5, 0.8, 0.9, 0.7, ...]

- **audioDuration** (Integer, Optional - audioFile이 있는 경우)
  - 음성 길이 (초 단위)
  - 범위: 1 ~ 300

### Response

**Success (201 Created)**:

- **photoId**: 생성된 사진 고유 ID (UUID)
- **imageUrl**: 이미지 파일 공개 URL (Supabase Storage 또는 AWS S3)
- **audioUrl**: 음성 파일 공개 URL (audioFile이 있는 경우)
- **categoryId**: 카테고리 ID
- **userId**: 업로더 ID
- **userIds**: 카테고리 멤버 ID 목록
- **caption**: 사진 설명
- **status**: 사진 상태 (ACTIVE)
- **hasAudio**: 음성 메모 포함 여부 (Boolean)
- **waveformData**: 파형 데이터 (audioFile이 있는 경우)
- **duration**: 음성 길이 (초, audioFile이 있는 경우)
- **createdAt**: 생성 시각 (ISO 8601 UTC)
- **user**: 업로더 정보
  - id: 사용자 ID
  - nickname: 닉네임
  - profileImageUrl: 프로필 이미지 URL

**Error Responses**:

- **400 Bad Request**: 파일 크기/형식 오류, 필수 필드 누락, userIds 검증 실패
- **403 Forbidden**: 카테고리 멤버가 아님 ("카테고리 멤버만 사진을 업로드할 수 있습니다.")
- **404 Not Found**: 카테고리가 존재하지 않음
- **413 Payload Too Large**: 파일 크기 초과 ("이미지 파일 크기는 10MB를 초과할 수 없습니다.")
- **500 Internal Server Error**: Storage 업로드 실패

### 비즈니스 규칙

1. **파일 검증**:
   - 이미지 크기: 1KB ~ 10MB
   - 음성 크기: 1KB ~ 10MB
   - 이미지 형식: MIME type 확인 (image/jpeg, image/png, image/heic)
   - 음성 형식: MIME type 확인 (audio/aac, audio/mpeg)
   - 음성 길이: 1~300초 검증

2. **카테고리 멤버십 검증**:
   - 요청자(userId)가 해당 카테고리의 멤버인지 확인
   - 멤버가 아닌 경우 403 Forbidden 반환

3. **UserIds 검증**:
   - userIds 배열이 비어있지 않은지 확인
   - userId가 userIds에 포함되어 있는지 확인
   - 검증 실패 시 400 Bad Request ("올바른 사용자 목록이 필요합니다.")

4. **Storage 업로드**:
   - 이미지를 Storage에 업로드하고 공개 URL 생성
   - 음성 파일이 있는 경우 별도 업로드
   - 업로드 실패 시 트랜잭션 롤백 필요

5. **파형 데이터 처리**:
   - waveformData가 제공된 경우 별도 테이블에 저장 (photos와 1:1 관계)
   - 제공되지 않고 audioFile이 있는 경우, 서버에서 추출 (Optional)

6. **카테고리 최신 사진 정보 업데이트**:
   - categories 테이블의 lastPhotoUploadedBy, lastPhotoUploadedAt 업데이트
   - 카테고리 활동 시간 갱신

7. **카테고리 대표 사진 자동 업데이트** (중요 비즈니스 로직):
   - **케이스 A**: 카테고리에 대표사진이 없는 경우 (첫 번째 사진)
     - 업로드된 사진을 자동으로 대표사진으로 설정
   - **케이스 B**: 카테고리에 이미 대표사진이 있는 경우
     - 현재 대표사진이 "자동 설정"된 것인지 확인 (카테고리의 기존 사진 중 하나인지 체크)
     - 자동 설정된 경우: 최신 업로드 사진으로 대표사진 자동 업데이트
     - 사용자가 직접 설정한 경우: 대표사진 유지
   - 대표사진 업데이트 시 관련 알림의 썸네일도 함께 업데이트

8. **실시간 알림 생성**:
   - 사진 업로드 성공 시 notifications 테이블에 레코드 생성
   - 알림 타입: PHOTO_ADDED
   - 카테고리 멤버들에게 WebSocket으로 실시간 알림 전송
   - 알림 생성 실패는 전체 업로드를 실패시키지 않음 (로그만 기록)

9. **트랜잭션 처리**:
   - Storage 업로드 → DB 저장 → 알림 생성 순서로 처리
   - Storage 업로드 실패 시 전체 실패
   - DB 저장 실패 시 업로드된 파일 삭제
   - 알림 생성 실패는 무시 (업로드는 성공으로 처리)

---

## 📋 Feature 2: 전체 사진 목록 조회 (페이지네이션)

### Request

**Method**: `GET /api/v1/photos`

**Query Parameters**:

- **categoryIds** (Array of String, Required)
  - 조회할 카테고리 ID 목록
  - 최소 1개 이상 필요
  - 예: categoryIds=uuid1&categoryIds=uuid2&categoryIds=uuid3

- **limit** (Integer, Optional)
  - 페이지당 사진 개수
  - 범위: 1 ~ 100
  - 기본값: 20

- **startAfterPhotoId** (String, Optional)
  - 이전 페이지의 마지막 사진 ID
  - 무한 스크롤의 커서 역할
  - 첫 페이지에서는 null

**Headers**:
- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

- **photos**: 사진 목록 배열
  - id: 사진 고유 ID
  - imageUrl: 이미지 공개 URL
  - audioUrl: 음성 공개 URL (있는 경우)
  - categoryId: 카테고리 ID
  - userId: 업로더 ID
  - userIds: 멤버 ID 목록
  - caption: 사진 설명
  - status: 사진 상태 (ACTIVE)
  - hasAudio: 음성 포함 여부
  - duration: 음성 길이 (초)
  - createdAt: 생성 시각
  - user: 업로더 정보 (id, nickname, profileImageUrl)

- **lastPhotoId**: 마지막 사진 ID (다음 페이지 요청 시 사용)
- **hasMore**: 다음 페이지 존재 여부 (Boolean)

**Error Responses**:

- **400 Bad Request**: categoryIds 누락, limit 범위 오류
- **403 Forbidden**: 카테고리 접근 권한 없음

### 비즈니스 규칙

1. **입력 검증**:
   - categoryIds가 비어있는 경우 400 에러 ("카테고리 ID 목록이 필요합니다.")
   - limit이 1~100 범위를 벗어난 경우 400 에러 ("제한값은 1과 100 사이여야 합니다.")

2. **카테고리 멤버십 확인**:
   - 요청자가 모든 categoryIds의 멤버인지 확인
   - 접근 권한이 없는 카테고리가 있으면 403 Forbidden

3. **페이지네이션 로직**:
   - startAfterPhotoId가 있는 경우: 해당 사진 이후의 사진들을 조회
   - startAfterPhotoId가 없는 경우: 첫 페이지 조회
   - limit + 1개를 조회하여 hasMore 판단 (limit개만 반환)

4. **차단된 사용자 필터링** (중요):
   - 요청자가 차단한 사용자들의 사진을 필터링
   - 단방향 필터링: "내가 차단한 사용자"의 사진만 제외
   - 차단 테이블 조인 또는 서브쿼리로 필터링

5. **활성 사진만 조회**:
   - status = ACTIVE인 사진만 반환
   - DELETED, ARCHIVED, REPORTED 상태는 제외

6. **정렬**:
   - createdAt 기준 내림차순 (최신순)
   - 동일 시간인 경우 photoId 기준 정렬

7. **성능 최적화**:
   - 사용자 정보를 LEFT JOIN으로 함께 조회 (N+1 문제 방지)
   - 카테고리별 조회를 병렬로 처리 가능
   - 인덱스: (categoryId, createdAt DESC, status)

---

## 🖼️ Feature 3: 카테고리별 사진 목록 조회

### Request

**Method**: `GET /api/v1/categories/{categoryId}/photos`

**Path Parameters**:
- **categoryId** (UUID, Required): 조회할 카테고리 ID

**Query Parameters**:
- **status** (String, Optional): 사진 상태 필터 (ACTIVE, DELETED, ARCHIVED)
  - 기본값: ACTIVE

**Headers**:
- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

- **photos**: 사진 목록 배열
  - id: 사진 고유 ID
  - imageUrl: 이미지 공개 URL
  - audioUrl: 음성 공개 URL (있는 경우)
  - categoryId: 카테고리 ID
  - userId: 업로더 ID
  - caption: 사진 설명
  - status: 사진 상태
  - hasAudio: 음성 포함 여부
  - duration: 음성 길이 (초)
  - createdAt: 생성 시각
  - user: 업로더 정보 (id, nickname, profileImageUrl)

**Error Responses**:

- **400 Bad Request**: categoryId 형식 오류
- **403 Forbidden**: 카테고리 멤버가 아님
- **404 Not Found**: 카테고리가 존재하지 않음

### 비즈니스 규칙

1. **입력 검증**:
   - categoryId가 비어있는 경우 400 에러 ("카테고리 ID가 필요합니다.")
   - status가 유효한 값인지 확인 (ACTIVE, DELETED, ARCHIVED)

2. **카테고리 멤버십 확인**:
   - 요청자가 해당 카테고리의 멤버인지 확인
   - Private 카테고리는 멤버만 조회 가능
   - Public 카테고리는 누구나 조회 가능 (Optional)

3. **차단된 사용자 필터링**:
   - 요청자가 차단한 사용자들의 사진 제외
   - 단방향 필터링

4. **정렬**:
   - createdAt 기준 내림차순 (최신순)

5. **성능 최적화**:
   - 사용자 정보를 LEFT JOIN으로 함께 조회
   - 인덱스: (categoryId, status, createdAt DESC)

---

## 👤 Feature 4: 사용자별 사진 목록 조회

### Request

**Method**: `GET /api/v1/users/{userId}/photos` 또는 `GET /api/v1/users/me/photos`

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

- **content**: 사진 목록 배열
  - id: 사진 고유 ID
  - imageUrl: 이미지 공개 URL
  - audioUrl: 음성 공개 URL (있는 경우)
  - categoryId: 카테고리 ID
  - categoryName: 카테고리 이름 (추가 정보)
  - userId: 업로더 ID
  - caption: 사진 설명
  - status: 사진 상태 (ACTIVE)
  - hasAudio: 음성 포함 여부
  - duration: 음성 길이 (초)
  - createdAt: 생성 시각

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

- **404 Not Found**: 사용자가 존재하지 않음
- **403 Forbidden**: 다른 사용자의 private 사진을 조회하려는 경우

### 비즈니스 규칙

1. **접근 권한**:
   - 자신의 사진(userId = me): 모든 카테고리의 사진 조회 가능
   - 다른 사용자의 사진: 자신이 멤버인 카테고리의 사진만 조회 가능

2. **카테고리 정보 포함**:
   - 사용자 관점이므로 카테고리 이름도 함께 제공
   - categories 테이블 JOIN 필요

3. **차단된 사용자 필터링**:
   - 요청자가 차단한 사용자의 사진 제외
   - userId가 본인인 경우는 필터링 불필요

4. **활성 사진만 조회**:
   - status = ACTIVE인 사진만 반환

5. **정렬**:
   - 기본적으로 최신순 (createdAt DESC)

6. **성능 최적화**:
   - 카테고리 정보를 LEFT JOIN으로 함께 조회 (N+1 문제 방지)
   - 인덱스: (userId, status, createdAt DESC)

---

## 🔍 Feature 5: 사진 상세 조회

### Request

**Method**: `GET /api/v1/photos/{photoId}`

**Path Parameters**:
- **photoId** (UUID, Required): 조회할 사진 ID

**Query Parameters**:
- **categoryId** (String, Optional but Recommended): 카테고리 ID
  - 성능 최적화를 위해 제공 권장

**Headers**:
- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

- **id**: 사진 고유 ID
- **imageUrl**: 이미지 공개 URL
- **audioUrl**: 음성 공개 URL (있는 경우)
- **categoryId**: 카테고리 ID
- **categoryName**: 카테고리 이름
- **userId**: 업로더 ID
- **userName**: 업로더 닉네임
- **userProfileImageUrl**: 업로더 프로필 이미지
- **userIds**: 카테고리 멤버 ID 목록
- **caption**: 사진 설명
- **status**: 사진 상태
- **hasAudio**: 음성 포함 여부
- **waveformData**: 파형 데이터 (음성이 있는 경우)
- **duration**: 음성 길이 (초, 음성이 있는 경우)
- **createdAt**: 생성 시각
- **viewCount**: 조회 횟수 (Optional)

**Error Responses**:

- **404 Not Found**: 사진이 존재하지 않음
- **403 Forbidden**: 카테고리 멤버가 아니어서 접근 불가

### 비즈니스 규칙

1. **입력 검증**:
   - photoId가 비어있는 경우 400 에러
   - categoryId가 제공된 경우 함께 검증

2. **접근 권한 확인**:
   - 요청자가 해당 사진의 카테고리 멤버인지 확인
   - 멤버가 아닌 경우 403 Forbidden

3. **완전한 정보 제공**:
   - 카테고리, 사용자, 파형 데이터 포함
   - 모든 관련 정보를 한 번의 요청으로 조회

4. **조회 횟수 증가** (Optional):
   - viewCount 컬럼 +1 증가
   - 비동기 처리 권장 (조회 성능에 영향 없도록)

5. **성능 최적화**:
   - 카테고리, 사용자 정보를 JOIN으로 함께 조회
   - categoryId가 제공된 경우 복합 인덱스 활용

---

## ✏️ Feature 6: 사진 정보 수정

### Request

**Method**: `PUT /api/v1/photos/{photoId}`

**Path Parameters**:
- **photoId** (UUID, Required): 수정할 사진 ID

**Headers**:
- `Authorization`: Bearer {Firebase ID Token}
- `Content-Type`: application/json

**Body**:
- **caption** (String, Optional): 새 사진 설명 (최대 1000자)
- **categoryId** (String, Optional): 카테고리 ID (권한 확인용)

### Response

**Success (200 OK)**:

- **id**: 사진 ID
- **caption**: 수정된 설명
- **updatedAt**: 수정 시각
- (나머지 사진 정보 동일)

**Error Responses**:

- **400 Bad Request**: caption 길이 초과 (1000자)
- **403 Forbidden**: 작성자가 아니어서 수정 불가 ("사진을 수정할 권한이 없습니다.")
- **404 Not Found**: 사진이 존재하지 않음 ("사진을 찾을 수 없습니다.")

### 비즈니스 규칙

1. **작성자 권한 확인**:
   - photo.userId == 요청자 userId 확인
   - 본인이 업로드한 사진만 수정 가능

2. **Caption 검증**:
   - 최대 1000자 제한
   - 빈 문자열 허용 (caption 제거 가능)

3. **수정 불가 필드**:
   - imageUrl, audioUrl, categoryId, userIds 등 메타데이터는 수정 불가
   - 오직 caption만 수정 가능

4. **업데이트 시각**:
   - updatedAt 필드 자동 갱신 (현재 시각)

5. **실시간 알림** (Optional):
   - 사진 수정 시 WebSocket으로 알림 전송 가능
   - UPDATE_PHOTO 이벤트

---

## 🗑️ Feature 7: 사진 삭제 (소프트 삭제)

### Request

**Method**: `DELETE /api/v1/photos/{photoId}`

**Path Parameters**:
- **photoId** (UUID, Required): 삭제할 사진 ID

**Query Parameters**:
- **categoryId** (String, Required): 카테고리 ID
- **permanent** (Boolean, Optional): 영구 삭제 여부 (기본값: false)

**Headers**:
- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (204 No Content)**: Body 없음 (성공적으로 삭제됨)

**Error Responses**:

- **403 Forbidden**: 작성자가 아니어서 삭제 불가 ("사진을 삭제할 권한이 없습니다.")
- **404 Not Found**: 사진이 존재하지 않음 ("사진을 찾을 수 없습니다.")
- **500 Internal Server Error**: Storage 파일 삭제 실패

### 비즈니스 규칙

1. **작성자 권한 확인**:
   - photo.userId == 요청자 userId 확인
   - 본인이 업로드한 사진만 삭제 가능

2. **소프트 삭제 (permanent = false, 기본값)**:
   - status를 ACTIVE → DELETED로 변경
   - deletedAt 필드에 현재 시각 설정
   - Storage 파일은 유지 (30일 후 배치로 삭제)
   - 30일 이내에는 복원 가능

3. **영구 삭제 (permanent = true)**:
   - DB 레코드 완전 삭제
   - Storage 파일도 함께 삭제 (imageUrl, audioUrl)
   - 파형 데이터도 함께 삭제
   - 복원 불가능

4. **Cascade 삭제**:
   - 관련 파형 데이터 삭제 (waveform 테이블)
   - 관련 댓글 삭제 (Optional)
   - 관련 좋아요/반응 삭제 (Optional)

5. **카테고리 대표 사진 업데이트**:
   - 삭제된 사진이 현재 카테고리의 대표사진인지 확인
   - 대표사진인 경우: 카테고리의 최신 사진으로 자동 업데이트
   - 대표사진이 아닌 경우: 변경 없음

6. **트랜잭션 처리**:
   - 소프트 삭제: DB 업데이트만 트랜잭션 처리
   - 영구 삭제: DB 삭제 → Storage 삭제 순서로 처리
   - Storage 삭제는 비동기로 처리 가능 (실패 시 재시도)

7. **실시간 알림**:
   - 사진 삭제 시 WebSocket으로 카테고리 멤버들에게 알림
   - DELETE_PHOTO 이벤트

---

## 🔄 Feature 8: 삭제된 사진 목록 조회

### Request

**Method**: `GET /api/v1/users/{userId}/photos/deleted` 또는 `GET /api/v1/users/me/photos/deleted`

**Path Parameters**:
- **userId** (UUID, Required): 조회할 사용자 ID
  - `me`: 현재 로그인한 사용자

**Query Parameters**:
- **page** (Integer, Optional): 페이지 번호 (0부터 시작, 기본값: 0)
- **size** (Integer, Optional): 페이지당 개수 (1~100, 기본값: 20)

**Headers**:
- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

- **content**: 삭제된 사진 목록 배열
  - id: 사진 고유 ID
  - imageUrl: 이미지 공개 URL
  - audioUrl: 음성 공개 URL (있는 경우)
  - categoryId: 카테고리 ID
  - categoryName: 카테고리 이름
  - caption: 사진 설명
  - status: 사진 상태 (DELETED)
  - deletedAt: 삭제 시각
  - expiresAt: 영구 삭제 예정 시각 (deletedAt + 30일)
  - daysUntilPermanentDelete: 영구 삭제까지 남은 일수

- **pageable**: 페이징 정보
- **totalElements**: 전체 요소 개수
- **totalPages**: 전체 페이지 수

**Error Responses**:

- **400 Bad Request**: userId 형식 오류
- **403 Forbidden**: 다른 사용자의 삭제된 사진을 조회하려는 경우
- **404 Not Found**: 사용자가 존재하지 않음

### 비즈니스 규칙

1. **접근 권한**:
   - 본인의 삭제된 사진만 조회 가능
   - userId가 요청자와 다른 경우 403 Forbidden

2. **필터링**:
   - status = DELETED인 사진만 조회
   - deletedAt이 있는 사진만 조회

3. **정렬**:
   - deletedAt 기준 내림차순 (최근 삭제된 것부터)

4. **영구 삭제 예정 정보**:
   - expiresAt = deletedAt + 30일
   - daysUntilPermanentDelete = (expiresAt - 현재 시각).days
   - UI에서 사용자에게 복원 가능 기간 표시

5. **카테고리 정보 포함**:
   - 카테고리 이름 함께 제공 (복원 시 참고용)

---

## ♻️ Feature 9: 사진 복원

### Request

**Method**: `POST /api/v1/photos/{photoId}/restore`

**Path Parameters**:
- **photoId** (UUID, Required): 복원할 사진 ID

**Headers**:
- `Authorization`: Bearer {Firebase ID Token}
- `Content-Type`: application/json

**Body**:
- **categoryId** (String, Required): 카테고리 ID (권한 확인용)

### Response

**Success (200 OK)**:

- **id**: 복원된 사진 ID
- **status**: 사진 상태 (ACTIVE)
- **restoredAt**: 복원 시각
- (나머지 사진 정보 동일)

**Error Responses**:

- **400 Bad Request**: 필수 필드 누락, 삭제되지 않은 사진 복원 시도
- **403 Forbidden**: 권한 없음 ("사진을 복원할 권한이 없습니다.")
- **404 Not Found**: 사진이 존재하지 않음 ("사진을 찾을 수 없습니다.")

### 비즈니스 규칙

1. **사진 상태 확인**:
   - photo.status == DELETED 인지 확인
   - ACTIVE 상태 사진은 복원 불가 (400 에러: "삭제된 사진만 복원할 수 있습니다.")

2. **권한 확인** (두 가지 케이스):
   - **케이스 A**: 사진 소유자인 경우 (photo.userId == 요청자 userId)
     - 복원 가능
   - **케이스 B**: 카테고리 멤버인 경우
     - 복원 가능 (Optional, 정책에 따라 조정 가능)

3. **복원 실행**:
   - status를 DELETED → ACTIVE로 변경
   - deletedAt 필드를 NULL로 설정
   - restoredAt 필드에 현재 시각 설정 (Optional)

4. **카테고리 최신 사진 확인** (Optional):
   - 복원된 사진이 카테고리의 최신 사진인지 확인
   - 최신 사진인 경우 lastPhotoUploadedAt 업데이트 가능

5. **실시간 알림** (Optional):
   - 복원 알림 생성 (PHOTO_RESTORED)
   - WebSocket으로 카테고리 멤버들에게 전송

---

## 📊 Feature 10: 사진 통계 조회

### Request

**Method**: `GET /api/v1/categories/{categoryId}/photos/stats`

**Path Parameters**:
- **categoryId** (UUID, Required): 조회할 카테고리 ID

**Headers**:
- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

- **categoryId**: 카테고리 ID
- **totalPhotos**: 전체 사진 개수 (ACTIVE 상태만)
- **totalPhotosWithAudio**: 음성이 있는 사진 개수
- **totalPhotosWithoutAudio**: 음성이 없는 사진 개수
- **photosByUser**: 사용자별 사진 개수
  - userId: 사용자 ID
  - count: 사진 개수
- **firstPhotoCreatedAt**: 첫 번째 사진 생성 시각
- **lastPhotoCreatedAt**: 마지막 사진 생성 시각

**Error Responses**:

- **403 Forbidden**: 카테고리 멤버가 아님
- **404 Not Found**: 카테고리가 존재하지 않음

### 비즈니스 규칙

1. **카테고리 멤버십 확인**:
   - 요청자가 해당 카테고리의 멤버인지 확인

2. **활성 사진만 집계**:
   - status = ACTIVE인 사진만 카운트
   - DELETED, ARCHIVED는 제외

3. **통계 계산**:
   - totalPhotos: COUNT(*) WHERE status = ACTIVE
   - totalPhotosWithAudio: COUNT(*) WHERE audioUrl IS NOT NULL AND audioUrl != ''
   - photosByUser: GROUP BY userId, COUNT(*)

4. **성능 최적화**:
   - 집계 쿼리는 인덱스 활용
   - 캐싱 권장 (5분 TTL)
   - 대용량 데이터의 경우 배치로 사전 계산

---

## 🎤 Feature 11: 실시간 사진 업데이트 알림 (WebSocket)

### 연결

**Protocol**: WebSocket + STOMP

**Endpoint**: `ws://api.soi.com/ws` 또는 `wss://api.soi.com/ws`

**Headers**:
- `Authorization`: Bearer {Firebase ID Token}

### 구독 (Subscribe)

**Topic**: `/topic/categories/{categoryId}/photos`

- 특정 카테고리의 사진 관련 실시간 이벤트 수신
- 카테고리 멤버만 구독 가능

### 메시지 형식

#### 새 사진 업로드 알림 (type: NEW_PHOTO)

- **type**: 이벤트 타입 ("NEW_PHOTO")
- **photoId**: 새로 업로드된 사진 ID
- **categoryId**: 카테고리 ID
- **userId**: 업로더 ID
- **userName**: 업로더 닉네임
- **imageUrl**: 이미지 URL (썸네일용)
- **hasAudio**: 음성 포함 여부
- **createdAt**: 생성 시각

#### 사진 삭제 알림 (type: DELETE_PHOTO)

- **type**: 이벤트 타입 ("DELETE_PHOTO")
- **photoId**: 삭제된 사진 ID
- **categoryId**: 카테고리 ID
- **userId**: 삭제한 사용자 ID
- **deletedAt**: 삭제 시각

#### 사진 수정 알림 (type: UPDATE_PHOTO)

- **type**: 이벤트 타입 ("UPDATE_PHOTO")
- **photoId**: 수정된 사진 ID
- **categoryId**: 카테고리 ID
- **caption**: 새 캡션
- **updatedAt**: 수정 시각

#### 사진 복원 알림 (type: RESTORE_PHOTO)

- **type**: 이벤트 타입 ("RESTORE_PHOTO")
- **photoId**: 복원된 사진 ID
- **categoryId**: 카테고리 ID
- **userId**: 복원한 사용자 ID
- **restoredAt**: 복원 시각

### 비즈니스 규칙

1. **멤버십 확인**:
   - WebSocket 연결 시 카테고리 멤버 여부 확인
   - 멤버가 아닌 경우 구독 거부

2. **이벤트 종류**:
   - NEW_PHOTO: 새 사진 업로드
   - DELETE_PHOTO: 사진 삭제 (소프트 삭제)
   - UPDATE_PHOTO: 사진 정보 수정 (caption)
   - RESTORE_PHOTO: 삭제된 사진 복원

3. **브로드캐스트**:
   - 같은 카테고리의 모든 멤버에게 동시 전송
   - 이벤트 발생자는 제외 가능 (Optional)

4. **재연결 처리**:
   - 연결 끊김 시 자동 재연결
   - 누락 메시지 동기화 (마지막 메시지 ID 기준)

5. **성능**:
   - Redis Pub/Sub 또는 메시지 큐를 사용한 확장 가능한 구조
   - 다중 서버 환경에서도 동작하도록 설계

---

## 🎯 API 엔드포인트 요약

| Method    | Endpoint                                             | 설명                            |
| --------- | ---------------------------------------------------- | ------------------------------- |
| POST      | /api/v1/photos                                       | 사진 업로드 (이미지 + 음성)     |
| GET       | /api/v1/photos                                       | 전체 사진 목록 (페이징)         |
| GET       | /api/v1/categories/{categoryId}/photos               | 카테고리별 사진 목록            |
| GET       | /api/v1/users/{userId}/photos                        | 사용자별 사진 목록              |
| GET       | /api/v1/photos/{photoId}                             | 사진 상세 조회                  |
| PUT       | /api/v1/photos/{photoId}                             | 사진 정보 수정                  |
| DELETE    | /api/v1/photos/{photoId}                             | 사진 삭제 (소프트 삭제)         |
| GET       | /api/v1/users/{userId}/photos/deleted                | 삭제된 사진 목록 조회           |
| POST      | /api/v1/photos/{photoId}/restore                     | 사진 복원                       |
| GET       | /api/v1/categories/{categoryId}/photos/stats         | 사진 통계 조회                  |
| WebSocket | /ws → /topic/categories/{categoryId}/photos          | 실시간 사진 업데이트 알림       |

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
- **413 Payload Too Large**: 파일 크기 초과
- **429 Too Many Requests**: Rate limit 초과
- **500 Internal Server Error**: 서버 오류

### 페이징 공통 파라미터

- **page**: 페이지 번호 (0부터 시작, 기본값: 0)
- **size**: 페이지 크기 (1~100, 기본값: 20)
- **sort**: 정렬 (기본값: createdAt,desc)

### 날짜/시간 형식

- ISO 8601 형식 사용 (예: 2025-10-23T14:30:00Z)
- 서버는 UTC 기준, 클라이언트에서 로컬 시간 변환

### 파일 크기 및 제한

- 이미지 파일: 최대 10MB
- 음성 파일: 최대 10MB
- 음성 길이: 최대 5분 (300초)
- Caption: 최대 1000자
- 파형 포인트: 50~500개

---

## 🔧 구현 가이드

### 1. 데이터베이스 스키마

#### photos 테이블

```sql
CREATE TABLE photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  image_url TEXT NOT NULL,
  audio_url TEXT,
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id),
  user_ids UUID[] NOT NULL,
  caption TEXT,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  duration_seconds INTEGER DEFAULT 0,
  deleted_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  -- 인덱스
  INDEX idx_photos_category_status_created (category_id, status, created_at DESC),
  INDEX idx_photos_user_status_created (user_id, status, created_at DESC),
  INDEX idx_photos_status_deleted (status, deleted_at) WHERE status = 'DELETED'
);
```

#### photo_waveforms 테이블 (1:1 관계)

```sql
CREATE TABLE photo_waveforms (
  photo_id UUID PRIMARY KEY REFERENCES photos(id) ON DELETE CASCADE,
  waveform_data JSONB NOT NULL, -- Array of Float [0.1, 0.5, ...]
  sample_count INTEGER NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### 2. Storage 구조

```
storage/
├── photos/
│   └── {categoryId}/
│       └── {userId}/
│           ├── {photoId}.jpg (이미지 파일)
│           └── {photoId}_audio.m4a (음성 파일)
```

### 3. 차단 사용자 필터링 SQL 예시

```sql
-- 내가 차단한 사용자들의 사진 제외
SELECT p.*
FROM photos p
WHERE p.category_id = ANY($1::UUID[])
  AND p.status = 'ACTIVE'
  AND p.user_id NOT IN (
    SELECT blocked_user_id 
    FROM user_blocks 
    WHERE blocker_user_id = $2
  )
ORDER BY p.created_at DESC
LIMIT $3;
```

### 4. 카테고리 대표사진 자동 업데이트 로직

```sql
-- 카테고리의 기존 사진 중 현재 대표사진이 있는지 확인
SELECT EXISTS(
  SELECT 1 
  FROM photos 
  WHERE category_id = $1 
    AND image_url = $2
    AND status = 'ACTIVE'
) AS is_auto_set;

-- 자동 설정인 경우 최신 사진으로 업데이트
UPDATE categories 
SET category_photo_url = $1
WHERE id = $2;
```

### 5. 소프트 삭제 배치 작업 (30일 후 영구 삭제)

```sql
-- 30일 지난 삭제된 사진 조회
SELECT id, image_url, audio_url, category_id
FROM photos
WHERE status = 'DELETED'
  AND deleted_at < NOW() - INTERVAL '30 days';

-- 영구 삭제 (Storage 파일도 함께 삭제)
DELETE FROM photos WHERE id = $1;
```

### 6. 성능 최적화

- **인덱스 활용**: 복합 인덱스 (categoryId, status, createdAt DESC)
- **N+1 문제 방지**: LEFT JOIN으로 사용자, 카테고리 정보 함께 조회
- **페이지네이션**: 커서 기반 페이지네이션 사용 (startAfterPhotoId)
- **캐싱**: 사진 통계는 Redis에 5분 TTL로 캐싱
- **Storage**: CDN 연동으로 이미지 전송 속도 향상

### 7. 보안 고려사항

- **파일 업로드**: MIME type 검증, 파일 크기 제한
- **권한 확인**: 모든 API에서 카테고리 멤버십 확인
- **Rate Limiting**: 사진 업로드는 분당 10개 제한
- **XSS 방지**: Caption에 HTML 태그 제거 또는 이스케이프
- **Storage 접근**: 서명된 URL 사용 (유효 시간 제한)

---

## 📊 테스트 시나리오

### Feature 1: 사진 업로드

**정상 케이스**:
- 이미지만 업로드
- 이미지 + 음성 업로드
- 이미지 + 음성 + 파형 데이터 업로드

**에러 케이스**:
- 파일 크기 초과 (10MB)
- 카테고리 멤버가 아님
- userIds에 userId 미포함

### Feature 7: 사진 삭제

**정상 케이스**:
- 소프트 삭제 (기본)
- 영구 삭제 (permanent=true)
- 대표사진 삭제 시 자동 업데이트

**에러 케이스**:
- 다른 사용자의 사진 삭제 시도
- 이미 삭제된 사진 재삭제

### Feature 9: 사진 복원

**정상 케이스**:
- 본인 사진 복원
- 카테고리 멤버가 사진 복원 (Optional)

**에러 케이스**:
- 삭제되지 않은 사진 복원 시도
- 권한 없는 사용자가 복원 시도

---

이 문서는 카테고리 사진 관리의 **11개 핵심 기능**을 백엔드 API로 마이그레이션하기 위한 완전한 명세서입니다.
