# Auth System - Features Specification

## 📖 문서 목적

이 문서는 SOI 앱의 **인증 시스템**을 백엔드로 마이그레이션하기 위한 **기능 명세서**입니다.

각 API의 **Request Parameters**와 **Response**를 평문으로 정리하여, 백엔드 개발자가 자유롭게 구현할 수 있도록 합니다.

---

## 🎯 기능 개요

| 순번 | 기능                    | 엔드포인트                            | 설명                                   |
| ---- | ----------------------- | ------------------------------------- | -------------------------------------- |
| 1    | 회원가입                | `POST /api/v1/users/register`         | Firebase Auth 이후 사용자 정보 등록    |
| 2    | 로그인                  | `POST /api/v1/users/login`            | Firebase Auth 검증 및 사용자 정보 조회 |
| 3    | 내 정보 조회            | `GET /api/v1/users/me`                | 현재 로그인한 사용자 정보              |
| 4    | 사용자 프로필 조회      | `GET /api/v1/users/{userId}`          | 다른 사용자 프로필 정보                |
| 5    | 사용자 정보 수정        | `PUT /api/v1/users/me`                | 이름, 생년월일 수정                    |
| 6    | 프로필 이미지 업로드    | `POST /api/v1/users/me/profile-image` | 프로필 이미지 업로드 및 URL 업데이트   |
| 7    | 닉네임 검색             | `GET /api/v1/users/search`            | 닉네임으로 사용자 검색                 |
| 8    | 닉네임 중복 확인        | `POST /api/v1/users/check-duplicate`  | 회원가입 시 닉네임 중복 체크           |
| 9    | 계정 비활성화           | `POST /api/v1/users/me/deactivate`    | 계정 일시 비활성화 (사진 숨김)         |
| 10   | 계정 활성화             | `POST /api/v1/users/me/activate`      | 비활성화된 계정 재활성화               |
| 11   | 회원 탈퇴               | `DELETE /api/v1/users/me`             | 계정 및 모든 데이터 완전 삭제          |
| 12   | 친구 초대 링크 생성     | `POST /api/v1/invites/friend`         | 친구 초대용 단축 URL 생성              |
| 13   | 다중 프로필 이미지 조회 | `GET /api/v1/users/profile-images`    | 여러 사용자 프로필 이미지 일괄 조회    |
| 14   | 실시간 프로필 업데이트  | `WebSocket /ws`                       | 프로필 변경 실시간 알림 (STOMP)        |

---

## 📦 Feature 1: 회원가입

### Request

**Method**: `POST /api/v1/users/register`

**Content-Type**: `application/json`

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

**Body**:

- **firebaseUid** (String, Required)
  - Firebase Auth에서 발급한 사용자 고유 ID
  - Firebase ID Token에서 추출한 UID와 일치해야 함
- **nickname** (String, Required)
  - 사용자 닉네임/ID
  - 형식: 영문, 숫자, 언더스코어만 허용 (^[a-zA-Z0-9_]+$)
  - 길이: 1~50자
  - 중복 불가
- **name** (String, Required)
  - 사용자 실명
  - 길이: 1~100자
  - 앞뒤 공백 제거 필요
- **phoneNumber** (String, Required)
  - 전화번호 (한국 형식)
  - 형식: 01로 시작, 10~11자리 (^01[0-9]{8,9}$)
  - 예: "01012345678"
  - 중복 불가 (이미 가입된 번호면 에러)
- **birthDate** (String, Optional)
  - 생년월일
  - 형식: YYYY-MM-DD (예: "1990-01-01")
  - 제약: 만 14세 이상, 100세 이하

### Response

**Success (201 Created)**:

- **id**: 생성된 사용자 DB ID (Long)
- **firebaseUid**: Firebase UID
- **nickname**: 닉네임
- **name**: 이름
- **phoneNumber**: 전화번호
- **birthDate**: 생년월일 (Optional)
- **profileImageUrl**: 프로필 이미지 URL (초기값 null)
- **isDeactivated**: 비활성화 여부 (false)
- **createdAt**: 가입 시각
- **lastLogin**: 마지막 로그인 시각

**Error Responses**:

- **400 Bad Request**: 닉네임/전화번호 형식 오류, 생년월일 검증 실패
- **401 Unauthorized**: Firebase ID Token 없음 또는 만료
- **403 Forbidden**: Token의 UID와 요청의 firebaseUid 불일치
- **409 Conflict**: 닉네임 또는 전화번호 중복
- **500 Internal Server Error**: 서버 오류

### 비즈니스 규칙

1. **Firebase ID Token 검증**:

   - Authorization 헤더에서 Bearer Token 추출
   - Firebase Admin SDK로 토큰 검증 및 UID 추출
   - 요청의 firebaseUid와 토큰의 UID 일치 확인

2. **닉네임 검증**:

   - 형식: 영문, 숫자, 언더스코어만 허용
   - 길이: 1~50자
   - DB에서 중복 확인 (existsByNickname)

3. **전화번호 검증**:

   - 형식: ^01[0-9]{8,9}$
   - DB에서 중복 확인 (이미 가입된 번호면 409 에러)
   - 저장 시 정규화: 앞의 0 제거 (예: "01012345678" → "1012345678")

4. **생년월일 검증** (Optional):

   - 미래 날짜 불가
   - 만 14세 이상, 100세 이하

5. **초기 상태**:

   - isDeactivated = false
   - profileImageUrl = null
   - createdAt, lastLogin = 현재 시각

