# Category Member Management - Features Specification

## 📖 문서 목적

이 문서는 SOI 앱의 **카테고리 멤버 관리 시스템**을 백엔드로 마이그레이션하기 위한 **기능 명세서**입니다.

각 API의 **Request Parameters**와 **Response**를 평문으로 정리하여, 백엔드 개발자가 자유롭게 구현할 수 있도록 합니다.

---

## 🎯 기능 개요

| 순번 | 기능                  | 엔드포인트                                                | 설명                                     |
| ---- | --------------------- | --------------------------------------------------------- | ---------------------------------------- |
| 1    | 멤버 추가             | `POST /api/v1/categories/{categoryId}/members`            | 카테고리에 새 멤버 추가 + 친구 관계 검증 |
| 2    | 멤버 제거 (나가기)    | `DELETE /api/v1/categories/{categoryId}/members/{userId}` | 카테고리에서 나가기 (본인만 가능)        |
| 3    | 멤버 목록 조회        | `GET /api/v1/categories/{categoryId}/members`             | 카테고리 멤버 목록 (페이징)              |
| 4    | 멤버 상세 조회        | `GET /api/v1/categories/{categoryId}/members/{userId}`    | 특정 멤버의 상세 정보 및 설정 조회       |
| 5    | 실시간 멤버 변경 알림 | WebSocket `/ws/categories/{categoryId}/members`           | 멤버 추가/제거 실시간 알림               |

---

## 👥 Feature 1: 멤버 추가

### Request

**Method**: `POST /api/v1/categories/{categoryId}/members`

**Path Parameters**:

- **categoryId** (UUID, Required): 멤버를 추가할 카테고리 ID

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}
- `Content-Type`: application/json

**Body**:

- **userId** (String, Optional): 추가할 사용자의 UID
- **nickname** (String, Optional): 추가할 사용자의 닉네임

**참고**: userId와 nickname 중 하나는 반드시 제공되어야 함

### Response

**Success (201 Created) - 즉시 추가**:

- **requiresAcceptance**: false
- **member**: 추가된 멤버 객체
  - userId: 사용자 ID
  - nickname: 닉네임
  - profileImageUrl: 프로필 이미지 URL
  - joinedAt: 가입 시각
- **message**: "카테고리에 추가되었습니다."

**Success (201 Created) - 초대 생성**:

- **requiresAcceptance**: true
- **inviteId**: 생성된 초대 ID
- **invitedUserId**: 초대받은 사용자 ID
- **inviterUserId**: 초대한 사용자 ID (현재 사용자)
- **pendingMemberIds**: 친구가 아닌 기존 멤버 UID 배열
  - 초대받은 사용자와 아직 친구 관계가 아닌 멤버들의 목록 (참고용)
  - 이 목록의 사람들과 친구가 아니어도 초대 수락만으로 카테고리 가입 가능
- **status**: "pending"
- **createdAt**: 초대 생성 시각
- **message**: "초대를 보냈습니다. 상대방의 수락을 기다리고 있습니다."

**Error Responses**:

- **400 Bad Request**: userId와 nickname 둘 다 없음, 자기 자신 추가 시도
  - 예: {"error": "CANNOT_ADD_SELF", "message": "자기 자신은 이미 카테고리 멤버입니다."}
- **403 Forbidden**:
  - 요청자가 카테고리 멤버가 아님
  - 요청자와 대상 사용자가 친구가 아님
  - 예: {"error": "NOT_FRIENDS", "message": "친구만 추가할 수 있습니다."}
- **404 Not Found**:
  - 카테고리가 존재하지 않음
  - userId 또는 nickname에 해당하는 사용자가 없음
- **409 Conflict**: 이미 카테고리 멤버임
  - 예: {"error": "ALREADY_MEMBER", "message": "이미 카테고리 멤버입니다."}

### 비즈니스 규칙

1. **사용자 조회**:

   - userId가 제공되면 직접 조회
   - nickname이 제공되면 UserSearchRepository로 검색 (limit: 1)
   - 둘 다 없으면 400 에러

