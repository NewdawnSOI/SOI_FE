# Category CRUD - Features Specification

## 📖 문서 목적

이 문서는 SOI 앱의 **카테고리 CRUD 시스템**을 백엔드로 마이그레이션하기 위한 **기능 명세서**입니다.

각 API의 **Request Parameters**와 **Response**를 평문으로 정리하여, 백엔드 개발자가 자유롭게 구현할 수 있도록 합니다.

---

## 🎯 기능 개요

| 순번 | 기능                     | 엔드포인트                                        | 설명                                     |
| ---- | ------------------------ | ------------------------------------------------- | ---------------------------------------- |
| 1    | 카테고리 생성            | `POST /api/v1/categories`                         | 새 카테고리 생성 + 친구 관계 검증        |
| 2    | 카테고리 조회 (단건)     | `GET /api/v1/categories/{categoryId}`             | 특정 카테고리 상세 정보                  |
| 3    | 카테고리 목록 조회       | `GET /api/v1/users/me/categories`                 | 사용자별 카테고리 목록 (필터링 + 페이징) |
| 4    | 카테고리 수정            | `PUT /api/v1/categories/{categoryId}`             | 카테고리 이름 수정                       |
| 5    | 카테고리 삭제            | `DELETE /api/v1/categories/{categoryId}`          | 카테고리 + 사진 + 초대 전체 삭제         |
| 6    | 커스텀 이름 설정         | `PUT /api/v1/categories/{categoryId}/custom-name` | 사용자별 카테고리 커스텀 이름 설정       |
| 7    | 고정 상태 설정           | `PUT /api/v1/categories/{categoryId}/pin`         | 사용자별 카테고리 고정 상태 설정         |
| 8    | 실시간 카테고리 업데이트 | WebSocket `/ws/categories`                        | 카테고리 변경 실시간 알림                |

---

## 📦 Feature 1: 카테고리 생성

### Request

**Method**: `POST /api/v1/categories`

**Content-Type**: `application/json`

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

**Body**:

- **name** (String, Required)

  - 카테고리 이름
  - 길이: 1~20자 (공백 제거 후)
  - 빈 문자열 불가

- **memberIds** (Array of String, Required)
  - 카테고리에 추가할 멤버의 UID 배열
  - 최소 1명 이상
  - 현재 사용자 UID가 포함되어 있지 않으면 자동 추가
  - 예: ["user_a", "user_b", "user_c"]

### Response

**Success (201 Created)**:

- **id**: 생성된 카테고리 고유 ID (UUID)
- **name**: 카테고리 이름
- **members**: 즉시 추가된 멤버 배열
  - userId: 사용자 ID
  - nickname: 닉네임
  - profileImageUrl: 프로필 이미지 URL
- **invites**: 생성된 초대 배열 (친구가 아닌 멤버가 있을 경우)
  - inviteId: 초대 ID
  - invitedUserId: 초대받은 사용자 ID
  - inviterUserId: 초대한 사용자 ID (현재 사용자)
  - status: 초대 상태 ("pending")
  - blockedMateIds: 친구가 아닌 멤버 UID 목록
  - requiresAcceptance: 수락 필요 여부 (true)
  - createdAt: 초대 생성 시각
- **categoryPhotoUrl**: 표지사진 URL (null)
- **photoCount**: 사진 개수 (0)
- **createdAt**: 생성 시각
- **updatedAt**: 수정 시각

**Error Responses**:

- **400 Bad Request**: 이름 검증 실패 (빈값, 길이 초과), memberIds 빈 배열
- **403 Forbidden**: 멤버 중 차단한 사용자 포함
- **404 Not Found**: memberIds에 존재하지 않는 사용자 포함
- **500 Internal Server Error**: 데이터베이스 오류

### 비즈니스 규칙

1. **이름 검증**:

   - trim() 후 1~20자 검증
   - 빈 문자열, 공백만 있는 문자열 불가

2. **생성자 자동 추가**:

   - 요청한 사용자(currentUserId)가 memberIds에 없으면 자동 추가

3. **친구 관계 배치 확인**:

   - 생성자와 각 멤버 간 상호 친구 관계 확인 (FriendService.areBatchMutualFriends)
   - 친구가 아닌 멤버: blockedMateIds 목록에 추가