6. **환영 알림**: 회원가입 완료 후 환영 알림 전송 (Optional)

---

## 🔐 Feature 2: 로그인

### Request

**Method**: `POST /api/v1/users/login`

**Content-Type**: `application/json`

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

**Body**:

- **firebaseUid** (String, Required)
  - Firebase Auth에서 발급한 사용자 고유 ID

### Response

**Success (200 OK)**:

- **id**: 사용자 DB ID
- **firebaseUid**: Firebase UID
- **nickname**: 닉네임
- **name**: 이름
- **phoneNumber**: 전화번호
- **birthDate**: 생년월일 (Optional)
- **profileImageUrl**: 프로필 이미지 URL
- **isDeactivated**: 비활성화 여부
- **createdAt**: 가입 시각
- **lastLogin**: 마지막 로그인 시각 (방금 업데이트됨)

**Error Responses**:

- **401 Unauthorized**: Firebase ID Token 없음 또는 만료
- **403 Forbidden**: 계정이 비활성화됨 (isDeactivated = true)
- **404 Not Found**: 가입되지 않은 사용자 (회원가입 필요)
- **500 Internal Server Error**: 서버 오류

### 비즈니스 규칙

1. **Firebase ID Token 검증**:

   - Authorization 헤더에서 Bearer Token 추출
   - Firebase Admin SDK로 토큰 검증 및 UID 추출
   - 요청의 firebaseUid와 토큰의 UID 일치 확인

2. **사용자 조회**:

   - firebaseUid로 DB에서 사용자 검색
   - 존재하지 않으면 404 에러 (회원가입 필요)

3. **계정 상태 확인**:

   - isDeactivated = true인 경우 403 에러
   - 메시지: "비활성화된 계정입니다. 고객센터에 문의해주세요."

4. **lastLogin 업데이트**:

   - 로그인 시각을 현재 시각으로 업데이트

5. **재가입 허용**:
   - 탈퇴 후 같은 전화번호로 재가입 시, 새로운 Firebase UID로 등록 가능
   - 기존 데이터는 완전히 삭제되므로 새 계정으로 시작

---

## 👤 Feature 3: 내 정보 조회

### Request

**Method**: `GET /api/v1/users/me`

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

- **id**: 사용자 DB ID
- **firebaseUid**: Firebase UID
- **nickname**: 닉네임
- **name**: 이름
- **phoneNumber**: 전화번호 (본인 정보이므로 공개)
- **birthDate**: 생년월일
- **profileImageUrl**: 프로필 이미지 URL
- **isDeactivated**: 비활성화 여부
- **createdAt**: 가입 시각
- **lastLogin**: 마지막 로그인 시각
- **updatedAt**: 정보 수정 시각

**Error Responses**:

- **401 Unauthorized**: Firebase ID Token 없음 또는 만료
- **404 Not Found**: 사용자가 존재하지 않음
- **500 Internal Server Error**: 서버 오류

### 비즈니스 규칙

1. **Firebase ID Token 검증**:

   - Authorization 헤더에서 Bearer Token 추출
   - Firebase Admin SDK로 토큰 검증 및 UID 추출

2. **사용자 조회**:

   - UID로 DB에서 사용자 검색
   - 존재하지 않으면 404 에러

3. **전체 정보 공개**:
   - 본인 정보이므로 전화번호 포함 모든 필드 반환
   - 다른 사용자 프로필 조회와 달리 전화번호도 포함

---

## 🔍 Feature 4: 사용자 프로필 조회

### Request

**Method**: `GET /api/v1/users/{userId}`

**Path Parameters**:

- **userId** (Long, Required): 조회할 사용자의 DB ID

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

- **id**: 사용자 DB ID
- **nickname**: 닉네임
- **name**: 이름
- **profileImageUrl**: 프로필 이미지 URL
- **isDeactivated**: 비활성화 여부

**주의**: 전화번호, 생년월일, Firebase UID는 개인정보 보호를 위해 제외

**Error Responses**:

- **401 Unauthorized**: Firebase ID Token 없음 또는 만료
- **404 Not Found**: 사용자가 존재하지 않음
- **500 Internal Server Error**: 서버 오류

### 비즈니스 규칙

1. **Firebase ID Token 검증**: 로그인한 사용자만 조회 가능

2. **제한된 정보 공개**:

   - 다른 사용자의 프로필이므로 공개 정보만 반환
   - 전화번호, 생년월일, Firebase UID 제외

3. **비활성화 계정 표시**:
   - isDeactivated = true인 경우에도 조회 가능
   - 프론트엔드에서 "비활성화된 사용자" 표시

---

## ✏️ Feature 5: 사용자 정보 수정

### Request

**Method**: `PUT /api/v1/users/me`

**Content-Type**: `application/json`

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

**Body**:

- **name** (String, Optional)

  - 새 이름
  - 길이: 1~100자
  - 앞뒤 공백 제거 필요

- **birthDate** (String, Optional)
  - 새 생년월일
  - 형식: YYYY-MM-DD
  - 제약: 만 14세 이상, 100세 이하

**주의**: 닉네임(nickname), 전화번호(phoneNumber), Firebase UID는 수정 불가

### Response

**Success (200 OK)**:

- **id**: 사용자 DB ID
- **nickname**: 닉네임 (변경 없음)
- **name**: 수정된 이름
- **birthDate**: 수정된 생년월일
- **profileImageUrl**: 프로필 이미지 URL (변경 없음)
- **updatedAt**: 수정 시각 (자동 갱신)