2. **권한 검증**:

   - 요청자(currentUserId)가 해당 카테고리의 멤버인지 확인
   - 멤버가 아니면 403 Forbidden

3. **중복 검증**:

   - 자기 자신을 추가하려는 경우: 400 Bad Request
   - 이미 멤버인 경우: 409 Conflict

4. **친구 관계 검증 (1단계)**:

   - 요청자와 대상 사용자 간 상호 친구 관계 확인 (FriendService.areMutualFriends)
   - 친구가 아니면 403 Forbidden (친구만 초대 가능)

5. **친구 관계 검증 (2단계 - 배치)**:

   - 대상 사용자와 기존 모든 멤버 간 상호 친구 관계 배치 확인
   - FriendService.areBatchMutualFriends(targetUserId, existingMemberIds) 사용
   - 친구가 아닌 멤버 목록을 pendingMemberIds에 저장 (정보 제공용)
   - **중요**: 친구가 아니어도 초대 수락만으로 카테고리 가입 가능

6. **분기 처리**:

   **Case A: 모든 멤버와 친구인 경우 (pendingMemberIds가 비어있음)**

   - category_members 테이블에 즉시 추가
   - requiresAcceptance = false
   - 알림 전송: NotificationService.sendCategoryInviteNotification(requiresAcceptance: false)
   - 응답: member 객체 반환

   **Case B: 일부 멤버와 친구가 아닌 경우 (pendingMemberIds가 있음)**

   - category_invites 테이블에 초대 생성
   - 초대 상태: pending
   - blockedMateIds: pendingMemberIds 저장 (참고용 정보)
   - requiresAcceptance = true
   - 초대받은 사용자가 수락하면 친구 관계와 무관하게 카테고리에 추가됨
   - 알림 전송: NotificationService.sendCategoryInviteNotification(requiresAcceptance: true, pendingMemberIds)
   - 응답: inviteId, pendingMemberIds 반환

7. **초대 재사용**:

   - 같은 사용자에게 이미 pending 초대가 있으면 재사용
   - blockedMateIds를 병합하여 업데이트

8. **트랜잭션**:

   - 멤버 추가 또는 초대 생성은 원자적으로 처리
   - 실패 시 전체 롤백

9. **알림**:
   - 즉시 추가: 카테고리의 다른 멤버들에게 "새 멤버 추가" 알림
   - 초대 생성: 초대받은 사용자에게 "카테고리 초대" 알림

---

## 🚪 Feature 2: 멤버 제거 (나가기)

### Request

**Method**: `DELETE /api/v1/categories/{categoryId}/members/{userId}`

**Path Parameters**:

- **categoryId** (UUID, Required): 카테고리 ID
- **userId** (UUID, Required): 제거할 사용자 ID

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK) - 일반 나가기**:

- **categoryId**: 카테고리 ID
- **userId**: 나간 사용자 ID
- **leftAt**: 나간 시각
- **remainingMembers**: 남은 멤버 수
- **message**: "카테고리에서 나갔습니다."

**Success (200 OK) - 마지막 멤버**:

- **categoryId**: 삭제된 카테고리 ID (더 이상 존재하지 않음)
- **userId**: 나간 사용자 ID
- **leftAt**: 나간 시각
- **categoryDeleted**: true
- **message**: "카테고리에서 나갔습니다. 마지막 멤버였으므로 카테고리가 삭제되었습니다."

**Error Responses**:

- **403 Forbidden**: 본인이 아닌 다른 사용자를 제거하려는 경우
  - 예: {"error": "CANNOT_REMOVE_OTHERS", "message": "본인만 나갈 수 있습니다."}
- **404 Not Found**:
  - 카테고리가 존재하지 않음
  - 해당 사용자가 카테고리 멤버가 아님
  - 예: {"error": "NOT_MEMBER", "message": "해당 사용자는 이 카테고리의 멤버가 아닙니다."}

### 비즈니스 규칙

1. **본인 확인**:

   - userId는 반드시 현재 로그인한 사용자(currentUserId)와 일치해야 함
   - 다른 사용자를 제거하려는 경우 403 Forbidden
   - **참고**: 다른 사용자를 강제로 제거하는 기능은 없음 (모두 자발적 나가기만 가능)