4. **멤버 추가 분기**:

   - **모두 친구인 경우**: 즉시 members에 추가, invites 빈 배열
   - **일부 친구가 아닌 경우**:
     - 친구인 멤버만 members에 추가
     - 친구가 아닌 멤버에게 CategoryInvite 생성 (status: pending)
     - 초대 알림 전송 (NotificationService)

5. **초대 생성**:

   - 각 비친구 멤버당 하나의 초대 생성
   - blockedMateIds: 해당 멤버와 친구가 아닌 다른 멤버들의 UID 목록
   - 초대 수락 시 blockedMateIds의 모든 사람과 친구가 되어야 카테고리 가입 가능

6. **트랜잭션 처리**:
   - 카테고리 생성, 멤버 추가, 초대 생성은 원자적으로 처리
   - 실패 시 전체 롤백

---

## 🔍 Feature 2: 카테고리 조회 (단건)

### Request

**Method**: `GET /api/v1/categories/{categoryId}`

**Path Parameters**:

- **categoryId** (UUID, Required): 조회할 카테고리 ID

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

- **id**: 카테고리 고유 ID
- **name**: 카테고리 이름
- **members**: 멤버 배열
  - userId: 사용자 ID
  - nickname: 닉네임
  - profileImageUrl: 프로필 이미지 URL
- **categoryPhotoUrl**: 표지사진 URL (없으면 null)
- **customNames**: 사용자별 커스텀 이름 맵
  - key: userId (String)
  - value: customName (String)
  - 예: {"user_a": "우리 가족", "user_b": "친구들"}
- **userPinnedStatus**: 사용자별 고정 상태 맵
  - key: userId (String)
  - value: isPinned (Boolean)
  - 예: {"user_a": true, "user_b": false}
- **lastPhotoUploadedBy**: 마지막 사진 업로드한 사용자 닉네임 (없으면 null)
- **lastPhotoUploadedAt**: 마지막 사진 업로드 시각 (없으면 null)
- **userLastViewedAt**: 사용자별 마지막 확인 시각 맵
  - key: userId (String)
  - value: lastViewedAt (ISO 8601 Timestamp)
  - 예: {"user_a": "2025-01-10T15:30:00Z"}
- **photoCount**: 카테고리 내 사진 개수
- **createdAt**: 생성 시각
- **updatedAt**: 수정 시각

**Error Responses**:

- **403 Forbidden**: 카테고리 멤버가 아님
- **404 Not Found**: 카테고리가 존재하지 않음

### 비즈니스 규칙

1. **멤버 권한**: 요청자가 해당 카테고리의 멤버인지 확인 (members에 userId 포함)

2. **사진 개수**: photos 서브컬렉션의 문서 개수 계산 (실시간 또는 캐시)

3. **프로필 이미지**: 멤버의 최신 프로필 이미지 URL 제공 (UserService 연동)

4. **성능 최적화**: 멤버 정보를 JOIN으로 한번에 조회 (N+1 문제 방지)

---

## 📋 Feature 3: 카테고리 목록 조회

### Request

**Method**: `GET /api/v1/users/me/categories`

**Query Parameters**:

- **page** (Integer, Optional): 페이지 번호 (0부터 시작, 기본값: 0)
- **size** (Integer, Optional): 페이지당 개수 (1~100, 기본값: 20)
- **sort** (String, Optional): 정렬 방식 (기본값: custom)
  - "custom": 고정된 카테고리 우선, 최신 사진 업로드 순, 생성일 순
  - "createdAt,desc": 생성일 내림차순
  - "createdAt,asc": 생성일 오름차순

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

- **content**: 카테고리 목록 배열

  - id: 카테고리 ID
  - name: 카테고리 이름
  - customName: 현재 사용자의 커스텀 이름 (없으면 null)
  - displayName: 표시할 이름 (customName이 있으면 customName, 없으면 name)
  - isPinned: 현재 사용자의 고정 상태 (true/false)
  - members: 멤버 배열 (간략 정보: userId, nickname, profileImageUrl)
  - categoryPhotoUrl: 표지사진 URL
  - photoCount: 사진 개수
  - hasNewPhoto: 새 사진 여부 (lastPhotoUploadedAt > userLastViewedAt)
  - lastPhotoUploadedBy: 마지막 사진 업로드한 사용자 닉네임
  - lastPhotoUploadedAt: 마지막 사진 업로드 시각
  - createdAt: 생성 시각