**Error Responses**:

- **400 Bad Request**: 이름 길이 초과, 생년월일 검증 실패
- **401 Unauthorized**: Firebase ID Token 없음 또는 만료
- **404 Not Found**: 사용자가 존재하지 않음
- **500 Internal Server Error**: 서버 오류

### 비즈니스 규칙

1. **Firebase ID Token 검증**: 본인만 수정 가능

2. **수정 가능 필드**: name, birthDate만 수정 가능

3. **수정 불가 필드**: nickname, phoneNumber, firebaseUid, profileImageUrl (별도 API 사용)

4. **이름 검증**:

   - null이 아니고 빈 문자열이 아닌 경우에만 수정
   - 길이: 1~100자
   - 앞뒤 공백 제거

5. **생년월일 검증**:

   - null이 아닌 경우에만 검증 및 수정
   - 미래 날짜 불가
   - 만 14세 이상, 100세 이하

6. **updatedAt 자동 갱신**: 수정 시 현재 시각으로 업데이트

---

## 🖼️ Feature 6: 프로필 이미지 업로드

### Request

**Method**: `POST /api/v1/users/me/profile-image`

**Content-Type**: `multipart/form-data`

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

**Form Data**:

- **imageFile** (File, Required)
  - 이미지 파일 바이너리
  - 형식: JPG, PNG, WEBP
  - 크기: 최대 10MB

### Response

**Success (200 OK)**:

- **profileImageUrl**: 업로드된 이미지의 공개 URL
  - 예: "https://s3.amazonaws.com/.../profiles/123/profile_1234567890.jpg"

**Error Responses**:

- **400 Bad Request**: 파일 크기 초과, 지원하지 않는 형식
- **401 Unauthorized**: Firebase ID Token 없음 또는 만료
- **404 Not Found**: 사용자가 존재하지 않음
- **500 Internal Server Error**: Storage 업로드 실패

### 비즈니스 규칙

1. **Firebase ID Token 검증**: 본인만 업로드 가능

2. **파일 검증**:

   - 파일 존재 확인 (isEmpty 체크)
   - 크기: 최대 10MB
   - 형식: image/jpeg, image/png, image/webp

3. **이미지 처리**:

   - 리사이징: 1024x1024 픽셀로 자동 조정
   - 압축: JPEG 형식으로 변환 및 최적화

4. **Storage 업로드**:

   - 경로: profiles/{userId}/profile\_{timestamp}.jpg
   - AWS S3 또는 Supabase Storage 사용
   - 공개 URL 생성

5. **기존 이미지 삭제**:

   - 이전 프로필 이미지가 있으면 Storage에서 삭제
   - 실패해도 로그만 남기고 계속 진행

6. **DB 업데이트**:

   - profileImageUrl 필드에 새 URL 저장
   - updatedAt 자동 갱신

7. **연관 데이터 전파** (중요):
   - 음성 댓글(comment_records)의 userProfileImage 필드 업데이트
   - 친구 서브컬렉션의 profileImageUrl 필드 업데이트
   - 이는 서비스 레이어에서 처리 (Repository 호출)

---

## 🔎 Feature 7: 닉네임 검색

### Request

**Method**: `GET /api/v1/users/search`

**Query Parameters**:

- **nickname** (String, Required)

  - 검색할 닉네임 (부분 일치)
  - 최대 50자

- **page** (Integer, Optional)

  - 페이지 번호 (0부터 시작, 기본값: 0)

- **size** (Integer, Optional)
  - 페이지당 개수 (1~50, 기본값: 20)

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

- **content**: 사용자 목록 배열

  - id: 사용자 DB ID
  - nickname: 닉네임
  - name: 이름
  - profileImageUrl: 프로필 이미지 URL

- **pageable**: 페이징 정보

  - pageNumber: 현재 페이지 번호
  - pageSize: 페이지 크기

- **totalElements**: 전체 검색 결과 개수
- **totalPages**: 전체 페이지 수
- **last**: 마지막 페이지 여부
- **first**: 첫 페이지 여부

**Error Responses**:

- **400 Bad Request**: 검색어 없음, 검색어 길이 초과
- **401 Unauthorized**: Firebase ID Token 없음 또는 만료
- **500 Internal Server Error**: 서버 오류

### 비즈니스 규칙

1. **Firebase ID Token 검증**: 로그인한 사용자만 검색 가능

2. **검색어 검증**:

   - null 또는 빈 문자열이면 400 에러
   - 길이: 최대 50자

3. **검색 쿼리**:

   - 닉네임 부분 일치 (LIKE %nickname%)
   - 본인은 제외 (currentUserId 제외)
   - 비활성화 계정 제외 (isDeactivated = false)

4. **정렬**: 닉네임 오름차순 (ORDER BY nickname ASC)

5. **페이징**: 최대 50개까지 한번에 조회 가능

6. **성능 최적화**:
   - nickname 필드에 인덱스 생성 필요
   - 검색어가 너무 짧으면(1-2자) 결과가 많을 수 있으므로 주의

---

## ✅ Feature 8: 닉네임 중복 확인

### Request

**Method**: `POST /api/v1/users/check-duplicate`

**Content-Type**: `application/json`

**Body**:

- **nickname** (String, Required)
  - 확인할 닉네임
  - 형식: 영문, 숫자, 언더스코어만 허용
  - 길이: 1~50자

**주의**: 이 API는 인증 불필요 (회원가입 전에도 호출 가능)

### Response

