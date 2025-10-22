# 카테고리 API 엔드포인트 명세

이 문서는 카테고리 기능의 **모든 REST API 엔드포인트**를 정의합니다.

---

## 📋 목차

1. [공통 사항](#공통-사항)
2. [카테고리 CRUD](#카테고리-crud)
3. [멤버 관리](#멤버-관리)
4. [초대 시스템](#초대-시스템)
5. [사진 관리](#사진-관리)
6. [상태 관리](#상태-관리)

---

## 공통 사항

### Base URL

```
https://api.soi.app/v1
```

### 인증

모든 API는 JWT Bearer 토큰 필요:

```http
Authorization: Bearer <access_token>
```

### 공통 응답 형식

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
    "message": "사용자 친화적 에러 메시지",
    "details": { ... }
  }
}
```

### HTTP 상태 코드

- `200 OK`: 성공
- `201 Created`: 리소스 생성 성공
- `400 Bad Request`: 잘못된 요청
- `401 Unauthorized`: 인증 실패
- `403 Forbidden`: 권한 없음
- `404 Not Found`: 리소스 없음
- `409 Conflict`: 중복 등 충돌
- `500 Internal Server Error`: 서버 에러

---

## 카테고리 CRUD

### 1. 카테고리 목록 조회

사용자가 속한 모든 카테고리 목록을 조회합니다.

```http
GET /categories
```

#### Query Parameters

| 파라미터 | 타입    | 필수 | 설명                       |
| -------- | ------- | ---- | -------------------------- |
| page     | integer | ❌   | 페이지 번호 (기본값: 0)    |
| size     | integer | ❌   | 페이지 크기 (기본값: 20)   |
| sort     | string  | ❌   | 정렬 기준 (createdAt,desc) |

#### Response Body

```json
{
  "success": true,
  "data": {
    "categories": [
      {
        "id": "cat_123",
        "name": "가족 여행",
        "members": [
          {
            "userId": "user_a",
            "userName": "홍길동",
            "profileImageUrl": "https://..."
          }
        ],
        "coverPhotoUrl": "https://...",
        "customName": "우리 가족",
        "isPinned": true,
        "hasNewPhoto": true,
        "photoCount": 42,
        "lastPhotoUploadedBy": "user_b",
        "lastPhotoUploadedAt": "2025-01-10T15:30:00Z",
        "createdAt": "2025-01-01T10:00:00Z"
      }
    ],
    "totalElements": 10,
    "totalPages": 1,
    "currentPage": 0
  }
}
```

#### 비즈니스 로직

- 현재 사용자가 속한 카테고리만 반환
- 차단한 사용자가 있는 1:1 카테고리는 제외
- Pending 상태 초대가 있는 카테고리는 제외
- 고정된 카테고리를 상단에 표시 (정렬)
- 각 카테고리의 멤버 정보 포함 (JOIN)

---

### 2. 단일 카테고리 조회

```http
GET /categories/{categoryId}
```

#### Path Parameters

| 파라미터   | 타입   | 필수 | 설명        |
| ---------- | ------ | ---- | ----------- |
| categoryId | string | ✅   | 카테고리 ID |

#### Response Body

```json
{
  "success": true,
  "data": {
    "id": "cat_123",
    "name": "가족 여행",
    "members": [
      {
        "userId": "user_a",
        "userName": "홍길동",
        "profileImageUrl": "https://...",
        "joinedAt": "2025-01-01T10:00:00Z"
      }
    ],
    "coverPhotoUrl": "https://...",
    "customName": "우리 가족",
    "isPinned": true,
    "photoCount": 42,
    "lastPhotoUploadedBy": "user_b",
    "lastPhotoUploadedAt": "2025-01-10T15:30:00Z",
    "userLastViewedAt": "2025-01-10T14:00:00Z",
    "createdAt": "2025-01-01T10:00:00Z"
  }
}
```

#### 에러

- `404`: 카테고리를 찾을 수 없음
- `403`: 카테고리 멤버가 아님

---

### 3. 카테고리 생성

```http
POST /categories
```

#### Request Body

```json
{
  "name": "가족 여행",
  "memberIds": ["user_a", "user_b", "user_c"]
}
```

#### 입력 검증

- `name`: 필수, 1-20자
- `memberIds`: 필수, 최소 1명, 생성자 포함 필수

#### Response Body

```json
{
  "success": true,
  "data": {
    "categoryId": "cat_123",
    "name": "가족 여행",
    "members": [...],
    "invites": [
      {
        "inviteId": "inv_456",
        "invitedUserId": "user_b",
        "requiresAcceptance": true,
        "pendingMemberIds": ["user_c"]
      }
    ]
  },
  "message": "카테고리가 생성되었습니다."
}
```

#### 비즈니스 로직

1. 카테고리 이름 검증
2. 생성자와 각 멤버 간 양방향 친구 확인
3. 멤버 간 친구가 아닌 경우 초대 생성
4. 초대 알림 전송
5. 트랜잭션으로 원자성 보장

#### 에러

- `400`: 이름이 너무 김, 멤버가 없음
- `403`: 친구가 아닌 사용자 포함

---

### 4. 카테고리 수정

```http
PUT /categories/{categoryId}
```

#### Request Body

```json
{
  "name": "새로운 이름"
}
```

#### Response Body

```json
{
  "success": true,
  "data": {
    "id": "cat_123",
    "name": "새로운 이름",
    "updatedAt": "2025-01-15T10:00:00Z"
  },
  "message": "카테고리가 수정되었습니다."
}
```

#### 에러

- `403`: 멤버가 아님
- `400`: 잘못된 이름

---

### 5. 카테고리 삭제

```http
DELETE /categories/{categoryId}
```

#### Response Body

```json
{
  "success": true,
  "message": "카테고리가 삭제되었습니다."
}
```

#### 비즈니스 로직

- 연관된 사진, 초대, 커스텀 이름 모두 삭제 (Cascade)
- 트랜잭션 보장

---

## 멤버 관리

### 6. 멤버 추가

```http
POST /categories/{categoryId}/members
```

#### Request Body

```json
{
  "userId": "user_d"
}
```

또는 닉네임으로:

```json
{
  "nickname": "hong123"
}
```

#### Response Body

```json
{
  "success": true,
  "data": {
    "requiresAcceptance": true,
    "inviteId": "inv_789",
    "pendingMemberIds": ["user_a", "user_c"]
  },
  "message": "초대를 보냈습니다. 상대방의 수락을 기다리고 있습니다."
}
```

또는 즉시 추가:

```json
{
  "success": true,
  "data": {
    "requiresAcceptance": false,
    "member": {
      "userId": "user_d",
      "userName": "김철수",
      "profileImageUrl": "https://..."
    }
  },
  "message": "카테고리에 추가되었습니다."
}
```

#### 비즈니스 로직

1. 요청자가 카테고리 멤버인지 확인
2. 대상 사용자 존재 확인
3. 중복 확인
4. 친구 관계 확인
5. 기존 멤버와의 친구 관계 확인
6. 필요시 초대 생성 또는 즉시 추가

#### 에러

- `404`: 사용자를 찾을 수 없음
- `409`: 이미 멤버임
- `403`: 친구가 아님

---

### 7. 멤버 제거

```http
DELETE /categories/{categoryId}/members/{userId}
```

#### Response Body

```json
{
  "success": true,
  "message": "카테고리에서 나갔습니다."
}
```

또는 마지막 멤버인 경우:

```json
{
  "success": true,
  "message": "카테고리에서 나갔습니다. 마지막 멤버였으므로 카테고리가 삭제되었습니다."
}
```

#### 비즈니스 로직

- 멤버 확인
- 마지막 멤버이면 카테고리 삭제
- 트랜잭션 보장

---

## 초대 시스템

### 8. Pending 초대 목록 조회

```http
GET /categories/invites/pending
```

#### Response Body

```json
{
  "success": true,
  "data": {
    "invites": [
      {
        "id": "inv_123",
        "category": {
          "id": "cat_456",
          "name": "가족 여행",
          "coverPhotoUrl": "https://..."
        },
        "inviter": {
          "userId": "user_a",
          "userName": "홍길동",
          "profileImageUrl": "https://..."
        },
        "pendingMembers": [
          {
            "userId": "user_b",
            "userName": "김철수"
          }
        ],
        "createdAt": "2025-01-10T10:00:00Z",
        "expiresAt": "2025-01-17T10:00:00Z"
      }
    ]
  }
}
```

---

### 9. 초대 수락

```http
POST /categories/invites/{inviteId}/accept
```

#### Response Body

```json
{
  "success": true,
  "data": {
    "categoryId": "cat_456",
    "category": {
      "id": "cat_456",
      "name": "가족 여행",
      "members": [...]
    }
  },
  "message": "초대를 수락했습니다."
}
```

#### 비즈니스 로직

1. 초대 존재 및 상태 확인
2. 수신자 확인
3. 카테고리에 멤버 추가
4. 초대 상태를 ACCEPTED로 변경 후 삭제
5. 트랜잭션 보장

#### 에러

- `404`: 초대를 찾을 수 없음
- `403`: 본인의 초대가 아님
- `400`: 이미 수락되었거나 만료됨

---

### 10. 초대 거절

```http
POST /categories/invites/{inviteId}/decline
```

#### Response Body

```json
{
  "success": true,
  "message": "초대를 거절했습니다."
}
```

#### 비즈니스 로직

1. 초대 존재 및 상태 확인
2. 수신자 확인
3. 카테고리에서 멤버 제거
4. 초대 상태를 DECLINED로 변경 후 삭제
5. 트랜잭션 보장

---

## 사진 관리

### 11. 카테고리 사진 목록 조회

```http
GET /categories/{categoryId}/photos
```

#### Query Parameters

| 파라미터 | 타입    | 필수 | 설명                     |
| -------- | ------- | ---- | ------------------------ |
| page     | integer | ❌   | 페이지 번호 (기본값: 0)  |
| size     | integer | ❌   | 페이지 크기 (기본값: 20) |

#### Response Body

```json
{
  "success": true,
  "data": {
    "photos": [
      {
        "id": "photo_123",
        "imageUrl": "https://...",
        "audioUrl": "https://...",
        "caption": "즐거운 여행!",
        "uploader": {
          "userId": "user_a",
          "userName": "홍길동",
          "profileImageUrl": "https://..."
        },
        "uploadedAt": "2025-01-10T15:30:00Z"
      }
    ],
    "totalElements": 42,
    "totalPages": 3
  }
}
```

#### 비즈니스 로직

- 차단한 사용자의 사진 제외
- 최신순 정렬

---

### 12. 사진 업로드

```http
POST /categories/{categoryId}/photos
```

#### Request Body (multipart/form-data)

```
imageFile: <binary>
audioFile: <binary> (선택)
caption: "즐거운 여행!" (선택)
```

#### Response Body

```json
{
  "success": true,
  "data": {
    "photoId": "photo_123",
    "imageUrl": "https://...",
    "audioUrl": "https://...",
    "uploadedAt": "2025-01-10T15:30:00Z"
  },
  "message": "사진이 업로드되었습니다."
}
```

#### 비즈니스 로직

1. 멤버 권한 확인
2. 파일 검증 (크기, 형식)
3. 이미지 압축 (백엔드)
4. Storage 업로드
5. DB 저장
6. 카테고리 최신 사진 정보 업데이트
7. 다른 멤버에게 알림 전송

#### 에러

- `403`: 멤버가 아님
- `400`: 파일이 너무 큼, 잘못된 형식

---

### 13. 사진 삭제

```http
DELETE /categories/{categoryId}/photos/{photoId}
```

#### Response Body

```json
{
  "success": true,
  "message": "사진이 삭제되었습니다."
}
```

#### 비즈니스 로직

1. 권한 확인 (멤버 또는 업로더)
2. Storage에서 파일 삭제
3. DB에서 삭제
4. 표지사진이었으면 최신 사진으로 자동 변경

---

### 14. 표지사진 업데이트

#### 갤러리에서 업로드

```http
POST /categories/{categoryId}/cover-photo
```

#### Request Body (multipart/form-data)

```
imageFile: <binary>
```

#### 카테고리 내 사진으로 설정

```http
PUT /categories/{categoryId}/cover-photo
```

#### Request Body

```json
{
  "photoUrl": "https://..."
}
```

#### Response Body

```json
{
  "success": true,
  "data": {
    "coverPhotoUrl": "https://..."
  },
  "message": "표지사진이 변경되었습니다."
}
```

---

### 15. 표지사진 삭제

```http
DELETE /categories/{categoryId}/cover-photo
```

#### Response Body

```json
{
  "success": true,
  "message": "표지사진이 삭제되었습니다."
}
```

#### 비즈니스 로직

- 최신 사진으로 자동 설정
- 사진이 없으면 null

---

## 상태 관리

### 16. 카테고리 고정/해제

```http
PUT /categories/{categoryId}/pin
```

#### Request Body

```json
{
  "isPinned": true
}
```

#### Response Body

```json
{
  "success": true,
  "data": {
    "isPinned": true
  },
  "message": "카테고리를 고정했습니다."
}
```

---

### 17. 커스텀 이름 설정

```http
PUT /categories/{categoryId}/custom-name
```

#### Request Body

```json
{
  "customName": "우리 가족"
}
```

#### Response Body

```json
{
  "success": true,
  "data": {
    "customName": "우리 가족"
  },
  "message": "카테고리 이름이 변경되었습니다."
}
```

#### 입력 검증

- 1-20자
- Trim 적용

---

### 18. 사용자 확인 시간 업데이트

```http
PUT /categories/{categoryId}/view-time
```

#### Response Body

```json
{
  "success": true,
  "data": {
    "viewedAt": "2025-01-15T10:00:00Z"
  }
}
```

#### 비즈니스 로직

- 현재 시간으로 업데이트
- hasNewPhoto 계산에 사용

---

## 배치 API (최적화)

### 19. 친구 관계 배치 확인

```http
POST /friends/batch-check
```

#### Request Body

```json
{
  "userId": "user_a",
  "targetUserIds": ["user_b", "user_c", "user_d"]
}
```

#### Response Body

```json
{
  "success": true,
  "data": {
    "friendships": {
      "user_b": true,
      "user_c": false,
      "user_d": true
    }
  }
}
```

#### 비즈니스 로직

- JOIN 쿼리로 효율적 확인
- N+1 문제 방지

---

## 에러 코드 목록

| 코드                    | 설명                          |
| ----------------------- | ----------------------------- |
| `CATEGORY_NOT_FOUND`    | 카테고리를 찾을 수 없음       |
| `CATEGORY_NAME_INVALID` | 카테고리 이름이 유효하지 않음 |
| `CATEGORY_FULL`         | 카테고리 인원이 가득 참       |
| `NOT_CATEGORY_MEMBER`   | 카테고리 멤버가 아님          |
| `ALREADY_MEMBER`        | 이미 카테고리 멤버임          |
| `FRIENDSHIP_REQUIRED`   | 친구 관계 필요                |
| `INVITE_NOT_FOUND`      | 초대를 찾을 수 없음           |
| `INVITE_EXPIRED`        | 초대가 만료됨                 |
| `PHOTO_NOT_FOUND`       | 사진을 찾을 수 없음           |
| `FILE_TOO_LARGE`        | 파일이 너무 큼                |
| `INVALID_FILE_TYPE`     | 지원하지 않는 파일 형식       |
| `USER_NOT_FOUND`        | 사용자를 찾을 수 없음         |
| `BLOCKED_USER`          | 차단된 사용자                 |

---

## 다음 문서

👉 **[데이터 모델](./04-data-models.md)** - Entity 및 DTO 설계
