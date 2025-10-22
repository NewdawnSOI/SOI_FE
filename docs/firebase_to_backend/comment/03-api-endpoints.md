# 음성/텍스트 댓글 시스템 - API 엔드포인트

이 문서는 음성/텍스트 댓글 시스템의 **REST API 명세**를 정의합니다.

---

## 📋 목차

1. [API 개요](#api-개요)
2. [인증](#인증)
3. [댓글 생성 API](#댓글-생성-api)
4. [댓글 조회 API](#댓글-조회-api)
5. [댓글 수정 API](#댓글-수정-api)
6. [댓글 삭제 API](#댓글-삭제-api)
7. [에러 코드](#에러-코드)

---

## API 개요

### Base URL

```
https://api.soi-app.com/v1
```

### 공통 헤더

| 헤더          | 값                  | 설명              |
| ------------- | ------------------- | ----------------- |
| Authorization | Bearer {idToken}    | Firebase ID Token |
| Content-Type  | application/json    | JSON 요청 시      |
| Content-Type  | multipart/form-data | 파일 업로드 시    |

### 응답 형식

#### 성공 응답

```json
{
  "success": true,
  "data": { ... },
  "message": "성공 메시지"
}
```

#### 에러 응답

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "에러 메시지",
    "details": { ... }
  }
}
```

---

## 인증

모든 API는 Firebase ID Token 인증이 필요합니다.

```
Authorization: Bearer eyJhbGciOiJSUzI1NiI...
```

---

## 댓글 생성 API

### 1. POST /photos/{photoId}/comments/audio

음성 댓글을 생성합니다.

#### Request

```http
POST /api/photos/photo123/comments/audio HTTP/1.1
Host: api.soi-app.com
Authorization: Bearer eyJhbGciOiJSUzI1NiI...
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary

------WebKitFormBoundary
Content-Disposition: form-data; name="audioFile"; filename="audio.aac"
Content-Type: audio/aac

<binary audio data>
------WebKitFormBoundary
Content-Disposition: form-data; name="waveformData"

[0.5, 0.8, 0.3, 0.9, 0.4, ...]
------WebKitFormBoundary
Content-Disposition: form-data; name="duration"

5000
------WebKitFormBoundary
Content-Disposition: form-data; name="relativeX"

0.5
------WebKitFormBoundary
Content-Disposition: form-data; name="relativeY"

0.3
------WebKitFormBoundary--
```

#### Request Body

| 필드         | 타입       | 필수 | 설명                                     |
| ------------ | ---------- | ---- | ---------------------------------------- |
| audioFile    | File       | ✅   | 오디오 파일 (최대 10MB, aac/m4a/mp3/wav) |
| waveformData | JSON Array | ✅   | 파형 데이터 (0.0~1.0 범위의 double 배열) |
| duration     | int        | ✅   | 녹음 시간 (밀리초, 최대 300000)          |
| relativeX    | double     | ❌   | 프로필 X 좌표 (0.0~1.0)                  |
| relativeY    | double     | ❌   | 프로필 Y 좌표 (0.0~1.0)                  |

#### Response (201 Created)

```json
{
  "success": true,
  "data": {
    "id": 123,
    "photoId": "photo123",
    "recorderUserId": 456,
    "type": "audio",
    "audioUrl": "https://s3.amazonaws.com/soi-comments/audio/photo123/456/1234567890.aac",
    "duration": 5000,
    "profileImageUrl": "https://s3.amazonaws.com/soi-profiles/456/profile.jpg",
    "relativeX": 0.5,
    "relativeY": 0.3,
    "isDeleted": false,
    "createdAt": "2025-01-15T10:00:00Z"
  },
  "message": "음성 댓글이 생성되었습니다."
}
```

#### Business Logic

```
1. Firebase ID Token 검증 → userId 추출
2. photoId 존재 확인 (photos 테이블)
3. 오디오 파일 검증 (크기, 형식, MIME)
4. S3 업로드
   - 경로: comments/audio/{photoId}/{userId}/{timestamp}.aac
5. waveform_data 정규화 (0.0~1.0)
6. comments 테이블 INSERT
7. waveform_data 테이블 INSERT
8. 알림 생성 (비동기)
9. Response 반환
```

---

### 2. POST /photos/{photoId}/comments/text

텍스트 댓글을 생성합니다.

#### Request

```http
POST /api/photos/photo123/comments/text HTTP/1.1
Host: api.soi-app.com
Authorization: Bearer eyJhbGciOiJSUzI1NiI...
Content-Type: application/json

{
  "text": "좋은 사진이네요!",
  "relativeX": 0.7,
  "relativeY": 0.5
}
```

#### Request Body

| 필드      | 타입   | 필수 | 설명                    |
| --------- | ------ | ---- | ----------------------- |
| text      | string | ✅   | 댓글 내용 (최대 1000자) |
| relativeX | double | ❌   | 프로필 X 좌표 (0.0~1.0) |
| relativeY | double | ❌   | 프로필 Y 좌표 (0.0~1.0) |

#### Response (201 Created)

```json
{
  "success": true,
  "data": {
    "id": 124,
    "photoId": "photo123",
    "recorderUserId": 789,
    "type": "text",
    "text": "좋은 사진이네요!",
    "profileImageUrl": "https://s3.amazonaws.com/soi-profiles/789/profile.jpg",
    "relativeX": 0.7,
    "relativeY": 0.5,
    "isDeleted": false,
    "createdAt": "2025-01-15T10:05:00Z"
  },
  "message": "텍스트 댓글이 생성되었습니다."
}
```

#### Business Logic

```
1. Firebase ID Token 검증
2. photoId 존재 확인
3. text 검증 (trim, 길이, 금지어)
4. comments 테이블 INSERT
   - type: 'text'
   - audio_url: NULL
   - text: 입력값
5. 알림 생성
6. Response 반환
```

---

## 댓글 조회 API

### 3. GET /photos/{photoId}/comments

특정 사진의 모든 댓글을 조회합니다.

#### Request

```http
GET /api/photos/photo123/comments?page=0&size=20 HTTP/1.1
Host: api.soi-app.com
Authorization: Bearer eyJhbGciOiJSUzI1NiI...
```

#### Query Parameters

| 파라미터 | 타입 | 필수 | 기본값 | 설명                     |
| -------- | ---- | ---- | ------ | ------------------------ |
| page     | int  | ❌   | 0      | 페이지 번호 (0부터 시작) |
| size     | int  | ❌   | 20     | 페이지 크기 (최대 100)   |

#### Response (200 OK)

```json
{
  "success": true,
  "data": {
    "comments": [
      {
        "id": 123,
        "photoId": "photo123",
        "recorderUserId": 456,
        "recorderNickname": "hong123",
        "recorderName": "홍길동",
        "type": "audio",
        "audioUrl": "https://s3.amazonaws.com/.../audio.aac",
        "duration": 5000,
        "waveformData": [0.5, 0.8, 0.3, ...],
        "profileImageUrl": "https://s3.amazonaws.com/.../profile.jpg",
        "relativeX": 0.5,
        "relativeY": 0.3,
        "createdAt": "2025-01-15T10:00:00Z"
      },
      {
        "id": 124,
        "photoId": "photo123",
        "recorderUserId": 789,
        "recorderNickname": "kim456",
        "recorderName": "김철수",
        "type": "text",
        "text": "좋은 사진이네요!",
        "profileImageUrl": "https://s3.amazonaws.com/.../profile.jpg",
        "relativeX": 0.7,
        "relativeY": 0.5,
        "createdAt": "2025-01-15T10:05:00Z"
      }
    ],
    "pagination": {
      "currentPage": 0,
      "pageSize": 20,
      "totalElements": 25,
      "totalPages": 2,
      "hasNext": true,
      "hasPrevious": false
    }
  }
}
```

#### Business Logic

```
1. Firebase ID Token 검증
2. photoId 존재 확인
3. 페이지네이션 파라미터 검증
4. SQL 쿼리:
   SELECT c.*, u.nickname, u.name, w.data AS waveform_data
   FROM comments c
   JOIN users u ON c.recorder_user_id = u.id
   LEFT JOIN waveform_data w ON c.id = w.comment_id
   WHERE c.photo_id = ? AND c.is_deleted = FALSE
   ORDER BY c.created_at ASC
   LIMIT ? OFFSET ?
5. DTO 변환
6. Response 반환
```

---

### 4. GET /users/{userId}/comments

특정 사용자의 모든 댓글을 조회합니다.

#### Request

```http
GET /api/users/456/comments?page=0&size=20 HTTP/1.1
Host: api.soi-app.com
Authorization: Bearer eyJhbGciOiJSUzI1NiI...
```

#### Response (200 OK)

```json
{
  "success": true,
  "data": {
    "comments": [
      {
        "id": 123,
        "photoId": "photo123",
        "photoThumbnailUrl": "https://s3.amazonaws.com/.../thumb.jpg",
        "type": "audio",
        "audioUrl": "https://s3.amazonaws.com/.../audio.aac",
        "duration": 5000,
        "createdAt": "2025-01-15T10:00:00Z"
      },
      {
        "id": 125,
        "photoId": "photo456",
        "photoThumbnailUrl": "https://s3.amazonaws.com/.../thumb2.jpg",
        "type": "text",
        "text": "멋진 사진입니다!",
        "createdAt": "2025-01-14T15:30:00Z"
      }
    ],
    "pagination": {
      "currentPage": 0,
      "pageSize": 20,
      "totalElements": 15,
      "totalPages": 1
    }
  }
}
```

---

### 5. GET /comments/{commentId}

특정 댓글의 상세 정보를 조회합니다.

#### Request

```http
GET /api/comments/123 HTTP/1.1
Host: api.soi-app.com
Authorization: Bearer eyJhbGciOiJSUzI1NiI...
```

#### Response (200 OK)

```json
{
  "success": true,
  "data": {
    "id": 123,
    "photoId": "photo123",
    "recorderUserId": 456,
    "recorderNickname": "hong123",
    "recorderName": "홍길동",
    "type": "audio",
    "audioUrl": "https://s3.amazonaws.com/.../audio.aac",
    "duration": 5000,
    "waveformData": [0.5, 0.8, 0.3, ...],
    "profileImageUrl": "https://s3.amazonaws.com/.../profile.jpg",
    "relativeX": 0.5,
    "relativeY": 0.3,
    "isDeleted": false,
    "createdAt": "2025-01-15T10:00:00Z",
    "updatedAt": "2025-01-15T10:00:00Z"
  }
}
```

---

## 댓글 수정 API

### 6. PUT /comments/{commentId}/position

댓글의 프로필 이미지 위치를 수정합니다.

#### Request

```http
PUT /api/comments/123/position HTTP/1.1
Host: api.soi-app.com
Authorization: Bearer eyJhbGciOiJSUzI1NiI...
Content-Type: application/json

{
  "relativeX": 0.6,
  "relativeY": 0.4
}
```

#### Request Body

| 필드      | 타입   | 필수 | 설명                    |
| --------- | ------ | ---- | ----------------------- |
| relativeX | double | ✅   | 프로필 X 좌표 (0.0~1.0) |
| relativeY | double | ✅   | 프로필 Y 좌표 (0.0~1.0) |

#### Response (200 OK)

```json
{
  "success": true,
  "data": {
    "id": 123,
    "relativeX": 0.6,
    "relativeY": 0.4,
    "updatedAt": "2025-01-15T10:10:00Z"
  },
  "message": "프로필 위치가 수정되었습니다."
}
```

#### Business Logic

```
1. Firebase ID Token 검증
2. commentId 존재 확인
3. 권한 확인 (본인 댓글인지)
4. 좌표 검증 (0.0~1.0 범위)
5. SQL UPDATE:
   UPDATE comments
   SET relative_x = ?, relative_y = ?, updated_at = NOW()
   WHERE id = ? AND recorder_user_id = ?
6. Response 반환
```

---

### 7. PATCH /users/{userId}/comments/profile-image

특정 사용자의 모든 댓글의 프로필 이미지 URL을 일괄 업데이트합니다.

#### Request

```http
PATCH /api/users/456/comments/profile-image HTTP/1.1
Host: api.soi-app.com
Authorization: Bearer eyJhbGciOiJSUzI1NiI...
Content-Type: application/json

{
  "newProfileImageUrl": "https://s3.amazonaws.com/soi-profiles/456/new_profile.jpg"
}
```

#### Request Body

| 필드               | 타입   | 필수 | 설명                 |
| ------------------ | ------ | ---- | -------------------- |
| newProfileImageUrl | string | ✅   | 새 프로필 이미지 URL |

#### Response (200 OK)

```json
{
  "success": true,
  "data": {
    "userId": 456,
    "updatedCommentsCount": 15,
    "newProfileImageUrl": "https://s3.amazonaws.com/soi-profiles/456/new_profile.jpg"
  },
  "message": "프로필 이미지가 업데이트되었습니다."
}
```

#### Business Logic

```
1. Firebase ID Token 검증
2. 권한 확인 (본인 댓글만)
3. URL 검증
4. SQL UPDATE:
   UPDATE comments
   SET profile_image_url = ?, updated_at = NOW()
   WHERE recorder_user_id = ? AND is_deleted = FALSE
5. 영향받은 행 수 반환
6. Response 반환
```

---

## 댓글 삭제 API

### 8. DELETE /comments/{commentId}

댓글을 삭제합니다 (Soft Delete).

#### Request

```http
DELETE /api/comments/123 HTTP/1.1
Host: api.soi-app.com
Authorization: Bearer eyJhbGciOiJSUzI1NiI...
```

#### Response (200 OK)

```json
{
  "success": true,
  "message": "댓글이 삭제되었습니다."
}
```

#### Business Logic

```
1. Firebase ID Token 검증
2. commentId 존재 확인
3. 댓글 조회
4. 권한 확인:
   - 본인 댓글인가?
5. SQL UPDATE (Soft Delete):
   UPDATE comments
   SET is_deleted = TRUE, updated_at = NOW()
   WHERE id = ?
6. Response 반환
```

---

## 에러 코드

### 인증 에러 (401)

| 코드               | 메시지                        | 설명                        |
| ------------------ | ----------------------------- | --------------------------- |
| AUTH_TOKEN_MISSING | 인증 토큰이 필요합니다        | Authorization 헤더 없음     |
| AUTH_TOKEN_INVALID | 유효하지 않은 인증 토큰입니다 | Firebase ID Token 검증 실패 |
| AUTH_TOKEN_EXPIRED | 인증 토큰이 만료되었습니다    | Token 만료                  |

### 권한 에러 (403)

| 코드                     | 메시지                           | 설명             |
| ------------------------ | -------------------------------- | ---------------- |
| FORBIDDEN                | 권한이 없습니다                  | 본인 댓글이 아님 |
| COMMENT_DELETE_FORBIDDEN | 자신의 댓글만 삭제할 수 있습니다 | 본인 댓글이 아님 |

### 요청 에러 (400)

| 코드               | 메시지                              | 설명                            |
| ------------------ | ----------------------------------- | ------------------------------- |
| INVALID_AUDIO_FILE | 유효하지 않은 오디오 파일입니다     | 파일 형식 오류                  |
| FILE_SIZE_EXCEEDED | 파일 크기가 너무 큽니다 (최대 10MB) | 파일 크기 초과                  |
| INVALID_DURATION   | 유효하지 않은 녹음 시간입니다       | duration 범위 오류              |
| INVALID_TEXT       | 유효하지 않은 텍스트입니다          | 텍스트 빈 문자열 또는 길이 초과 |
| INVALID_POSITION   | 유효하지 않은 위치입니다            | 좌표 범위 오류 (0.0~1.0)        |
| TEXT_TOO_LONG      | 텍스트가 너무 깁니다 (최대 1000자)  | 텍스트 길이 초과                |
| FORBIDDEN_WORD     | 부적절한 단어가 포함되어 있습니다   | 금지어 감지                     |

### 리소스 에러 (404)

| 코드              | 메시지                     | 설명           |
| ----------------- | -------------------------- | -------------- |
| PHOTO_NOT_FOUND   | 존재하지 않는 사진입니다   | photoId 없음   |
| COMMENT_NOT_FOUND | 존재하지 않는 댓글입니다   | commentId 없음 |
| USER_NOT_FOUND    | 존재하지 않는 사용자입니다 | userId 없음    |

### Rate Limit 에러 (429)

| 코드                | 메시지                                           | 설명            |
| ------------------- | ------------------------------------------------ | --------------- |
| RATE_LIMIT_EXCEEDED | 너무 많은 요청입니다. 잠시 후 다시 시도해주세요. | Rate limit 초과 |
| TOO_MANY_COMMENTS   | 너무 많은 댓글을 작성했습니다                    | 분당 10개 초과  |
| SPAM_DETECTED       | 스팸 행위가 감지되었습니다                       | 동일 댓글 반복  |

### 서버 에러 (500)

| 코드                  | 메시지                           | 설명           |
| --------------------- | -------------------------------- | -------------- |
| S3_UPLOAD_FAILED      | 파일 업로드에 실패했습니다       | S3 업로드 오류 |
| DATABASE_ERROR        | 데이터베이스 오류가 발생했습니다 | SQL 오류       |
| INTERNAL_SERVER_ERROR | 서버 오류가 발생했습니다         | 기타 서버 오류 |

---

## 🎯 다음 단계

API 명세를 이해했다면:

1. [04-data-models.md](./04-data-models.md)에서 DB 스키마 확인
2. [05-features.md](./05-features.md)에서 구현 예시 확인