**Success (200 OK)**:

- **available**: 사용 가능 여부 (boolean)

  - true: 사용 가능
  - false: 이미 사용 중

- **message**: 결과 메시지
  - 사용 가능: "사용 가능한 닉네임입니다."
  - 중복: "이미 사용 중인 닉네임입니다."

**Error Responses**:

- **400 Bad Request**: 닉네임 형식 오류, 길이 오류
- **500 Internal Server Error**: 서버 오류

### 비즈니스 규칙

1. **인증 불필요**: Authorization 헤더 없어도 호출 가능

2. **닉네임 검증**:

   - 형식: ^[a-zA-Z0-9_]+$
   - 길이: 1~50자
   - 앞뒤 공백 제거

3. **중복 확인**:

   - DB에서 existsByNickname(nickname) 확인
   - 대소문자 구분 (case-sensitive)

4. **Rate Limiting**: 분당 30회 제한 권장

---

## 🚫 Feature 9: 계정 비활성화

### Request

**Method**: `POST /api/v1/users/me/deactivate`

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

**Body**: 없음

### Response

**Success (200 OK)**:

- **id**: 사용자 DB ID
- **isDeactivated**: 비활성화 여부 (true)
- **deactivatedAt**: 비활성화 시각 (새로 추가된 필드, Optional)

**Error Responses**:

- **401 Unauthorized**: Firebase ID Token 없음 또는 만료
- **404 Not Found**: 사용자가 존재하지 않음
- **500 Internal Server Error**: 서버 오류

### 비즈니스 규칙

1. **Firebase ID Token 검증**: 본인만 비활성화 가능

2. **사용자 상태 업데이트**:

   - isDeactivated = true
   - updatedAt = 현재 시각
   - deactivatedAt = 현재 시각 (Optional, 추적용)

3. **사진 비활성화**:

   - 사용자가 업로드한 모든 사진의 unactive 필드를 true로 설정
   - collectionGroup('photos').where('userID', isEqualTo: userId) 쿼리
   - 배치 업데이트 (450개씩 처리)

4. **로그인 제한**:

   - 비활성화 후 로그인 시 403 에러
   - 메시지: "비활성화된 계정입니다. 고객센터에 문의해주세요."

5. **데이터 보존**:

   - 사용자 데이터는 삭제하지 않고 보존
   - 사진은 숨김 처리만 (실제 삭제 안 함)

6. **재활성화 가능**: Feature 10을 통해 재활성화 가능

---

## ✅ Feature 10: 계정 활성화

### Request

**Method**: `POST /api/v1/users/me/activate`

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

**Body**: 없음

### Response

**Success (200 OK)**:

- **id**: 사용자 DB ID
- **isDeactivated**: 비활성화 여부 (false)
- **activatedAt**: 재활성화 시각 (새로 추가된 필드, Optional)

**Error Responses**:

- **401 Unauthorized**: Firebase ID Token 없음 또는 만료
- **404 Not Found**: 사용자가 존재하지 않음
- **500 Internal Server Error**: 서버 오류

### 비즈니스 규칙

1. **Firebase ID Token 검증**: 본인만 활성화 가능

2. **사용자 상태 업데이트**:

   - isDeactivated = false
   - updatedAt = 현재 시각
   - activatedAt = 현재 시각 (Optional, 추적용)

3. **사진 재활성화**:

   - 사용자가 업로드한 모든 사진의 unactive 필드를 false로 설정
   - collectionGroup('photos').where('userID', isEqualTo: userId) 쿼리
   - 배치 업데이트 (450개씩 처리)

4. **로그인 허용**:
   - 재활성화 후 정상 로그인 가능

---

## 🗑️ Feature 11: 회원 탈퇴

### Request

**Method**: `DELETE /api/v1/users/me`

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

**Body**: 없음

### Response

**Success (204 No Content)**:

- Body 없음 (성공적으로 삭제됨)

**Error Responses**:

- **401 Unauthorized**: Firebase ID Token 없음 또는 만료
- **404 Not Found**: 사용자가 존재하지 않음
- **500 Internal Server Error**: 서버 오류

### 비즈니스 규칙

1. **Firebase ID Token 검증**: 본인만 탈퇴 가능

2. **삭제 순서** (중요, Cascade 삭제):

   **1) 카테고리 멤버십 삭제**:

   - category_members 테이블에서 userId로 삭제
   - 모든 카테고리에서 강제 탈퇴

   **2) 친구 관계 삭제** (양방향):

   - friendships 테이블에서 userId로 삭제
   - friendships 테이블에서 friendId로 삭제

   **3) 업로드한 사진 삭제**:

   - photos 테이블에서 uploaderId로 조회
   - 각 사진의 imageUrl, audioUrl Storage 파일 삭제
   - photos 테이블 레코드 삭제

   **4) 프로필 이미지 삭제**:

   - profileImageUrl Storage 파일 삭제

   **5) 알림 삭제**:

   - notifications 테이블에서 recipientUserId로 삭제
   - notifications 테이블에서 actorUserId로 삭제

   **6) 사용자 삭제**:

   - users 테이블에서 레코드 삭제

   **7) Firebase Auth 삭제** (중요):

   - Firebase Admin SDK로 firebaseUid 사용하여 계정 삭제
   - FirebaseAuth.getInstance().deleteUser(firebaseUid)

3. **트랜잭션**:

   - DB 작업은 트랜잭션으로 처리
   - Storage 파일 삭제는 비동기로 처리 (실패해도 계속 진행)