- **pageable**: 페이징 정보

  - pageNumber: 현재 페이지 번호
  - pageSize: 페이지 크기
  - sort: 정렬 정보

- **totalElements**: 전체 카테고리 개수
- **totalPages**: 전체 페이지 수
- **last**: 마지막 페이지 여부
- **first**: 첫 페이지 여부
- **empty**: 빈 결과 여부

**Error Responses**:

- **401 Unauthorized**: 인증 토큰 없음 또는 만료
- **500 Internal Server Error**: 데이터베이스 오류

### 비즈니스 규칙

1. **멤버 필터링**: 현재 사용자가 members에 포함된 카테고리만 조회

2. **차단 사용자 필터링**:

   - 1:1 카테고리 (members 2명)에서 상대방을 차단했거나 차단당한 경우 제외
   - FriendService.getBlockedUsers() + FriendService.getBlockedByUsers() 사용

3. **Pending 초대 필터링**:

   - 현재 사용자가 invitee이면서 status가 pending인 초대가 있는 카테고리 제외
   - CategoryInviteRepository.findPendingInvitesByInvitee(userId) 사용

4. **커스텀 정렬** (sort=custom):

   - 1순위: userPinnedStatus[userId] == true인 카테고리가 위로
   - 2순위: lastPhotoUploadedAt 내림차순 (최신 사진이 있는 카테고리 우선)
   - 3순위: createdAt 내림차순 (최근 생성된 카테고리 우선)

5. **새 사진 여부**:

   - lastPhotoUploadedAt > userLastViewedAt[userId] 이면 hasNewPhoto = true
   - 한 번도 확인하지 않았으면 (userLastViewedAt 없음) hasNewPhoto = true

6. **성능 최적화**:
   - 멤버 정보 JOIN (N+1 방지)
   - photoCount는 캐시 또는 별도 컬럼으로 관리

---

## ✏️ Feature 4: 카테고리 수정

### Request

**Method**: `PUT /api/v1/categories/{categoryId}`

**Path Parameters**:

- **categoryId** (UUID, Required): 수정할 카테고리 ID

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}
- `Content-Type`: application/json

**Body**:

- **name** (String, Required)
  - 새 카테고리 이름
  - 길이: 1~20자 (공백 제거 후)

### Response

**Success (200 OK)**:

- **id**: 카테고리 ID
- **name**: 수정된 이름
- **updatedAt**: 수정 시각
- (나머지 카테고리 정보 동일)

**Error Responses**:

- **400 Bad Request**: 이름 검증 실패 (빈값, 길이 초과)
- **403 Forbidden**: 카테고리 멤버가 아님
- **404 Not Found**: 카테고리가 존재하지 않음

### 비즈니스 규칙

1. **멤버 권한**: 카테고리 멤버만 수정 가능

2. **이름 검증**: trim() 후 1~20자 검증

3. **업데이트 시각**: updatedAt 필드 자동 갱신

4. **수정 불가 필드**: members, categoryPhotoUrl, photoCount 등은 별도 API로 관리

---

## 🗑️ Feature 5: 카테고리 삭제

### Request

**Method**: `DELETE /api/v1/categories/{categoryId}`

**Path Parameters**:

- **categoryId** (UUID, Required): 삭제할 카테고리 ID

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (204 No Content)**:

- Body 없음 (성공적으로 삭제됨)

**Error Responses**:

- **403 Forbidden**: 카테고리 멤버가 아님
- **404 Not Found**: 카테고리가 존재하지 않음
- **500 Internal Server Error**: Storage 파일 삭제 실패

### 비즈니스 규칙

1. **멤버 권한**: 카테고리 멤버만 삭제 가능 (일반적으로 나가기 기능 사용)

2. **Cascade 삭제**:

   - 카테고리 레코드 삭제
   - category_members 전체 삭제
   - category_photos 전체 삭제
   - category_invites 전체 삭제
   - Storage 파일 전체 삭제 (이미지, 음성)

3. **트랜잭션 처리**: 데이터베이스와 Storage 삭제는 원자적으로 처리

4. **비동기 처리**: Storage 파일 삭제는 비동기로 처리 가능 (실패 시 재시도)

5. **실시간 알림**: 삭제 시 WebSocket으로 다른 멤버들에게 알림

---

## 🏷️ Feature 6: 커스텀 이름 설정

### Request