2. **멤버 확인**:

   - 해당 사용자가 카테고리의 멤버인지 확인
   - 멤버가 아니면 404 Not Found

3. **멤버 제거**:

   - category_members 테이블에서 해당 레코드 삭제
   - 사용자별 설정도 함께 삭제 (customName, isPinned, lastViewedAt)

4. **남은 멤버 확인**:

   - 멤버 제거 후 category_members 테이블에서 해당 카테고리의 멤버 수 조회
   - SQL: `SELECT COUNT(*) FROM category_members WHERE category_id = ?`(예시)

5. **카테고리 삭제 (마지막 멤버인 경우)**:

   - 남은 멤버 수가 0이면 카테고리 전체 삭제
   - Cascade 삭제:
     - categories 테이블 레코드
     - category_photos 테이블 레코드
     - category_invites 테이블 레코드
     - Storage 파일 (사진, 음성)
   - 응답에 categoryDeleted: true 포함

6. **알림**:

   - 일반 나가기: 남은 멤버들에게 "멤버 나감" 알림
   - 마지막 멤버: 알림 없음 (카테고리 삭제)

7. **트랜잭션**:
   - 멤버 제거와 카테고리 삭제는 원자적으로 처리

---

## 📋 Feature 3: 멤버 목록 조회

### Request

**Method**: `GET /api/v1/categories/{categoryId}/members`

**Path Parameters**:

- **categoryId** (UUID, Required): 조회할 카테고리 ID

**Query Parameters**:

- **page** (Integer, Optional): 페이지 번호 (0부터 시작, 기본값: 0)
- **size** (Integer, Optional): 페이지당 개수 (1~100, 기본값: 20)
- **sort** (String, Optional): 정렬 방식 (기본값: joinedAt,asc)
  - "joinedAt,asc": 가입 순서 (오래된 멤버 먼저)
  - "joinedAt,desc": 최근 가입 순서
  - "nickname,asc": 닉네임 오름차순

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

- **content**: 멤버 목록 배열

  - userId: 사용자 ID
  - nickname: 닉네임
  - profileImageUrl: 프로필 이미지 URL
  - joinedAt: 카테고리 가입 시각
  - isCreator: 카테고리 생성자 여부 (Optional)

- **pageable**: 페이징 정보

  - pageNumber: 현재 페이지 번호
  - pageSize: 페이지 크기
  - sort: 정렬 정보

- **totalElements**: 전체 멤버 수
- **totalPages**: 전체 페이지 수
- **last**: 마지막 페이지 여부
- **first**: 첫 페이지 여부
- **empty**: 빈 결과 여부

**Error Responses**:

- **403 Forbidden**: 카테고리 멤버가 아님 (private 카테고리 조회 시)
- **404 Not Found**: 카테고리가 존재하지 않음

### 비즈니스 규칙

1. **멤버 권한**:

   - Private 카테고리: 멤버만 조회 가능
   - Public 카테고리: 모든 사용자 조회 가능 (Optional)

2. **정렬**:

   - 기본: 가입 순서 (joinedAt ASC) → 카테고리 생성자가 첫 번째
   - 닉네임 정렬도 지원

3. **프로필 이미지**:

   - 사용자의 최신 프로필 이미지 URL 제공
   - User 테이블과 JOIN

4. **생성자 표시**:

   - 카테고리 생성 시 첫 번째로 추가된 멤버를 생성자로 표시 (Optional)

5. **성능 최적화**:
   - User 테이블과 JOIN으로 한 번에 조회 (N+1 방지)
   - SQL: `SELECT cm.*, u.nickname, u.profile_image_url FROM category_members cm JOIN users u ON cm.user_id = u.id WHERE cm.category_id = ? ORDER BY cm.joined_at ASC`

---

## 👤 Feature 4: 멤버 상세 조회

### Request

**Method**: `GET /api/v1/categories/{categoryId}/members/{userId}`