4. **배치 처리**:

   - 대량 삭제 시 450개씩 배치 처리 (Firestore 500 제한 대비)

5. **Firebase Auth 삭제 전략**:

   - 백엔드에서 Firebase Admin SDK로 삭제 시도
   - 실패 시 orphaned_auths 테이블에 firebaseUid 저장
   - 배치 작업으로 나중에 재시도

6. **재가입 허용**:

   - 같은 전화번호로 재가입 가능
   - 새로운 Firebase UID로 등록됨
   - 기존 데이터는 복구 불가 (완전 삭제됨)

7. **Storage 파일 삭제 로직**:
   - Firebase Storage 시도 → 실패 시 Supabase Storage 시도
   - URL 파싱하여 bucket과 path 추출
   - 실패해도 로그만 남기고 계속 진행

---

## 🔗 Feature 12: 친구 초대 링크 생성

### Request

**Method**: `POST /api/v1/invites/friend`

**Content-Type**: `application/json`

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

**Body**:

- **inviterName** (String, Required)
  - 초대자 이름
  - 길이: 1~100자
- **inviterId** (Long, Required)
  - 초대자 DB ID
  - Firebase ID Token의 UID로 조회한 사용자 ID와 일치해야 함
- **inviterProfileImage** (String, Optional)
  - 초대자 프로필 이미지 URL
  - 최대 500자

### Response

**Success (201 Created)**:

```json
{
  "inviteCode": "a1b2c3d4",
  "inviteLink": "https://soi.app/invite?code=a1b2c3d4",
  "inviterId": 123,
  "inviterName": "홍길동",
  "inviterProfileImage": "https://s3.../profile.jpg",
  "expiresAt": "2025-10-30T10:30:00Z",
  "createdAt": "2025-10-23T10:30:00Z"
}
```

**Error Responses**:

- **400 Bad Request**: 이름 길이 오류, inviterId 없음
- **401 Unauthorized**: Firebase ID Token 없음 또는 만료
- **403 Forbidden**: Token의 UID와 inviterId 불일치
- **404 Not Found**: 사용자가 존재하지 않음
- **429 Too Many Requests**: Rate limit 초과 (분당 10회)
- **500 Internal Server Error**: 서버 오류

### 비즈니스 규칙

1. **Firebase ID Token 검증**:

   - Authorization 헤더에서 Bearer Token 추출
   - Firebase Admin SDK로 토큰 검증 및 UID 추출
   - UID로 사용자 조회 후 DB ID와 inviterId 일치 확인

2. **초대 코드 생성**:

   - 8자리 영숫자 랜덤 생성 (a-z, 0-9)
   - 중복 확인: invites 테이블에서 existsByInviteCode 체크
   - 중복 시 재생성 (최대 3회 시도)

3. **만료 시간 설정**:

   - 생성 시각으로부터 7일 후 자동 만료
   - expiresAt = createdAt + 7 days

4. **데이터 저장**:

   - invites 테이블에 저장
   - 컬럼: inviteCode, inviterId, inviterName, inviterProfileImage, expiresAt, createdAt

5. **단축 URL 생성**:

   - 형식: https://soi.app/invite?code={inviteCode}
   - Deep Link 설정 (앱 설치 시 자동 열림)

6. **기존 초대 코드 재사용**:

   - 동일 사용자가 이미 유효한(미만료) 초대 코드를 가지고 있으면 재사용
   - 만료된 코드는 새로 생성

7. **Rate Limiting**:

   - 분당 10회 제한
   - 사용자별로 카운트

8. **사용 케이스**:
   - 회원가입 완료 화면 (register_screen.dart)
   - 친구 요청 화면 (friend_request_screen.dart)
   - 친구 관리 화면 (friend_management_screen.dart)

---

## 📷 Feature 13: 다중 프로필 이미지 조회

### Request

**Method**: `GET /api/v1/users/profile-images`

**Query Parameters**:

- **userIds** (String, Required)
  - 쉼표로 구분된 사용자 DB ID 목록
  - 예: "1,2,3,4,5"
  - 최대 50개

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

```json
{
  "profiles": [
    {
      "userId": 1,
      "nickname": "user1",
      "profileImageUrl": "https://s3.amazonaws.com/.../profile1.jpg"
    },
    {
      "userId": 2,
      "nickname": "user2",
      "profileImageUrl": ""
    },
    {
      "userId": 3,
      "nickname": "user3",
      "profileImageUrl": "https://s3.amazonaws.com/.../profile3.jpg"
    }
  ]
}
```

**주의**:

- 존재하지 않는 userId는 결과에서 제외됨
- 프로필 이미지가 없는 경우 profileImageUrl은 빈 문자열

**Error Responses**:

- **400 Bad Request**: userIds 파라미터 없음, 50개 초과, 형식 오류
- **401 Unauthorized**: Firebase ID Token 없음 또는 만료
- **500 Internal Server Error**: 서버 오류

### 비즈니스 규칙

1. **Firebase ID Token 검증**: 로그인한 사용자만 조회 가능

2. **userIds 파싱**:

   - 쉼표로 구분된 문자열을 Long 배열로 변환
   - 중복 ID 제거
   - 최대 50개 제한 검증

3. **배치 조회**:

   - SQL: `SELECT id, nickname, profileImageUrl FROM users WHERE id IN (?)`
   - 단일 쿼리로 N+1 문제 해결