**Method**: `PUT /api/v1/categories/{categoryId}/custom-name`

**Path Parameters**:

- **categoryId** (UUID, Required): 카테고리 ID

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}
- `Content-Type`: application/json

**Body**:

- **customName** (String, Required)
  - 사용자별 커스텀 이름
  - 길이: 1~20자 (공백 제거 후)
  - null 또는 빈 문자열 시 커스텀 이름 삭제

### Response

**Success (200 OK)**:

- **categoryId**: 카테고리 ID
- **userId**: 현재 사용자 ID
- **customName**: 설정된 커스텀 이름
- **updatedAt**: 수정 시각

**Error Responses**:

- **400 Bad Request**: customName 길이 초과
- **403 Forbidden**: 카테고리 멤버가 아님
- **404 Not Found**: 카테고리가 존재하지 않음

### 비즈니스 규칙

1. **멤버 권한**: 카테고리 멤버만 자신의 커스텀 이름 설정 가능

2. **사용자별 저장**: customNames 맵에 userId를 키로 저장

   - 예: customNames["user_a"] = "우리 가족"

3. **삭제**: customName이 null 또는 빈 문자열이면 맵에서 해당 키 삭제

4. **검증**: trim() 후 1~20자 검증

5. **다른 사용자 영향 없음**: 커스텀 이름은 설정한 사용자에게만 보임

---

## 📌 Feature 7: 고정 상태 설정

### Request

**Method**: `PUT /api/v1/categories/{categoryId}/pin`

**Path Parameters**:

- **categoryId** (UUID, Required): 카테고리 ID

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}
- `Content-Type`: application/json

**Body**:

- **isPinned** (Boolean, Required)
  - 고정 상태 (true: 고정, false: 고정 해제)

### Response

**Success (200 OK)**:

- **categoryId**: 카테고리 ID
- **userId**: 현재 사용자 ID
- **isPinned**: 설정된 고정 상태
- **updatedAt**: 수정 시각

**Error Responses**:

- **403 Forbidden**: 카테고리 멤버가 아님
- **404 Not Found**: 카테고리가 존재하지 않음

### 비즈니스 규칙

1. **멤버 권한**: 카테고리 멤버만 자신의 고정 상태 설정 가능

2. **사용자별 저장**: userPinnedStatus 맵에 userId를 키로 저장

   - 예: userPinnedStatus["user_a"] = true

3. **정렬 영향**: 카테고리 목록 조회 시 isPinned가 true인 카테고리가 상단에 표시

4. **다른 사용자 영향 없음**: 고정 상태는 설정한 사용자에게만 적용

---

## 🔴 Feature 8: 실시간 카테고리 업데이트 (WebSocket)

### 연결

**Protocol**: WebSocket + STOMP

**Endpoint**: `ws://api.soi.com/ws` 또는 `wss://api.soi.com/ws`

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### 구독 (Subscribe)

**Topic**: `/topic/categories/{userId}`

- 특정 사용자의 카테고리 관련 실시간 이벤트 수신
- 본인의 userId로만 구독 가능

### 메시지 형식

**새 카테고리 생성 알림** (type: CATEGORY_CREATED):

- **type**: 이벤트 타입 ("CATEGORY_CREATED")
- **categoryId**: 새로 생성된 카테고리 ID
- **name**: 카테고리 이름
- **createdBy**: 생성자 userId
- **members**: 멤버 userId 배열
- **createdAt**: 생성 시각

**카테고리 수정 알림** (type: CATEGORY_UPDATED):

- **type**: 이벤트 타입 ("CATEGORY_UPDATED")
- **categoryId**: 수정된 카테고리 ID
- **name**: 새 이름
- **updatedBy**: 수정한 사용자 userId
- **updatedAt**: 수정 시각

**카테고리 삭제 알림** (type: CATEGORY_DELETED):

- **type**: 이벤트 타입 ("CATEGORY_DELETED")
- **categoryId**: 삭제된 카테고리 ID
- **deletedBy**: 삭제한 사용자 userId
- **deletedAt**: 삭제 시각

**멤버 추가 알림** (type: MEMBER_ADDED):

- **type**: 이벤트 타입 ("MEMBER_ADDED")
- **categoryId**: 카테고리 ID
- **addedUserId**: 추가된 사용자 userId
- **addedBy**: 추가한 사용자 userId
- **addedAt**: 추가 시각