**Path Parameters**:

- **categoryId** (UUID, Required): 카테고리 ID
- **userId** (UUID, Required): 조회할 멤버의 사용자 ID

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### Response

**Success (200 OK)**:

- **userId**: 사용자 ID
- **nickname**: 닉네임
- **profileImageUrl**: 프로필 이미지 URL
- **customName**: 현재 사용자가 설정한 커스텀 이름 (없으면 null)
- **isPinned**: 현재 사용자의 고정 상태 (true/false)
- **lastViewedAt**: 현재 사용자가 마지막으로 확인한 시각 (없으면 null)
- **joinedAt**: 카테고리 가입 시각
- **isCreator**: 카테고리 생성자 여부
- **isCurrentUser**: 현재 로그인한 사용자 본인인지 여부

**Error Responses**:

- **403 Forbidden**: 요청자가 카테고리 멤버가 아님
- **404 Not Found**:
  - 카테고리가 존재하지 않음
  - 해당 userId가 카테고리 멤버가 아님

### 비즈니스 규칙

1. **멤버 권한**: 요청자가 카테고리 멤버인지 확인

2. **사용자별 설정**:

   - customName, isPinned, lastViewedAt는 요청자(currentUserId) 기준으로 반환
   - 각 사용자마다 다른 값을 가질 수 있음

3. **생성자 확인**:

   - 카테고리 생성 시 첫 번째로 추가된 멤버인지 확인
   - 또는 별도 creator_user_id 컬럼 사용

4. **본인 여부**:

   - isCurrentUser: userId == currentUserId

5. **성능 최적화**:
   - User 테이블, CategoryMember 테이블 JOIN
   - SQL: `SELECT cm.*, u.nickname, u.profile_image_url FROM category_members cm JOIN users u ON cm.user_id = u.id WHERE cm.category_id = ? AND cm.user_id = ?`

---

## 🔴 Feature 5: 실시간 멤버 변경 알림 (WebSocket)

### 연결

**Protocol**: WebSocket + STOMP

**Endpoint**: `ws://api.soi.com/ws` 또는 `wss://api.soi.com/ws`

**Headers**:

- `Authorization`: Bearer {Firebase ID Token}

### 구독 (Subscribe)

**Topic**: `/topic/categories/{categoryId}/members`

- 특정 카테고리의 멤버 변경 실시간 이벤트 수신
- 카테고리 멤버만 구독 가능

### 메시지 형식

**새 멤버 추가 알림** (type: MEMBER_ADDED):

- **type**: 이벤트 타입 ("MEMBER_ADDED")
- **categoryId**: 카테고리 ID
- **userId**: 추가된 사용자 ID
- **nickname**: 추가된 사용자 닉네임
- **profileImageUrl**: 프로필 이미지 URL
- **addedBy**: 추가한 사용자 ID (초대자)
- **addedAt**: 추가 시각
- **requiresAcceptance**: 초대 수락이 필요했는지 여부 (true/false)

**멤버 나감 알림** (type: MEMBER_LEFT):

- **type**: 이벤트 타입 ("MEMBER_LEFT")
- **categoryId**: 카테고리 ID
- **userId**: 나간 사용자 ID
- **nickname**: 나간 사용자 닉네임
- **leftAt**: 나간 시각
- **remainingMembers**: 남은 멤버 수

**카테고리 삭제 알림** (type: CATEGORY_DELETED_BY_LAST_MEMBER):

- **type**: 이벤트 타입 ("CATEGORY_DELETED_BY_LAST_MEMBER")
- **categoryId**: 삭제된 카테고리 ID
- **lastMemberId**: 마지막 멤버였던 사용자 ID
- **deletedAt**: 삭제 시각

**초대 생성 알림** (type: INVITE_CREATED):

- **type**: 이벤트 타입 ("INVITE_CREATED")
- **categoryId**: 카테고리 ID
- **inviteId**: 초대 ID
- **invitedUserId**: 초대받은 사용자 ID
- **invitedUserNickname**: 초대받은 사용자 닉네임
- **inviterUserId**: 초대한 사용자 ID
- **pendingMemberIds**: 친구가 아닌 멤버 목록
- **createdAt**: 초대 생성 시각