4. **결과 매핑**:

   - 각 userId에 대해 nickname, profileImageUrl 포함
   - 존재하지 않는 userId는 결과에서 제외
   - profileImageUrl이 null이면 빈 문자열로 반환

5. **성능 최적화**:

   - users.id 인덱스 활용 (PRIMARY KEY)
   - 필요한 컬럼만 SELECT (id, nickname, profileImageUrl)
   - CDN 캐싱 권장 (Cache-Control: public, max-age=300)

6. **사용 케이스**:
   - 아카이브 카드: 여러 사용자 프로필 초기 로드
   - 친구 목록: 프로필 이미지 일괄 로드
   - 댓글 목록: 댓글 작성자 프로필 일괄 로드
   - 카테고리 멤버 목록: 멤버 프로필 일괄 로드

---

## 📡 Feature 14: 실시간 프로필 업데이트 (WebSocket)

### 개요

사용자가 프로필 이미지를 변경하면 해당 사용자의 친구들에게 실시간으로 알림을 전송합니다.

Flutter의 Firestore `snapshots()` 대신 WebSocket + STOMP 프로토콜을 사용합니다.

### WebSocket 연결

**Endpoint**: `ws://api.soi.app/ws` (또는 `wss://` for production)

**Protocol**: STOMP over WebSocket

**Authentication**:

```
CONNECT
Authorization: Bearer {Firebase ID Token}
accept-version: 1.2
heart-beat: 10000,10000
```

### 구독 (Subscribe)

**Topic**: `/topic/users/{userId}/profile`

**예시**:

```
SUBSCRIBE
id: sub-0
destination: /topic/users/123/profile
```

사용자 ID 123의 프로필 변경 사항을 실시간으로 수신합니다.

### 메시지 형식

**프로필 이미지 업데이트 메시지**:

```json
{
  "type": "PROFILE_UPDATE",
  "userId": 123,
  "nickname": "user123",
  "profileImageUrl": "https://s3.amazonaws.com/.../profile_new.jpg",
  "updatedAt": "2025-10-23T10:30:00Z"
}
```

**필드 설명**:

- **type**: 메시지 유형 (항상 "PROFILE_UPDATE")
- **userId**: 프로필을 변경한 사용자의 DB ID
- **nickname**: 사용자 닉네임
- **profileImageUrl**: 새 프로필 이미지 URL (빈 문자열 가능)
- **updatedAt**: 업데이트 시각 (ISO 8601 형식)

### 비즈니스 규칙

1. **프로필 업데이트 시 메시지 발송** (Feature 6 연계):

   - 사용자가 프로필 이미지를 업로드하면 (POST /api/v1/users/me/profile-image)
   - 해당 사용자를 친구로 등록한 모든 사용자에게 메시지 broadcast
   - Topic: /topic/users/{friendId}/profile

2. **친구 목록 조회**:

   - friendships 테이블에서 해당 사용자를 friendId로 가지고 있는 모든 userId 조회
   - 각 친구의 WebSocket 세션으로 메시지 전송

3. **메시지 전송 로직**:

   ```java
   // Spring Boot 예시
   @Autowired
   private SimpMessagingTemplate messagingTemplate;

   public void notifyProfileUpdate(Long userId, String profileImageUrl) {
       List<Long> friendIds = friendshipRepository.findFriendIdsByUserId(userId);

       ProfileUpdateMessage message = new ProfileUpdateMessage(
           "PROFILE_UPDATE",
           userId,
           userNickname,
           profileImageUrl,
           Instant.now()
       );

       for (Long friendId : friendIds) {
           messagingTemplate.convertAndSend(
               "/topic/users/" + friendId + "/profile",
               message
           );
       }
   }
   ```

4. **연결 관리**:

   - 클라이언트는 앱 실행 시 WebSocket 연결 유지
   - 네트워크 끊김 시 자동 재연결 (exponential backoff)
   - Heartbeat: 10초마다 ping/pong

5. **Fallback 전략**:

   - WebSocket 연결 실패 시 주기적 폴링 (30초마다 Feature 13 호출)
   - 백그라운드에서는 WebSocket 연결 해제

6. **사용 케이스**:
   - 아카이브 카드: 프로필 이미지 실시간 업데이트
   - 친구 목록: 프로필 이미지 실시간 업데이트
   - 댓글 작성자: 프로필 이미지 실시간 업데이트
   - 카테고리 멤버: 프로필 이미지 실시간 업데이트

### 구현 우선순위

**Priority**: High

**이유**:

- archive_profile_row_widget.dart에서 이미 활발히 사용 중
- Firestore snapshots()를 대체하는 핵심 기능
- 사용자 경험 향상 (즉각적인 UI 업데이트)

**초기 구현 시**:

- WebSocket 구현이 복잡하면 폴링으로 시작 가능
- 추후 WebSocket으로 마이그레이션 (성능 개선)

---

## 🎯 API 엔드포인트 요약

