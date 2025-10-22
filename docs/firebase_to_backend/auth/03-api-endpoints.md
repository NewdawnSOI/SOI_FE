# 인증 시스템 API 엔드포인트 명세

이 문서는 인증 시스템의 **모든 REST API 엔드포인트**를 정의합니다.

---

## 📋 목차

1. [공통 사항](#공통-사항)
2. [인증 API](#인증-api)
3. [사용자 정보 API](#사용자-정보-api)
4. [프로필 관리 API](#프로필-관리-api)
5. [사용자 검색 API](#사용자-검색-api)
6. [계정 관리 API](#계정-관리-api)

---

## 공통 사항

### Base URL

```
https://api.soi.app/v1
```

### 인증

모든 API는 Firebase ID Token 필요:

```http
Authorization: Bearer <firebase_id_token>
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

## 인증 API

### 1. 회원가입

Firebase 인증 후 사용자 정보를 백엔드에 등록합니다.

```http
POST /auth/register
```

#### Request Body

```json
{
  "firebaseUid": "abc123xyz...",
  "idToken": "eyJhbGciOiJSUzI1NiI...",
  "nickname": "hong123",
  "name": "홍길동",
  "phoneNumber": "01012345678",
  "birthDate": "1990-01-01"
}
```

#### 입력 검증

- `firebaseUid`: 필수, Firebase에서 발급받은 UID
- `idToken`: 필수, Firebase ID Token
- `nickname`: 필수, 1-50자, 영문/숫자/언더스코어, 중복 불가
- `name`: 필수, 1-100자
- `phoneNumber`: 필수, `01012345678` 형식, 중복 불가
- `birthDate`: 선택, `YYYY-MM-DD` 형식, 만 14세 이상

#### Response Body (201 Created)

```json
{
  "success": true,
  "data": {
    "id": 123,
    "firebaseUid": "abc123xyz...",
    "nickname": "hong123",
    "name": "홍길동",
    "phoneNumber": "01012345678",
    "birthDate": "1990-01-01",
    "profileImageUrl": null,
    "createdAt": "2025-01-15T10:00:00Z"
  },
  "message": "회원가입이 완료되었습니다."
}
```

#### 비즈니스 로직

1. Firebase ID Token 검증
2. Token의 UID와 요청 body의 UID 일치 확인
3. 닉네임 중복 확인
4. 전화번호 중복 확인
5. users 테이블에 저장
6. UserDTO 반환

#### 에러

- `400`: 잘못된 입력 값
- `401`: ID Token 검증 실패
- `409`: 닉네임 또는 전화번호 중복

---

### 2. 로그인

Firebase 자동 로그인 후 백엔드 사용자 정보를 조회합니다.

```http
POST /auth/login
```

#### Request Body

```json
{
  "firebaseUid": "abc123xyz...",
  "idToken": "eyJhbGciOiJSUzI1NiI..."
}
```

#### Response Body (200 OK)

```json
{
  "success": true,
  "data": {
    "id": 123,
    "nickname": "hong123",
    "name": "홍길동",
    "phoneNumber": "01012345678",
    "profileImageUrl": "https://...",
    "lastLogin": "2025-01-15T10:00:00Z"
  },
  "message": "로그인 성공"
}
```

#### 비즈니스 로직

1. Firebase ID Token 검증
2. Firebase UID로 사용자 조회
3. 계정 활성화 상태 확인
4. `last_login` 시간 업데이트
5. UserDTO 반환

#### 에러

- `401`: ID Token 검증 실패
- `403`: 비활성화된 계정
- `404`: 가입되지 않은 사용자

---

### 3. 토큰 갱신

Firebase ID Token을 갱신합니다. (선택사항, Firebase SDK가 자동 처리)

```http
POST /auth/refresh
```

#### Request Body

```json
{
  "refreshToken": "..."
}
```

#### Response Body

```json
{
  "success": true,
  "data": {
    "idToken": "eyJhbGciOiJSUzI1NiI...",
    "expiresIn": 3600
  }
}
```

---

### 4. 로그아웃

로그아웃 처리 (Firebase SDK에서 주로 처리)

```http
POST /auth/logout
```

#### Response Body

```json
{
  "success": true,
  "message": "로그아웃되었습니다."
}
```

---

## 사용자 정보 API

### 5. 내 정보 조회

현재 로그인한 사용자의 상세 정보를 조회합니다.

```http
GET /users/me
```

#### Response Body

```json
{
  "success": true,
  "data": {
    "id": 123,
    "nickname": "hong123",
    "name": "홍길동",
    "phoneNumber": "01012345678",
    "birthDate": "1990-01-01",
    "profileImageUrl": "https://...",
    "isDeactivated": false,
    "createdAt": "2025-01-01T10:00:00Z",
    "lastLogin": "2025-01-15T10:00:00Z"
  }
}
```

#### 비즈니스 로직

- Firebase ID Token에서 UID 추출
- 해당 사용자의 전체 정보 반환
- 본인 정보이므로 phoneNumber, birthDate 포함

---

### 6. 특정 사용자 정보 조회

다른 사용자의 공개 정보를 조회합니다.

```http
GET /users/{userId}
```

#### Path Parameters

| 파라미터 | 타입 | 필수 | 설명      |
| -------- | ---- | ---- | --------- |
| userId   | long | ✅   | 사용자 ID |

#### Response Body

```json
{
  "success": true,
  "data": {
    "id": 123,
    "nickname": "hong123",
    "name": "홍길동",
    "profileImageUrl": "https://..."
  }
}
```

#### 비즈니스 로직

- 공개 정보만 반환 (nickname, name, profileImageUrl)
- 전화번호, 생년월일 등은 비공개
- 비활성화된 계정은 404 반환

#### 에러

- `404`: 사용자를 찾을 수 없음

---

## 프로필 관리 API

### 7. 내 정보 수정

이름, 생년월일 등을 수정합니다.

```http
PUT /users/me
```

#### Request Body

```json
{
  "name": "홍길순",
  "birthDate": "1990-01-01"
}
```

#### Response Body

```json
{
  "success": true,
  "data": {
    "id": 123,
    "nickname": "hong123",
    "name": "홍길순",
    "birthDate": "1990-01-01",
    "updatedAt": "2025-01-15T10:00:00Z"
  },
  "message": "정보가 수정되었습니다."
}
```

#### 수정 가능한 필드

- `name`: 이름
- `birthDate`: 생년월일

#### 수정 불가능한 필드

- `firebaseUid`: 영구 식별자
- `nickname`: 고유 ID (변경 시 별도 API 필요)
- `phoneNumber`: Firebase Auth 종속

---

### 8. 프로필 이미지 업로드

갤러리에서 선택한 이미지를 프로필 이미지로 설정합니다.

```http
POST /users/me/profile-image
```

#### Request Body (multipart/form-data)

```
imageFile: <binary>
```

#### Response Body

```json
{
  "success": true,
  "data": {
    "profileImageUrl": "https://s3.amazonaws.com/.../profile_123.jpg"
  },
  "message": "프로필 이미지가 변경되었습니다."
}
```

#### 비즈니스 로직

1. 파일 검증 (크기, 형식)
2. 이미지 리사이징 (1024x1024px)
3. S3 업로드
4. 기존 이미지 삭제
5. users.profile_image_url 업데이트

#### 에러

- `400`: 파일 크기 초과 (10MB), 잘못된 형식
- `413`: 파일이 너무 큼

---

### 9. 프로필 이미지 삭제

프로필 이미지를 삭제하고 기본 이미지로 설정합니다.

```http
DELETE /users/me/profile-image
```

#### Response Body

```json
{
  "success": true,
  "message": "프로필 이미지가 삭제되었습니다."
}
```

#### 비즈니스 로직

- S3에서 이미지 파일 삭제
- users.profile_image_url을 NULL로 설정

---

## 사용자 검색 API

### 10. 닉네임으로 사용자 검색

친구 추가를 위해 닉네임으로 사용자를 검색합니다.

```http
GET /users/search
```

#### Query Parameters

| 파라미터 | 타입    | 필수 | 설명                      |
| -------- | ------- | ---- | ------------------------- |
| nickname | string  | ✅   | 검색할 닉네임 (부분 일치) |
| page     | integer | ❌   | 페이지 번호 (기본값: 0)   |
| size     | integer | ❌   | 페이지 크기 (기본값: 20)  |

#### Response Body

```json
{
  "success": true,
  "data": {
    "users": [
      {
        "id": 123,
        "nickname": "hong123",
        "name": "홍길동",
        "profileImageUrl": "https://..."
      },
      {
        "id": 456,
        "nickname": "hong456",
        "name": "홍길순",
        "profileImageUrl": "https://..."
      }
    ],
    "totalElements": 2,
    "totalPages": 1,
    "currentPage": 0
  }
}
```

#### 비즈니스 로직

- 닉네임 부분 일치 검색 (LIKE '%query%')
- 본인 제외
- 비활성화 계정 제외
- 최대 50개 결과 반환
- 페이지네이션 지원

#### 에러

- `400`: 검색어가 비어있음

---

### 11. 닉네임 중복 확인

회원가입 시 닉네임 중복 여부를 확인합니다.

```http
POST /users/check-duplicate
```

#### Request Body

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
    "available": false,
    "message": "이미 사용 중인 닉네임입니다."
  }
}
```

또는

```json
{
  "success": true,
  "data": {
    "available": true,
    "message": "사용 가능한 닉네임입니다."
  }
}
```

#### 비즈니스 로직

- DB에서 닉네임 중복 확인
- 대소문자 구분
- 실시간 검증

---

## 계정 관리 API

### 12. 계정 비활성화

계정을 일시적으로 비활성화합니다. (재활성화 가능)

```http
PUT /users/me/deactivate
```

#### Response Body

```json
{
  "success": true,
  "message": "계정이 비활성화되었습니다."
}
```

#### 비즈니스 로직

- `is_deactivated` 플래그를 `true`로 설정
- 업로드한 사진/오디오 숨김 처리
- 로그인 불가
- 데이터는 유지

---

### 13. 계정 활성화

비활성화된 계정을 다시 활성화합니다.

```http
PUT /users/me/activate
```

#### Response Body

```json
{
  "success": true,
  "message": "계정이 활성화되었습니다."
}
```

#### 비즈니스 로직

- `is_deactivated` 플래그를 `false`로 설정
- 모든 콘텐츠 복원
- 로그인 가능

---

### 14. 회원 탈퇴

계정과 모든 데이터를 영구적으로 삭제합니다.

```http
DELETE /users/me
```

#### Response Body

```json
{
  "success": true,
  "message": "회원 탈퇴가 완료되었습니다."
}
```

#### 비즈니스 로직 (트랜잭션)

1. 카테고리 멤버 관계 삭제
2. 친구 관계 삭제
3. 업로드한 사진/오디오 삭제
4. Storage 파일 삭제
5. 알림 삭제
6. users 테이블에서 삭제
7. Firebase Auth는 유지 (재가입 방지)

#### 제한 조건

- 카테고리 멤버인 경우 먼저 나가기 필요
- 진행 중인 거래 확인 (선택)

#### 에러

- `409`: 카테고리에서 나가야 탈퇴 가능

---

## 배치 API (내부 사용)

### 15. 여러 사용자 정보 조회

친구 목록 등에서 여러 사용자 정보를 한 번에 조회합니다.

```http
POST /users/batch
```

#### Request Body

```json
{
  "userIds": [123, 456, 789]
}
```

#### Response Body

```json
{
  "success": true,
  "data": {
    "users": [
      {
        "id": 123,
        "nickname": "hong123",
        "name": "홍길동",
        "profileImageUrl": "https://..."
      },
      {
        "id": 456,
        "nickname": "kim456",
        "name": "김철수",
        "profileImageUrl": "https://..."
      }
    ]
  }
}
```

#### 비즈니스 로직

- IN 쿼리로 효율적 조회
- N+1 문제 방지
- 최대 100개까지 조회

---

## 에러 코드 목록

| 코드                  | 설명                    |
| --------------------- | ----------------------- |
| `USER_NOT_FOUND`      | 사용자를 찾을 수 없음   |
| `NICKNAME_DUPLICATE`  | 닉네임 중복             |
| `PHONE_DUPLICATE`     | 전화번호 중복           |
| `INVALID_ID_TOKEN`    | 유효하지 않은 ID Token  |
| `TOKEN_EXPIRED`       | 만료된 Token            |
| `ACCOUNT_DEACTIVATED` | 비활성화된 계정         |
| `FILE_TOO_LARGE`      | 파일 크기 초과          |
| `INVALID_FILE_TYPE`   | 지원하지 않는 파일 형식 |
| `PERMISSION_DENIED`   | 권한 없음               |
| `INVALID_BIRTH_DATE`  | 잘못된 생년월일         |
| `AGE_RESTRICTION`     | 만 14세 이상 가입 가능  |

---

## 다음 문서

👉 **[데이터 모델](./04-data-models.md)** - Entity 및 DTO 설계