**멤버 제거 알림** (type: MEMBER_REMOVED):

- **type**: 이벤트 타입 ("MEMBER_REMOVED")
- **categoryId**: 카테고리 ID
- **removedUserId**: 제거된 사용자 userId
- **removedAt**: 제거 시각

**표지사진 변경 알림** (type: COVER_PHOTO_UPDATED):

- **type**: 이벤트 타입 ("COVER_PHOTO_UPDATED")
- **categoryId**: 카테고리 ID
- **categoryPhotoUrl**: 새 표지사진 URL
- **updatedBy**: 수정한 사용자 userId
- **updatedAt**: 수정 시각

### 비즈니스 규칙

1. **사용자별 구독**: 각 사용자는 자신의 userId로 구독하여 자신이 속한 카테고리의 변경사항만 수신

2. **이벤트 종류**:

   - CATEGORY_CREATED: 새 카테고리 생성 또는 초대 수락
   - CATEGORY_UPDATED: 카테고리 이름 수정
   - CATEGORY_DELETED: 카테고리 삭제
   - MEMBER_ADDED: 새 멤버 추가
   - MEMBER_REMOVED: 멤버 나가기
   - COVER_PHOTO_UPDATED: 표지사진 변경

3. **재연결 처리**: 연결 끊김 시 자동 재연결 및 누락 메시지 동기화 (lastEventId 사용)

4. **브로드캐스트**: 같은 카테고리의 모든 멤버에게 동시 전송

5. **성능**: Redis Pub/Sub 또는 메시지 큐를 사용한 확장 가능한 구조

6. **Heartbeat**: 10초마다 핑 메시지로 연결 유지

7. **Fallback**: WebSocket 실패 시 폴링 방식으로 자동 전환 (30초마다 GET /api/v1/categories?updatedAfter={timestamp})

---

## 🎯 API 엔드포인트 요약

| Method    | Endpoint                                    | 설명                     |
| --------- | ------------------------------------------- | ------------------------ |
| POST      | /api/v1/categories                          | 카테고리 생성            |
| GET       | /api/v1/categories/{categoryId}             | 카테고리 상세 조회       |
| GET       | /api/v1/users/me/categories                 | 카테고리 목록 조회       |
| PUT       | /api/v1/categories/{categoryId}             | 카테고리 수정            |
| DELETE    | /api/v1/categories/{categoryId}             | 카테고리 삭제            |
| PUT       | /api/v1/categories/{categoryId}/custom-name | 커스텀 이름 설정         |
| PUT       | /api/v1/categories/{categoryId}/pin         | 고정 상태 설정           |
| WebSocket | /ws → /topic/categories/{userId}            | 실시간 카테고리 업데이트 |

---

## 📝 공통 규칙

### 인증

- 모든 API는 Firebase ID Token 인증 필요
- Header: `Authorization: Bearer {token}`
- 백엔드는 Firebase Admin SDK로 토큰 검증 후 userId 추출

### 에러 응답 형식

- **400 Bad Request**: 요청 파라미터 검증 실패
  - 예: {"error": "INVALID_NAME", "message": "카테고리 이름은 1-20자여야 합니다."}
- **401 Unauthorized**: 인증 토큰 없음 또는 만료
- **403 Forbidden**: 권한 없음 (카테고리 멤버가 아님)
- **404 Not Found**: 리소스 없음 (카테고리가 존재하지 않음)
- **409 Conflict**: 중복 생성 시도
- **429 Too Many Requests**: Rate limit 초과
- **500 Internal Server Error**: 서버 오류

### 페이징 공통 파라미터

- **page**: 페이지 번호 (0부터 시작, 기본값: 0)
- **size**: 페이지 크기 (1~100, 기본값: 20)
- **sort**: 정렬 (기본값: custom 또는 createdAt,desc)

### 날짜/시간 형식

- ISO 8601 형식 사용 (예: 2025-01-10T15:30:00Z)
- 서버는 UTC 기준, 클라이언트에서 로컬 시간 변환

### 데이터 크기 및 제한

- 카테고리 이름: 1~20자 (trim 후)
- 커스텀 이름: 1~20자 (trim 후)
- 멤버 수: 최소 1명, 최대 제한 없음 (권장: 50명 이하)
- 페이지 크기: 1~100 (기본값: 20)

### Rate Limiting