| Method | Endpoint                       | 설명                                           |
| ------ | ------------------------------ | ---------------------------------------------- |
| POST   | /api/v1/users/register         | 회원가입 (사용자 정보 등록)                    |
| POST   | /api/v1/users/login            | 로그인 (사용자 정보 조회 + lastLogin 업데이트) |
| GET    | /api/v1/users/me               | 내 정보 조회 (전체 정보)                       |
| GET    | /api/v1/users/{userId}         | 사용자 프로필 조회 (공개 정보만)               |
| PUT    | /api/v1/users/me               | 사용자 정보 수정 (이름, 생년월일)              |
| POST   | /api/v1/users/me/profile-image | 프로필 이미지 업로드                           |
| GET    | /api/v1/users/search           | 닉네임 검색 (페이징)                           |
| POST   | /api/v1/users/check-duplicate  | 닉네임 중복 확인                               |
| POST   | /api/v1/users/me/deactivate    | 계정 비활성화                                  |
| POST   | /api/v1/users/me/activate      | 계정 재활성화                                  |
| DELETE | /api/v1/users/me               | 회원 탈퇴 (완전 삭제)                          |
| POST   | /api/v1/invites/friend         | 친구 초대 링크 생성                            |
| GET    | /api/v1/users/profile-images   | 다중 프로필 이미지 일괄 조회                   |
| WS     | ws://api.soi.app/ws            | 실시간 프로필 업데이트 (WebSocket + STOMP)     |

---

## 📝 공통 규칙

### 인증

- **대부분의 API는 Firebase ID Token 인증 필요**
- Header: `Authorization: Bearer {Firebase ID Token}`
- 예외: 닉네임 중복 확인 (Feature 8)은 인증 불필요

### Firebase ID Token 검증 프로세스

1. Authorization 헤더에서 "Bearer " 제거 후 토큰 추출
2. Firebase Admin SDK의 `verifyIdToken(token)` 호출
3. 토큰 만료 확인
4. UID 추출
5. 요청 Body의 firebaseUid와 일치 확인 (필요 시)

### 에러 응답 형식

**400 Bad Request**: 요청 파라미터 검증 실패

- 닉네임/전화번호 형식 오류
- 생년월일 검증 실패
- 파일 크기/형식 오류

**401 Unauthorized**: 인증 토큰 없음 또는 만료

- Authorization 헤더 누락
- Firebase ID Token 만료
- 토큰 검증 실패

**403 Forbidden**: 권한 없음

- 토큰의 UID와 요청의 UID 불일치
- 비활성화된 계정으로 로그인 시도
- 다른 사용자의 데이터 수정/삭제 시도

**404 Not Found**: 리소스 없음

- 가입되지 않은 사용자
- 존재하지 않는 사용자 ID

**409 Conflict**: 중복

- 닉네임 중복
- 전화번호 중복

**429 Too Many Requests**: Rate limit 초과

- 닉네임 중복 확인: 분당 30회 제한 권장

**500 Internal Server Error**: 서버 오류

- DB 연결 실패
- Storage 업로드 실패
- Firebase Admin SDK 오류

### 페이징 공통 파라미터

- **page**: 페이지 번호 (0부터 시작, 기본값: 0)
- **size**: 페이지 크기 (1~50, 기본값: 20)
- **sort**: 정렬 (기본값: 닉네임 오름차순)

### 날짜/시간 형식

- **ISO 8601 형식 사용**: YYYY-MM-DDTHH:mm:ssZ
- 예: "2025-10-22T14:30:00Z"
- 서버는 UTC 기준, 클라이언트에서 로컬 시간 변환

### 검증 규칙 요약

**닉네임 (nickname)**:

- 형식: ^[a-zA-Z0-9_]+$ (영문, 숫자, 언더스코어)
- 길이: 1~50자
- 중복 불가

**전화번호 (phoneNumber)**:

- 형식: ^01[0-9]{8,9}$ (01로 시작, 10~11자리)
- 예: "01012345678"
- 중복 불가
- 저장 시 정규화: 앞의 0 제거 ("1012345678")

**이름 (name)**:

- 길이: 1~100자
- 앞뒤 공백 제거 필요

**생년월일 (birthDate)**:

- 형식: YYYY-MM-DD
- 제약: 만 14세 이상, 100세 이하
- 미래 날짜 불가

**프로필 이미지 (imageFile)**:

- 형식: JPG, PNG, WEBP (image/jpeg, image/png, image/webp)
- 크기: 최대 10MB
- 처리: 1024x1024 픽셀로 리사이징

### Storage 경로 규칙

**프로필 이미지**:

- 경로: `profiles/{userId}/profile_{timestamp}.jpg`
- 예: `profiles/123/profile_1737876543210.jpg`

**Storage 선택**:

- AWS S3 또는 Supabase Storage 사용 가능
- 공개 URL 생성 필요
- 삭제 시 두 Storage 모두 시도 (Firebase Storage, Supabase Storage)

### 데이터베이스 인덱스

**필수 인덱스**:

- `users.firebaseUid` (UNIQUE): 빠른 로그인 조회
- `users.nickname` (UNIQUE): 중복 확인 및 검색
- `users.phoneNumber` (UNIQUE): 중복 확인
- `users.isDeactivated`: 활성 사용자 필터링

**권장 인덱스**:

- `photos.uploaderId`: 회원 탈퇴 시 사진 조회
- `friendships.userId`: 친구 관계 조회
- `friendships.friendId`: 양방향 친구 관계
- `notifications.recipientUserId`: 알림 조회
- `notifications.actorUserId`: 발신자 알림 조회

### 성능 최적화

1. **N+1 문제 방지**:

   - 사용자 검색 시 프로필 이미지 함께 조회 (JOIN)
   - 페이징 쿼리에 필요한 데이터만 SELECT

2. **배치 처리**:

   - 회원 탈퇴 시 대량 삭제는 450개씩 배치 처리
   - Firestore 500 제한 대비

3. **비동기 처리**:

   - Storage 파일 삭제는 비동기로 처리
   - 실패해도 메인 프로세스에 영향 없도록