### 비즈니스 규칙

1. **멤버십 확인**: WebSocket 연결 시 카테고리 멤버 여부 확인

2. **이벤트 종류**:

   - MEMBER_ADDED: 새 멤버가 즉시 추가됨 (모든 멤버와 친구인 경우)
   - MEMBER_LEFT: 멤버가 카테고리에서 나감
   - CATEGORY_DELETED_BY_LAST_MEMBER: 마지막 멤버가 나가서 카테고리 삭제
   - INVITE_CREATED: 초대가 생성됨 (일부 멤버와 친구가 아닌 경우)

3. **재연결 처리**: 연결 끊김 시 자동 재연결 및 누락 메시지 동기화

4. **브로드캐스트**: 같은 카테고리의 모든 멤버에게 동시 전송

5. **성능**: Redis Pub/Sub 또는 메시지 큐를 사용한 확장 가능한 구조

6. **Heartbeat**: 10초마다 핑 메시지로 연결 유지

7. **Fallback**: WebSocket 실패 시 폴링 방식으로 자동 전환
   - GET /api/v1/categories/{categoryId}/members?updatedAfter={timestamp}
   - 30초마다 호출

---

## 🎯 API 엔드포인트 요약

| Method    | Endpoint                                         | 설명                                                  |
| --------- | ------------------------------------------------ | ----------------------------------------------------- |
| POST      | /api/v1/categories/{categoryId}/members          | 멤버 추가 (친구 관계 검증 + 초대 생성)                |
| DELETE    | /api/v1/categories/{categoryId}/members/{userId} | 멤버 제거 (본인만 가능, 마지막 멤버 시 카테고리 삭제) |
| GET       | /api/v1/categories/{categoryId}/members          | 멤버 목록 조회 (페이징)                               |
| GET       | /api/v1/categories/{categoryId}/members/{userId} | 멤버 상세 조회 (사용자별 설정 포함)                   |
| WebSocket | /ws → /topic/categories/{categoryId}/members     | 실시간 멤버 변경 알림                                 |

---

## 📝 공통 규칙

### 인증

- 모든 API는 Firebase ID Token 인증 필요
- Header: `Authorization: Bearer {token}`
- 백엔드는 Firebase Admin SDK로 토큰 검증 후 userId 추출

### 에러 응답 형식

- **400 Bad Request**: 요청 파라미터 검증 실패
  - 예: {"error": "CANNOT_ADD_SELF", "message": "자기 자신은 이미 카테고리 멤버입니다."}
- **401 Unauthorized**: 인증 토큰 없음 또는 만료
- **403 Forbidden**: 권한 없음
  - 카테고리 멤버가 아님
  - 친구가 아닌 사용자 초대 시도
  - 다른 사용자 제거 시도
- **404 Not Found**: 리소스 없음
  - 카테고리 또는 사용자가 존재하지 않음
  - 멤버가 아닌 사용자 조회
- **409 Conflict**: 중복 생성 시도
  - 이미 멤버인 사용자 추가
- **500 Internal Server Error**: 서버 오류

### 페이징 공통 파라미터

- **page**: 페이지 번호 (0부터 시작, 기본값: 0)
- **size**: 페이지 크기 (1~100, 기본값: 20)
- **sort**: 정렬 (기본값: joinedAt,asc)

### 날짜/시간 형식

- ISO 8601 형식 사용 (예: 2025-01-10T15:30:00Z)
- 서버는 UTC 기준, 클라이언트에서 로컬 시간 변환

### 데이터 크기 및 제한

- 닉네임: 최대 50자
- 프로필 이미지 URL: 최대 500자
- 페이지 크기: 1~100 (기본값: 20)

### Rate Limiting

- 멤버 추가: 분당 30개
- 멤버 제거: 분당 30개
- 멤버 조회: 분당 100개

---

## 🔗 연관 기능

카테고리 멤버 관리는 다음 기능들과 연동됩니다:

1. **Friend System**: 친구 관계 검증 (areMutualFriends, areBatchMutualFriends)
2. **Category Invite System**: 초대 생성/수락/거절
3. **Category CRUD**: 카테고리 생성 시 생성자 자동 추가
4. **Notification System**: 멤버 추가/제거 알림
5. **User System**: 사용자 정보 조회 (nickname, profileImageUrl)

이 문서는 **카테고리 멤버 관리 기능만** 다룹니다. 연관 기능은 별도 문서를 참조하세요.

---

## ✅ Flutter 코드 매핑

Flutter 클라이언트에서 백엔드 API로 마이그레이션할 메서드:

| Flutter Service          | Flutter Method          | Backend API                                                                          |
| ------------------------ | ----------------------- | ------------------------------------------------------------------------------------ |
| CategoryMemberService    | addUserByNickname()     | POST /api/v1/categories/{categoryId}/members (body: {nickname})                      |
| CategoryMemberService    | addUserByUid()          | POST /api/v1/categories/{categoryId}/members (body: {userId})                        |
| CategoryMemberService    | removeUser()            | DELETE /api/v1/categories/{categoryId}/members/{userId}                              |
| CategoryMemberService    | isUserMember()          | GET /api/v1/categories/{categoryId}/members/{userId} (클라이언트에서 존재 여부 확인) |
| CategoryMemberController | leaveCategoryByUid()    | DELETE /api/v1/categories/{categoryId}/members/{userId}                              |
| CategoryRepository       | addUidToCategory()      | POST /api/v1/categories/{categoryId}/members (내부 구현)                             |
| CategoryRepository       | removeUidFromCategory() | DELETE /api/v1/categories/{categoryId}/members/{userId} (내부 구현)                  |

---

## 🎓 구현 가이드

### 1. 멤버 추가 플로우차트

```
멤버 추가 요청
    ↓
사용자 조회 (userId or nickname)
    ↓
권한 확인 (요청자가 멤버인가?)
    ↓
중복 확인 (이미 멤버인가?)
    ↓
친구 관계 확인 (요청자 ↔ 대상)
    ↓
친구인가?
    ├─ 아니오 → 403 Forbidden
    └─ 예 ↓
배치 친구 확인 (대상 ↔ 기존 멤버들)
    ↓
pendingMemberIds = 친구 아닌 멤버 목록
    ↓
pendingMemberIds가 비어있는가?
    ├─ 예 → 즉시 추가 → category_members INSERT
    └─ 아니오 → 초대 생성 → category_invites INSERT
    ↓
알림 전송
    ↓
응답 반환
```

### 2. 성능 최적화

- **N+1 문제 방지**: 멤버 목록 조회 시 User 테이블과 JOIN
- **배치 친구 확인**: 여러 멤버의 친구 관계를 한 번에 조회
- **캐싱**: 멤버 목록을 Redis에 캐싱 (TTL: 60초)
- **비동기 알림**: 알림 전송은 비동기 큐로 처리

### 3. 보안

- **권한 검증**: 모든 API에서 카테고리 멤버십 확인
- **본인 확인**: 멤버 제거는 반드시 본인만 가능
- **친구 검증**: 친구가 아닌 사용자는 초대 불가
- **Rate Limiting**: API별 Rate Limit 설정

### 4. 테스트 시나리오

**멤버 추가 테스트**:

1. 정상: 모든 멤버와 친구 → 즉시 추가
2. 정상: 일부 멤버와 친구 아님 → 초대 생성
3. 실패: 요청자가 멤버 아님 → 403
4. 실패: 대상과 친구 아님 → 403
5. 실패: 이미 멤버임 → 409
6. 실패: 자기 자신 추가 → 400

**멤버 제거 테스트**:

1. 정상: 본인 나가기 → 200
2. 정상: 마지막 멤버 나가기 → 카테고리 삭제
3. 실패: 다른 사용자 제거 → 403
4. 실패: 멤버 아님 → 404

---

**문서 버전**: 1.0  
**작성일**: 2025-01-23  
**작성자**: SOI Backend Migration Team