- 카테고리 생성: 분당 10개
- 카테고리 수정: 분당 30개
- 카테고리 조회: 분당 100개

### 캐싱

- 카테고리 상세: Cache-Control: private, max-age=60
- 카테고리 목록: Cache-Control: private, max-age=30
- 조건부 요청 지원: ETag, If-None-Match

---

## 🔗 연관 기능

카테고리 CRUD는 다음 기능들과 연동됩니다:

1. **Friend System**: 친구 관계 검증 (areBatchMutualFriends)
2. **Category Invite System**: 초대 생성/수락/거절
3. **Category Member System**: 멤버 추가/제거
4. **Category Photo System**: 사진 업로드/삭제/표지사진 관리
5. **Notification System**: 초대, 멤버 추가, 사진 업로드 알림
6. **Block System**: 차단 사용자 필터링

이 문서는 **카테고리 CRUD 기능만** 다룹니다. 연관 기능은 별도 문서를 참조하세요.

---

## ✅ Flutter 코드 매핑

Flutter 클라이언트에서 백엔드 API로 마이그레이션할 메서드:

| Flutter Service | Flutter Method             | Backend API                                     |
| --------------- | -------------------------- | ----------------------------------------------- |
| CategoryService | createCategory()           | POST /api/v1/categories                         |
| CategoryService | getCategory()              | GET /api/v1/categories/{categoryId}             |
| CategoryService | getUserCategories()        | GET /api/v1/users/me/categories                 |
| CategoryService | updateCategory()           | PUT /api/v1/categories/{categoryId}             |
| CategoryService | deleteCategory()           | DELETE /api/v1/categories/{categoryId}          |
| CategoryService | updateCustomCategoryName() | PUT /api/v1/categories/{categoryId}/custom-name |
| CategoryService | updateUserPinStatus()      | PUT /api/v1/categories/{categoryId}/pin         |
| CategoryService | getUserCategoriesStream()  | WebSocket /ws → /topic/categories/{userId}      |
| CategoryService | getCategoryStream()        | WebSocket /ws → /topic/categories/{userId}      |

---

## 🎓 구현 가이드

### 1. 데이터베이스 스키마

**categories 테이블**:

- id (UUID, PK)
- name (VARCHAR(20))
- category_photo_url (TEXT)
- last_photo_uploaded_by (VARCHAR)
- last_photo_uploaded_at (TIMESTAMP)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)

**category_members 테이블**:

- id (UUID, PK)
- category_id (UUID, FK → categories.id)
- user_id (UUID, FK → users.id)
- custom_name (VARCHAR(20), NULLABLE)
- is_pinned (BOOLEAN, DEFAULT false)
- last_viewed_at (TIMESTAMP, NULLABLE)
- created_at (TIMESTAMP)

**category_invites 테이블**:

- id (UUID, PK)
- category_id (UUID, FK → categories.id)
- inviter_user_id (UUID, FK → users.id)
- invitee_user_id (UUID, FK → users.id)
- status (ENUM: pending, accepted, declined)
- blocked_mate_ids (JSONB: ["user_a", "user_b"])
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
- expires_at (TIMESTAMP, DEFAULT NOW() + INTERVAL '7 days')

**인덱스**:

- category_members(user_id, category_id)
- category_members(category_id)
- category_invites(invitee_user_id, status)
- category_invites(category_id, status)

### 2. 성능 최적화

- **N+1 문제 방지**: JOIN FETCH로 멤버 정보 함께 조회
- **캐싱**: Redis로 카테고리 목록 캐싱 (TTL: 60초)
- **페이징**: Offset 대신 Cursor 기반 페이징 권장 (대량 데이터 시)
- **비동기 처리**: Storage 파일 삭제는 비동기 큐로 처리

### 3. 보안

- **권한 검증**: 모든 API에서 카테고리 멤버십 확인
- **SQL Injection**: PreparedStatement 사용
- **XSS 방지**: 카테고리 이름 sanitize
- **Rate Limiting**: API별 Rate Limit 설정

### 4. 모니터링

- **메트릭**: 카테고리 생성 성공/실패율, API 응답 시간
- **로그**: 에러 로그, 친구 관계 검증 실패 로그
- **알림**: 초대 생성 실패 시 Slack 알림

---

**문서 버전**: 1.0  
**작성일**: 2025-01-23  
**작성자**: SOI Backend Migration Team