4. **캐싱**:
   - 프로필 이미지 URL은 CDN 캐싱 권장
   - Cache-Control 헤더 설정

### 보안 규칙

1. **Firebase ID Token 검증 필수**: 모든 API에서 토큰 검증

2. **본인 확인**: 수정/삭제는 본인만 가능 (UID 일치 확인)

3. **개인정보 보호**:

   - 다른 사용자 프로필 조회 시 전화번호, 생년월일 제외
   - Firebase UID는 외부에 노출하지 않음

4. **Rate Limiting**:

   - 닉네임 중복 확인: 분당 30회 제한
   - 회원가입: 분당 10회 제한
   - 로그인: 분당 60회 제한

5. **SQL Injection 방지**: 파라미터 바인딩 사용

6. **XSS 방지**: 사용자 입력 검증 및 이스케이프

---

## 🔄 추가 고려사항

### 1. 초대 수락 API (Future Enhancement)

**참고**: Feature 12에서 초대 링크 생성은 구현되었지만, 초대 수락 처리는 별도 API 필요

**Endpoint**: `POST /api/v1/invites/{inviteCode}/accept`

**Request**:

- inviteCode: String (URL 파라미터)
- acceptedUserId: Long (수락하는 사용자 ID)

**Response**:

- success: Boolean
- friendshipId: Long (생성된 친구 관계 ID)

**비즈니스 로직**:

- inviteCode로 초대 정보 조회
- 만료 여부 확인 (expiresAt > now)
- 이미 친구인지 확인
- friendships 테이블에 양방향 관계 생성
- 초대자에게 알림 전송

---

### 2. 로그아웃 API (Optional)

현재는 Firebase ID Token 기반 (stateless JWT)이므로 클라이언트에서 토큰 삭제만으로 충분합니다.

**Refresh Token 사용 시에만 필요**:

**Endpoint**: `POST /api/v1/users/logout`

**Request**:

- Firebase ID Token (Authorization Header)

**Response**:

- 204 No Content

**비즈니스 로직**:

- Refresh Token 무효화
- 세션 테이블에서 삭제
- 로그아웃 로그 기록

---

### 3. 전화번호로 사용자 검색 (Internal API)

현재 `findUserByPhone()`은 회원가입/로그인 시 내부적으로 사용됩니다.

별도 Public API로 노출 여부:

- **권장하지 않음**: 개인정보 보호를 위해 전화번호 검색은 제한
- 대신 닉네임 검색(Feature 7) 사용 권장
- 필요 시 친구 추천 등에서 서버 내부적으로만 사용

---

## 📚 참고: Flutter 코드 매핑

이 명세서는 다음 Flutter 파일들을 분석하여 작성되었습니다:

- `lib/repositories/auth_repository.dart`: Firebase Auth, Firestore, Storage 직접 조작
- `lib/services/auth_service.dart`: 비즈니스 로직 및 검증 규칙
- `lib/controllers/auth_controller.dart`: UI 상태 관리 및 캐싱

**주요 기능 매핑**:

| Flutter 메서드                       | Backend API                                  |
| ------------------------------------ | -------------------------------------------- |
| verifyPhoneNumber()                  | (Firebase Auth SDK - 클라이언트 처리)        |
| signInWithSmsCode()                  | (Firebase Auth SDK - 클라이언트 처리)        |
| createUser()                         | POST /api/v1/users/register                  |
| login()                              | POST /api/v1/users/login                     |
| getCurrentUser()                     | GET /api/v1/users/me                         |
| getUserInfo(userId)                  | GET /api/v1/users/{userId}                   |
| updateUserInfo()                     | PUT /api/v1/users/me                         |
| uploadProfileImage()                 | POST /api/v1/users/me/profile-image          |
| searchUsersByNickname()              | GET /api/v1/users/search                     |
| isIdDuplicate()                      | POST /api/v1/users/check-duplicate           |
| deactivateAccount()                  | POST /api/v1/users/me/deactivate             |
| activateAccount()                    | POST /api/v1/users/me/activate               |
| deleteAccount()                      | DELETE /api/v1/users/me                      |
| createFriendInviteLink()             | POST /api/v1/invites/friend                  |
| getMultipleUserProfileImagesStream() | GET /api/v1/users/profile-images + WebSocket |

---

**추가된 기능** (Feature 12-14):

- **Feature 12**: 친구 초대 링크 생성 (실사용 중, 3개 화면에서 활용)
- **Feature 13**: 다중 프로필 이미지 조회 (N+1 문제 해결, 성능 최적화)
- **Feature 14**: 실시간 프로필 업데이트 (WebSocket, 아카이브 위젯에서 활용)

---

**클라이언트 전용 기능** (백엔드 불필요):

- Phone Authentication (Firebase Auth SDK)
- Auto-Login (SharedPreferences)
- Profile Image Caching (Map, max 100 entries)
- UI State Management (ChangeNotifier)
- Search Results Caching
- Invite Link Preparation & Sharing

---

이상으로 SOI 앱의 인증 시스템 백엔드 마이그레이션을 위한 **완전한 기능 명세서**를 완료합니다. 🎉

## 📊 문서 완성도

- **전체 기능**: 14개 (기존 11개 + 신규 3개)
- **핵심 CRUD**: 100% 완료
- **소셜 기능**: 100% 완료 (친구 초대)
- **실시간 기능**: 100% 완료 (WebSocket)
- **성능 최적화**: 배치 조회, N+1 해결
- **문서 상태**: ⭐⭐⭐⭐⭐ **Production Ready**
