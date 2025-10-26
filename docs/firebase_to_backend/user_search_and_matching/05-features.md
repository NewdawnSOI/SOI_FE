# User Search & Matching System - Features Implementation

## 📖 문서 목적

이 문서는 SOI 앱의 **사용자 검색 및 연락처 매칭 시스템**을 Spring Boot로 마이그레이션하기 위한 **기능 명세서**입니다.

Flutter 코드(`UserMatchingService`, `UserSearchRepository`, `UserMatchingController`)를 분석하여 백엔드에서 구현해야 할 8가지 핵심 기능을 정의합니다.

---

## 🎯 기능 개요

| 기능                       | 엔드포인트                                | Flutter 소스                                                  | 설명                                   |
| -------------------------- | ----------------------------------------- | ------------------------------------------------------------- | -------------------------------------- |
| 1. 연락처 기반 사용자 매칭 | `POST /api/v1/users/find-by-contacts`    | matchContactsWithUsers()<br>searchUsersByPhoneNumbers()       | 전화번호 리스트로 SOI 사용자 찾기      |
| 2. 사용자 검색             | `GET /api/v1/users/search`               | searchUsersById()<br>searchUsers()                            | ID/닉네임으로 사용자 검색              |
| 3. 사용자 상세 조회        | `GET /api/v1/users/{userId}`             | searchUserById()                                              | 특정 사용자 프로필 조회                |
| 4. 추천 친구 목록          | `GET /api/v1/users/recommended`          | getSuggestedFriends()                                         | 연락처 기반 친구 추천                  |
| 5. 최근 가입자 조회        | `GET /api/v1/users/recent`               | getRecentUsers()                                              | 최근 가입한 사용자 조회                |
| 6. 전화번호 등록           | `PUT /api/v1/users/me/phone`             | registerPhoneNumber()                                         | 사용자 전화번호 등록 (해시화)          |
| 7. 전화번호 삭제           | `DELETE /api/v1/users/me/phone`          | removePhoneNumber()                                           | 전화번호 삭제                          |
| 8. 검색 설정 업데이트      | `PUT /api/v1/users/me/settings/search`   | updateSearchSettings()                                        | 전화번호 검색 허용/비허용 설정         |

---

## 📦 Feature 1: 연락처 기반 사용자 매칭 (Find Users by Contacts)

### Flutter 소스 분석

**UserMatchingService.matchContactsWithUsers()**:

```dart
Future<List<ContactMatchResult>> matchContactsWithUsers(
  List<Contact> contacts,
) async {
  try {
    // 1. 연락처에서 전화번호 추출
    final phoneNumbers = <String>[];
    final contactPhoneMap = <String, Contact>{};

    for (final contact in contacts) {
      for (final phone in contact.phones) {
        if (phone.number.isNotEmpty) {
          final cleanNumber = _cleanPhoneNumber(phone.number);
          phoneNumbers.add(cleanNumber);
          contactPhoneMap[cleanNumber] = contact;
        }
      }
    }

    if (phoneNumbers.isEmpty) {
      return [];
    }

    // 2. 전화번호로 Firebase 사용자 검색
    final foundUsers = await _userSearchRepository.searchUsersByPhoneNumbers(
      phoneNumbers,
    );

    // 3. 이미 친구인 사용자들 필터링
    final friendUserIds = await _getFriendUserIds();
    final filteredUsers = foundUsers.where((user) {
      return !friendUserIds.contains(user.uid);
    }).toList();

    // 4. 이미 요청을 보낸 사용자들 필터링
    final requestedUserIds = await _getRequestedUserIds();
    final finalUsers = filteredUsers.where((user) {
      return !requestedUserIds.contains(user.uid);
    }).toList();

    // 5. 결과 매핑
    return results;
  } catch (e) {
    throw Exception('연락처 매칭 실패: $e');
  }
}
```

**UserSearchRepository.searchUsersByPhoneNumbers()**:

```dart
Future<List<UserSearchModel>> searchUsersByPhoneNumbers(
  List<String> phoneNumbers,
) async {
  if (phoneNumbers.isEmpty) {
    return [];
  }

  try {
    final hashedNumbers = phoneNumbers.map(_hashPhoneNumber).toList();

    // Firestore의 'in' 쿼리 제한으로 인해 배치 처리 (최대 10개씩)
    final List<UserSearchModel> results = [];

    for (int i = 0; i < hashedNumbers.length; i += 10) {
      final batch = hashedNumbers.skip(i).take(10).toList();

      final querySnapshot = await _usersCollection
          .where('phone', whereIn: batch)
          .where('allowPhoneSearch', isEqualTo: true)
          .get();

      final batchResults = querySnapshot.docs.map((doc) {
        return UserSearchModel.fromFirestore(doc);
      }).toList();

      results.addAll(batchResults);
    }

    // 현재 사용자 제외
    final currentUid = _currentUserUid;
    if (currentUid != null) {
      results.removeWhere((user) => user.uid == currentUid);
    }

    return results;
  } catch (e) {
    throw Exception('전화번호 일괄 검색 실패: $e');
  }
}
```

**UserSearchRepository._hashPhoneNumber()**:

```dart
String _hashPhoneNumber(String phoneNumber) {
  // 전화번호에서 숫자만 추출
  var cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

  // 앞자리 0 제거
  if (cleanNumber.startsWith('0')) {
    cleanNumber = cleanNumber.substring(1);
  }

  // ⚠️ 현재는 해시화하지 않고 그대로 반환 (보안 취약점)
  return cleanNumber;

  // SHA-256 해시 생성 (추후 사용 예정)
  // final bytes = utf8.encode(cleanNumber);
  // final hash = sha256.convert(bytes);
  // return hash.toString();
}
```

**UserMatchingService._getFriendUserIds() / _getRequestedUserIds()**:

```dart
Future<Set<String>> _getFriendUserIds() async {
  try {
    final friends = await _friendRepository.getFriendsList().first;
    return friends.map((friend) => friend.userId).toSet();
  } catch (e) {
    return {};
  }
}

Future<Set<String>> _getRequestedUserIds() async {
  try {
    final sentRequests = await _friendRequestRepository.getSentRequests().first;
    return sentRequests.map((request) => request.receiverUid).toSet();
  } catch (e) {
    return {};
  }
}
```

### 백엔드 구현 명세

#### Input Format

**Endpoint**: `POST /api/v1/users/find-by-contacts`

**Headers**:
```
Authorization: Bearer {Firebase ID Token}
```

**Request Body**:
```java
public class FindUsersByContactsRequest {
    @NotNull(message = "전화번호 리스트는 필수입니다.")
    @Size(min = 1, max = 500, message = "전화번호는 1~500개까지 가능합니다.")
    private List<@Pattern(regexp = "^[0-9+\\-\\s()]+$") String> phoneNumbers;
}
```

**Example**:
```json
{
  "phoneNumbers": [
    "01012345678",
    "010-8765-4321",
    "+82 10 5555 6666",
    "01099998888"
  ]
}
```

#### Process Flow

**단계 1: 전화번호 정리 및 해시화**

```java
@Service
public class PhoneHashService {
    
    public String hashPhoneNumber(String phoneNumber) {
        // 1. 숫자만 추출
        String cleanNumber = phoneNumber.replaceAll("[^0-9]", "");
        
        // 2. 앞자리 0 제거 (한국 번호 정규화)
        if (cleanNumber.startsWith("0")) {
            cleanNumber = cleanNumber.substring(1);
        }
        
        // 3. SHA-256 해시 생성
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(cleanNumber.getBytes(StandardCharsets.UTF_8));
            return bytesToHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 해시 생성 실패", e);
        }
    }
    
    private String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte b : bytes) {
            result.append(String.format("%02x", b));
        }
        return result.toString();
    }
}
```

**단계 2: 사용자 매칭 및 관계 상태 조회**

```java
@Repository
public interface UserRepository extends JpaRepository<User, UUID> {
    
    @Query("""
        SELECT u.id as userId,
               u.userId as userIdString,
               u.nickname as nickname,
               u.profileImageUrl as profileImageUrl,
               u.createdAt as createdAt,
               u.phoneHash as phoneHash,
               CASE 
                 WHEN f.id IS NOT NULL THEN 'ALREADY_FRIEND'
                 WHEN fr_sent.id IS NOT NULL AND fr_sent.status = 'PENDING' THEN 'REQUEST_SENT'
                 WHEN fr_received.id IS NOT NULL AND fr_received.status = 'PENDING' THEN 'REQUEST_RECEIVED'
                 ELSE 'CAN_SEND_REQUEST'
               END as relationStatus
        FROM User u
        LEFT JOIN Friendship f 
          ON (f.userId = :currentUserId AND f.friendId = u.id)
          OR (f.userId = u.id AND f.friendId = :currentUserId)
        LEFT JOIN FriendRequest fr_sent
          ON (fr_sent.senderId = :currentUserId AND fr_sent.receiverId = u.id)
        LEFT JOIN FriendRequest fr_received
          ON (fr_received.senderId = u.id AND fr_received.receiverId = :currentUserId)
        WHERE u.phoneHash IN :phoneHashes
          AND u.allowPhoneSearch = true
          AND u.id != :currentUserId
        ORDER BY u.createdAt DESC
        """)
    List<MatchedUserProjection> findUsersByPhoneHashesWithRelation(
        @Param("phoneHashes") List<String> phoneHashes,
        @Param("currentUserId") UUID currentUserId
    );
}
```

**단계 3: Service 레이어에서 처리**

```java
@Service
@RequiredArgsConstructor
public class UserSearchService {
    
    private final UserRepository userRepository;
    private final PhoneHashService phoneHashService;
    
    @Transactional(readOnly = true)
    public FindUsersByContactsResponse findUsersByContacts(
        FindUsersByContactsRequest request,
        UUID currentUserId
    ) {
        // 1. 전화번호 해시화
        List<String> phoneHashes = request.getPhoneNumbers().stream()
            .map(phoneHashService::hashPhoneNumber)
            .distinct()
            .collect(Collectors.toList());
        
        log.info("전화번호 {} 개를 해시화하여 검색: {} 개 고유 해시", 
            request.getPhoneNumbers().size(), phoneHashes.size());
        
        // 2. 사용자 조회 (관계 상태 포함)
        List<MatchedUserProjection> projections = 
            userRepository.findUsersByPhoneHashesWithRelation(
                phoneHashes, 
                currentUserId
            );
        
        // 3. DTO 변환
        List<MatchedUserDTO> matchedUsers = projections.stream()
            .map(this::toMatchedUserDTO)
            .collect(Collectors.toList());
        
        log.info("총 {} 명의 사용자 매칭됨", matchedUsers.size());
        
        return FindUsersByContactsResponse.builder()
            .matchedUsers(matchedUsers)
            .totalMatched(matchedUsers.size())
            .build();
    }
    
    private MatchedUserDTO toMatchedUserDTO(MatchedUserProjection projection) {
        return MatchedUserDTO.builder()
            .userId(projection.getUserId())
            .userIdString(projection.getUserIdString())
            .nickname(projection.getNickname())
            .profileImageUrl(projection.getProfileImageUrl())
            .relationStatus(RelationStatus.valueOf(projection.getRelationStatus()))
            .createdAt(projection.getCreatedAt())
            .build();
    }
}
```

**단계 4: Controller**

```java
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserSearchController {
    
    private final UserSearchService userSearchService;
    
    @PostMapping("/find-by-contacts")
    public ResponseEntity<FindUsersByContactsResponse> findByContacts(
        @Valid @RequestBody FindUsersByContactsRequest request,
        @AuthenticationPrincipal UserDetails currentUser
    ) {
        UUID currentUserId = UUID.fromString(currentUser.getUsername());
        
        FindUsersByContactsResponse response = 
            userSearchService.findUsersByContacts(request, currentUserId);
        
        return ResponseEntity.ok(response);
    }
}
```

#### Output Format

**Success Response** (200 OK):

```json
{
  "matchedUsers": [
    {
      "userId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "userIdString": "jihoon_kim",
      "nickname": "지훈",
      "profileImageUrl": "https://soi-storage.s3.amazonaws.com/profiles/...",
      "relationStatus": "CAN_SEND_REQUEST",
      "createdAt": "2025-10-15T12:30:00Z"
    },
    {
      "userId": "550e8400-e29b-41d4-a716-446655440000",
      "userIdString": "minji_park",
      "nickname": "민지",
      "profileImageUrl": "https://...",
      "relationStatus": "ALREADY_FRIEND",
      "createdAt": "2025-10-10T09:00:00Z"
    },
    {
      "userId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "userIdString": "yuna_lee",
      "nickname": "유나",
      "profileImageUrl": "https://...",
      "relationStatus": "REQUEST_SENT",
      "createdAt": "2025-10-20T14:00:00Z"
    }
  ],
  "totalMatched": 3
}
```

**RelationStatus Enum**:
- `CAN_SEND_REQUEST`: 친구 요청 가능
- `REQUEST_SENT`: 이미 친구 요청 보냄
- `REQUEST_RECEIVED`: 상대방이 친구 요청 보냄
- `ALREADY_FRIEND`: 이미 친구

**Error Responses**:

- **400 Bad Request**: 전화번호 형식 오류, 개수 제한 초과
  ```json
  {
    "error": "INVALID_PHONE_NUMBERS",
    "message": "전화번호는 1~500개까지 가능합니다.",
    "timestamp": "2025-10-22T14:30:00Z"
  }
  ```

- **401 Unauthorized**: 인증 토큰 없음 또는 만료
- **429 Too Many Requests**: Rate limiting (분당 10회 제한)
  ```json
  {
    "error": "RATE_LIMIT_EXCEEDED",
    "message": "요청 횟수 제한을 초과했습니다. 1분 후 다시 시도해주세요.",
    "retryAfter": 60
  }
  ```

#### 구현 시 주의사항

**1. 전화번호 해시화 보안**

```java
// ❌ 클라이언트가 보낸 해시를 신뢰하면 안 됨
// 클라이언트가 해시를 조작할 수 있음

// ✅ 서버에서 반드시 재해시
String clientHash = request.getPhoneHash(); // 무시
String serverHash = phoneHashService.hashPhoneNumber(request.getPhoneNumber());
```

**2. Firestore의 'in' 쿼리 제한 (10개) vs PostgreSQL**

```java
// Firestore: 최대 10개씩 배치 처리 필요
// PostgreSQL: IN 절에 제한 없음 (하지만 성능을 위해 배치 권장)

// 500개 전화번호를 한 번에 조회 가능
WHERE u.phone_hash IN (:phoneHashes) // 500개 가능

// 하지만 성능을 위해 100개씩 배치 처리 권장
int batchSize = 100;
for (int i = 0; i < phoneHashes.size(); i += batchSize) {
    List<String> batch = phoneHashes.subList(
        i, 
        Math.min(i + batchSize, phoneHashes.size())
    );
    // 배치 조회
}
```

**3. N+1 문제 방지**

```java
// ❌ N+1 문제 발생
List<User> users = userRepository.findByPhoneHashIn(phoneHashes);
for (User user : users) {
    boolean isFriend = friendshipRepository.existsByUserIdAndFriendId(currentUserId, user.getId());
    // N번의 추가 쿼리 발생!
}

// ✅ JOIN FETCH로 한 번에 조회
@Query("""
    SELECT u FROM User u
    LEFT JOIN FETCH u.friendships
    WHERE u.phoneHash IN :phoneHashes
    """)
```

**4. 인덱스 최적화**

```sql
-- phone_hash 단일 인덱스
CREATE INDEX idx_users_phone_hash 
ON users(phone_hash) 
WHERE phone_hash IS NOT NULL;

-- allow_phone_search와 복합 인덱스
CREATE INDEX idx_users_phone_search 
ON users(phone_hash, allow_phone_search) 
WHERE allow_phone_search = true;

-- 쿼리 플랜 확인
EXPLAIN ANALYZE
SELECT * FROM users 
WHERE phone_hash IN ('hash1', 'hash2', ...)
  AND allow_phone_search = true;
```

**5. Rate Limiting (Redis)**

```java
@Component
public class RateLimitInterceptor {
    
    @Autowired
    private RedisTemplate<String, String> redisTemplate;
    
    public boolean isAllowed(UUID userId, String endpoint) {
        String key = String.format("rate_limit:%s:%s", userId, endpoint);
        Long count = redisTemplate.opsForValue().increment(key);
        
        if (count == 1) {
            redisTemplate.expire(key, 1, TimeUnit.MINUTES);
        }
        
        return count <= 10; // 분당 10회 제한
    }
}
```

---

## 📦 Feature 2: 사용자 검색 (User Search by ID/Nickname)

### Flutter 소스 분석

**UserSearchRepository.searchUsersById()**:

```dart
Future<List<UserSearchModel>> searchUsersById(
  String id, {
  int limit = 20,
}) async {
  if (id.isEmpty) {
    return [];
  }

  try {
    final List<UserSearchModel> results = [];

    // 1. 정확한 일치 검색
    final exactMatch = await _usersCollection
        .where('id', isEqualTo: id)
        .limit(limit)
        .get();

    results.addAll(
      exactMatch.docs.map((doc) {
        return UserSearchModel.fromFirestore(doc);
      }),
    );

    // 2. prefix 검색 (결과가 부족한 경우)
    if (results.length < limit) {
      final remaining = limit - results.length;
      final prefixMatch = await _usersCollection
          .where('id', isGreaterThanOrEqualTo: id)
          .where('id', isLessThan: '${id}z')
          .limit(remaining + 10)
          .get();

      final prefixResults = prefixMatch.docs
          .map((doc) => UserSearchModel.fromFirestore(doc))
          .where(
            (user) => !results.any((existing) => existing.uid == user.uid),
          )
          .take(remaining)
          .toList();

      results.addAll(prefixResults);
    }

    // 현재 사용자 제외
    final currentUid = _currentUserUid;
    if (currentUid != null) {
      results.removeWhere((user) => user.uid == currentUid);
    }

    return results;
  } catch (e) {
    throw Exception('닉네임 검색 실패: $e');
  }
}
```

**UserMatchingController.searchUsers()**:

```dart
Future<void> searchUsers(String query) async {
  try {
    _isSearching = true;
    _currentSearchQuery = query;
    _clearError();
    notifyListeners();

    if (query.trim().isEmpty) {
      _searchResults = [];
    } else {
      _searchResults = await _userSearchRepository.searchUsersById(query);
      // debugPrint('사용자 검색 완료: ${_searchResults.length}명 발견');
    }
  } catch (e) {
    _setError('사용자 검색 실패: $e');
    _searchResults = [];
  } finally {
    _isSearching = false;
    notifyListeners();
  }
}
```

### 백엔드 구현 명세

#### Input Format

**Endpoint**: `GET /api/v1/users/search`

**Query Parameters**:
```java
@RequestParam(required = true) String query,
@RequestParam(defaultValue = "20") @Min(1) @Max(50) int limit
```

**Example**:
```
GET /api/v1/users/search?query=jihoon&limit=10
```

#### Process Flow

**단계 1: 검색 쿼리 실행**

```java
@Repository
public interface UserRepository extends JpaRepository<User, UUID> {
    
    @Query("""
        SELECT u FROM User u
        WHERE (LOWER(u.userId) LIKE LOWER(CONCAT(:query, '%'))
           OR LOWER(u.nickname) LIKE LOWER(CONCAT('%', :query, '%')))
          AND u.id != :currentUserId
        ORDER BY 
          CASE 
            WHEN LOWER(u.userId) = LOWER(:query) THEN 0
            WHEN LOWER(u.userId) LIKE LOWER(CONCAT(:query, '%')) THEN 1
            ELSE 2
          END,
          u.createdAt DESC
        """)
    List<User> searchByIdOrNickname(
        @Param("query") String query,
        @Param("currentUserId") UUID currentUserId,
        Pageable pageable
    );
}
```

**단계 2: PostgreSQL Full-Text Search (고급)**

```sql
-- Full-Text Search 인덱스 생성
CREATE INDEX idx_users_fulltext 
ON users 
USING GIN (to_tsvector('simple', user_id || ' ' || nickname));

-- 검색 쿼리
SELECT * FROM users
WHERE to_tsvector('simple', user_id || ' ' || nickname) 
      @@ to_tsquery('simple', 'jihoon:*')
ORDER BY ts_rank(to_tsvector('simple', user_id || ' ' || nickname), 
                 to_tsquery('simple', 'jihoon:*')) DESC
LIMIT 20;
```

**단계 3: Service 레이어**

```java
@Service
@RequiredArgsConstructor
public class UserSearchService {
    
    private final UserRepository userRepository;
    
    @Transactional(readOnly = true)
    public UserSearchResponse searchUsers(
        String query,
        int limit,
        UUID currentUserId
    ) {
        Pageable pageable = PageRequest.of(0, limit);
        
        List<User> users = userRepository.searchByIdOrNickname(
            query, 
            currentUserId, 
            pageable
        );
        
        List<UserSearchDTO> results = users.stream()
            .map(UserSearchDTO::from)
            .collect(Collectors.toList());
        
        return UserSearchResponse.builder()
            .users(results)
            .totalResults(results.size())
            .query(query)
            .build();
    }
}
```

#### Output Format

**Success Response** (200 OK):

```json
{
  "users": [
    {
      "userId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "userIdString": "jihoon_kim",
      "nickname": "지훈",
      "profileImageUrl": "https://...",
      "bio": "사진 찍는 걸 좋아합니다 📷",
      "createdAt": "2025-10-15T12:30:00Z"
    },
    {
      "userId": "550e8400-e29b-41d4-a716-446655440000",
      "userIdString": "jihoon_park",
      "nickname": "지훈P",
      "profileImageUrl": "https://...",
      "bio": null,
      "createdAt": "2025-09-20T10:00:00Z"
    }
  ],
  "totalResults": 2,
  "query": "jihoon"
}
```

#### 구현 시 주의사항

**1. LIKE vs Full-Text Search**

```java
// LIKE: 간단하지만 느림 (특히 %query% 패턴)
WHERE nickname LIKE '%jihoon%' // Index Scan 불가능

// Full-Text Search: 빠르지만 복잡
WHERE to_tsvector('simple', nickname) @@ to_tsquery('simple', 'jihoon:*')
```

**권장**: 초기에는 LIKE로 시작, 성능 문제 발생 시 Full-Text Search 도입

**2. 대소문자 구분 없는 검색**

```java
// PostgreSQL의 ILIKE 사용
WHERE user_id ILIKE 'jihoon%' // 대소문자 무시

// 또는 LOWER() 함수
WHERE LOWER(user_id) LIKE LOWER('jihoon%')
```

**3. 검색 결과 정렬 우선순위**

```java
ORDER BY 
  CASE 
    WHEN LOWER(user_id) = LOWER(:query) THEN 0      // 정확한 일치 최우선
    WHEN LOWER(user_id) LIKE LOWER(:query || '%') THEN 1  // prefix 일치
    WHEN LOWER(nickname) LIKE LOWER(:query || '%') THEN 2 // 닉네임 prefix
    ELSE 3                                           // 부분 일치
  END,
  created_at DESC  // 같은 우선순위면 최근 가입자 우선
```

---

## 📦 Feature 3: 사용자 상세 조회 (User Detail)

### Flutter 소스 분석

**UserSearchRepository.searchUserById()**:

```dart
Future<UserSearchModel?> searchUserById(String userId) async {
  try {
    final userDoc = await _usersCollection.doc(userId).get();

    if (!userDoc.exists) {
      return null;
    }

    return UserSearchModel.fromFirestore(userDoc);
  } catch (e) {
    throw Exception('사용자 ID 검색 실패: $e');
  }
}
```

### 백엔드 구현 명세

#### Input Format

**Endpoint**: `GET /api/v1/users/{userId}`

**Path Parameters**:
- `userId`: UUID (사용자 ID)

#### Process Flow

```java
@Service
@RequiredArgsConstructor
public class UserSearchService {
    
    private final UserRepository userRepository;
    
    @Transactional(readOnly = true)
    public UserDetailDTO getUserById(UUID userId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new UserNotFoundException("사용자를 찾을 수 없습니다."));
        
        return UserDetailDTO.from(user);
    }
}
```

#### Output Format

**Success Response** (200 OK):

```json
{
  "userId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "userIdString": "jihoon_kim",
  "nickname": "지훈",
  "profileImageUrl": "https://...",
  "bio": "사진 찍는 걸 좋아합니다 📷",
  "createdAt": "2025-10-15T12:30:00Z",
  "friendsCount": 42,
  "categoriesCount": 5
}
```

**Error Responses**:
- **404 Not Found**: 사용자를 찾을 수 없음

---

## 📦 Feature 4: 추천 친구 목록 (Recommended Friends)

### Flutter 소스 분석

**UserMatchingService.getSuggestedFriends()**:

```dart
Future<List<UserSearchModel>> getSuggestedFriends(
  List<Contact> contacts, {
  int limit = 20,
}) async {
  try {
    final matchResults = await matchContactsWithUsers(contacts);

    // 우선순위에 따라 정렬
    matchResults.sort((a, b) {
      // 1. 이름이 있는 연락처 우선
      if (a.contact.displayName.isNotEmpty && b.contact.displayName.isEmpty) {
        return -1;
      }
      if (a.contact.displayName.isEmpty && b.contact.displayName.isNotEmpty) {
        return 1;
      }

      // 2. 사용자 생성일 순 (최근 가입자 우선)
      return b.user.createdAt.compareTo(a.user.createdAt);
    });

    return matchResults.take(limit).map((result) => result.user).toList();
  } catch (e) {
    throw Exception('친구 추천 생성 실패: $e');
  }
}
```

### 백엔드 구현 명세

#### Input Format

**Endpoint**: `GET /api/v1/users/recommended`

**Query Parameters**:
```java
@RequestParam(defaultValue = "20") int limit
```

#### Process Flow

**옵션 1: 연락처 기반 추천**

클라이언트가 `find-by-contacts` API를 먼저 호출하고 결과를 정렬하면 됨.

**옵션 2: 백엔드에서 추천 로직**

```java
@Service
@RequiredArgsConstructor
public class UserRecommendationService {
    
    private final UserRepository userRepository;
    private final FriendshipRepository friendshipRepository;
    
    @Transactional(readOnly = true)
    public List<UserSearchDTO> getRecommendedUsers(UUID currentUserId, int limit) {
        // 1. 친구의 친구 찾기 (공통 친구 기반)
        List<User> friendsOfFriends = userRepository.findFriendsOfFriends(
            currentUserId, 
            PageRequest.of(0, limit)
        );
        
        return friendsOfFriends.stream()
            .map(UserSearchDTO::from)
            .collect(Collectors.toList());
    }
}
```

**공통 친구 기반 추천 쿼리**:

```sql
SELECT u.*, COUNT(f2.user_id) as mutual_friends_count
FROM users u
JOIN friendships f1 ON f1.friend_id = u.id
JOIN friendships f2 ON f2.user_id = f1.user_id
WHERE f2.friend_id IN (
    SELECT friend_id FROM friendships WHERE user_id = :currentUserId
)
AND u.id != :currentUserId
AND NOT EXISTS (
    SELECT 1 FROM friendships 
    WHERE user_id = :currentUserId AND friend_id = u.id
)
GROUP BY u.id
ORDER BY mutual_friends_count DESC, u.created_at DESC
LIMIT :limit;
```

#### Output Format

**Success Response** (200 OK):

```json
{
  "recommendedUsers": [
    {
      "userId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "userIdString": "jihoon_kim",
      "nickname": "지훈",
      "profileImageUrl": "https://...",
      "mutualFriendsCount": 3,
      "createdAt": "2025-10-15T12:30:00Z"
    }
  ],
  "totalRecommended": 1
}
```

---

## 📦 Feature 5: 최근 가입자 조회 (Recent Users)

### Flutter 소스 분석

**UserSearchRepository.getRecentUsers()**:

```dart
Future<List<UserSearchModel>> getRecentUsers({int limit = 10}) async {
  try {
    final querySnapshot = await _usersCollection
        .orderBy('createdAt', descending: true)
        .limit(limit + 1) // 현재 사용자 제외를 위해 +1
        .get();

    final results = querySnapshot.docs.map((doc) {
      return UserSearchModel.fromFirestore(doc);
    }).toList();

    // 현재 사용자 제외
    final currentUid = _currentUserUid;
    if (currentUid != null) {
      results.removeWhere((user) => user.uid == currentUid);
    }

    return results.take(limit).toList();
  } catch (e) {
    throw Exception('인기 사용자 조회 실패: $e');
  }
}
```

### 백엔드 구현 명세

#### Input Format

**Endpoint**: `GET /api/v1/users/recent`

**Query Parameters**:
```java
@RequestParam(defaultValue = "10") int limit
```

#### Process Flow

```java
@Service
@RequiredArgsConstructor
public class UserSearchService {
    
    private final UserRepository userRepository;
    
    @Transactional(readOnly = true)
    public List<UserSearchDTO> getRecentUsers(UUID currentUserId, int limit) {
        Pageable pageable = PageRequest.of(0, limit);
        
        List<User> recentUsers = userRepository.findRecentUsers(
            currentUserId, 
            pageable
        );
        
        return recentUsers.stream()
            .map(UserSearchDTO::from)
            .collect(Collectors.toList());
    }
}
```

**Repository**:

```java
@Repository
public interface UserRepository extends JpaRepository<User, UUID> {
    
    @Query("""
        SELECT u FROM User u
        WHERE u.id != :currentUserId
        ORDER BY u.createdAt DESC
        """)
    List<User> findRecentUsers(
        @Param("currentUserId") UUID currentUserId,
        Pageable pageable
    );
}
```

#### Output Format

**Success Response** (200 OK):

```json
{
  "users": [
    {
      "userId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "userIdString": "jihoon_kim",
      "nickname": "지훈",
      "profileImageUrl": "https://...",
      "createdAt": "2025-10-22T10:00:00Z"
    }
  ],
  "totalResults": 1
}
```

---

## 📦 Feature 6: 전화번호 등록 (Register Phone Number)

### Flutter 소스 분석

**UserSearchRepository.registerPhoneNumber()**:

```dart
Future<void> registerPhoneNumber(String phoneNumber) async {
  final currentUid = _currentUserUid;
  if (currentUid == null) {
    throw Exception('사용자가 로그인되어 있지 않습니다');
  }

  try {
    final hashedPhoneNumber = _hashPhoneNumber(phoneNumber);

    await _usersCollection.doc(currentUid).update({
      'phone': hashedPhoneNumber,
      'allowPhoneSearch': true, // 기본값으로 검색 허용
    });
  } catch (e) {
    throw Exception('전화번호 등록 실패: $e');
  }
}
```

### 백엔드 구현 명세

#### Input Format

**Endpoint**: `PUT /api/v1/users/me/phone`

**Request Body**:
```java
public class RegisterPhoneRequest {
    @NotNull(message = "전화번호는 필수입니다.")
    @Pattern(regexp = "^[0-9+\\-\\s()]+$", message = "올바른 전화번호 형식이 아닙니다.")
    private String phoneNumber;
    
    @NotNull(message = "검색 허용 여부는 필수입니다.")
    private Boolean allowPhoneSearch;
}
```

**Example**:
```json
{
  "phoneNumber": "010-1234-5678",
  "allowPhoneSearch": true
}
```

#### Process Flow

**단계 1: 전화번호 중복 확인**

```java
@Service
@RequiredArgsConstructor
public class UserSearchService {
    
    private final UserRepository userRepository;
    private final PhoneHashService phoneHashService;
    
    @Transactional
    public void registerPhoneNumber(
        RegisterPhoneRequest request,
        UUID currentUserId
    ) {
        // 1. 전화번호 해시 생성
        String phoneHash = phoneHashService.hashPhoneNumber(
            request.getPhoneNumber()
        );
        
        // 2. 중복 확인
        Optional<User> existingUser = userRepository.findByPhoneHash(phoneHash);
        if (existingUser.isPresent() && !existingUser.get().getId().equals(currentUserId)) {
            throw new PhoneNumberAlreadyRegisteredException(
                "이미 등록된 전화번호입니다."
            );
        }
        
        // 3. 사용자 정보 업데이트
        User user = userRepository.findById(currentUserId)
            .orElseThrow(() -> new UserNotFoundException("사용자를 찾을 수 없습니다."));
        
        user.setPhoneHash(phoneHash);
        user.setAllowPhoneSearch(request.getAllowPhoneSearch());
        
        userRepository.save(user);
        
        log.info("사용자 {} 전화번호 등록 완료", currentUserId);
    }
}
```

**단계 2: User 엔티티 업데이트**

```java
@Entity
@Table(name = "users")
public class User {
    
    @Column(name = "phone_hash", length = 64, unique = true)
    private String phoneHash;
    
    @Column(name = "allow_phone_search", nullable = false)
    private Boolean allowPhoneSearch = false;
    
    public void setPhoneHash(String phoneHash) {
        this.phoneHash = phoneHash;
    }
    
    public void setAllowPhoneSearch(Boolean allowPhoneSearch) {
        this.allowPhoneSearch = allowPhoneSearch;
    }
}
```

#### Output Format

**Success Response** (200 OK):

```json
{
  "message": "전화번호가 등록되었습니다.",
  "allowPhoneSearch": true
}
```

**Error Responses**:

- **409 Conflict**: 이미 등록된 전화번호
  ```json
  {
    "error": "PHONE_ALREADY_REGISTERED",
    "message": "이미 등록된 전화번호입니다."
  }
  ```

#### 구현 시 주의사항

**1. 전화번호 해시 UNIQUE 제약**

```sql
ALTER TABLE users 
ADD CONSTRAINT uk_users_phone_hash 
UNIQUE (phone_hash);
```

**2. Salt 추가 고려 (고급)**

```java
public String hashPhoneNumberWithSalt(String phoneNumber) {
    String cleanNumber = cleanPhoneNumber(phoneNumber);
    String saltedNumber = cleanNumber + SALT; // 환경변수에서 로드
    
    MessageDigest digest = MessageDigest.getInstance("SHA-256");
    byte[] hash = digest.digest(saltedNumber.getBytes(StandardCharsets.UTF_8));
    return bytesToHex(hash);
}
```

---

## 📦 Feature 7: 전화번호 삭제 (Remove Phone Number)

### Flutter 소스 분석

**UserSearchRepository.removePhoneNumber()**:

```dart
Future<void> removePhoneNumber() async {
  final currentUid = _currentUserUid;
  if (currentUid == null) {
    throw Exception('사용자가 로그인되어 있지 않습니다');
  }

  try {
    await _usersCollection.doc(currentUid).update({
      'phone': FieldValue.delete(),
      'allowPhoneSearch': false,
    });
  } catch (e) {
    throw Exception('전화번호 삭제 실패: $e');
  }
}
```

### 백엔드 구현 명세

#### Input Format

**Endpoint**: `DELETE /api/v1/users/me/phone`

**No Request Body**

#### Process Flow

```java
@Service
@RequiredArgsConstructor
public class UserSearchService {
    
    private final UserRepository userRepository;
    
    @Transactional
    public void removePhoneNumber(UUID currentUserId) {
        User user = userRepository.findById(currentUserId)
            .orElseThrow(() -> new UserNotFoundException("사용자를 찾을 수 없습니다."));
        
        user.setPhoneHash(null);
        user.setAllowPhoneSearch(false);
        
        userRepository.save(user);
        
        log.info("사용자 {} 전화번호 삭제 완료", currentUserId);
    }
}
```

#### Output Format

**Success Response** (204 No Content)

---

## 📦 Feature 8: 검색 설정 업데이트 (Update Search Settings)

### Flutter 소스 분석

**UserSearchRepository.updateSearchSettings()**:

```dart
Future<void> updateSearchSettings({required bool allowPhoneSearch}) async {
  final currentUid = _currentUserUid;
  if (currentUid == null) {
    throw Exception('사용자가 로그인되어 있지 않습니다');
  }

  try {
    await _usersCollection.doc(currentUid).update({
      'allowPhoneSearch': allowPhoneSearch,
    });
  } catch (e) {
    throw Exception('검색 설정 업데이트 실패: $e');
  }
}
```

### 백엔드 구현 명세

#### Input Format

**Endpoint**: `PUT /api/v1/users/me/settings/search`

**Request Body**:
```java
public class UpdateSearchSettingsRequest {
    @NotNull(message = "검색 허용 여부는 필수입니다.")
    private Boolean allowPhoneSearch;
}
```

**Example**:
```json
{
  "allowPhoneSearch": false
}
```

#### Process Flow

```java
@Service
@RequiredArgsConstructor
public class UserSearchService {
    
    private final UserRepository userRepository;
    
    @Transactional
    public void updateSearchSettings(
        UpdateSearchSettingsRequest request,
        UUID currentUserId
    ) {
        User user = userRepository.findById(currentUserId)
            .orElseThrow(() -> new UserNotFoundException("사용자를 찾을 수 없습니다."));
        
        user.setAllowPhoneSearch(request.getAllowPhoneSearch());
        
        userRepository.save(user);
        
        log.info("사용자 {} 검색 설정 업데이트: allowPhoneSearch={}", 
            currentUserId, request.getAllowPhoneSearch());
    }
}
```

#### Output Format

**Success Response** (200 OK):

```json
{
  "message": "검색 설정이 업데이트되었습니다.",
  "allowPhoneSearch": false
}
```

---

## 📊 기능 구현 체크리스트

### Database

- [ ] **Migration Scripts**
  - [ ] `V1__add_user_search_columns.sql`: phone_hash, allow_phone_search, user_id 추가
  - [ ] `V2__create_search_indexes.sql`: 검색 최적화 인덱스 생성

### Backend (Spring Boot)

- [ ] **Entity Layer**
  - [ ] User 엔티티 확장 (phoneHash, allowPhoneSearch, userId)
  - [ ] Friendship 엔티티 (이미 존재 가정)
  - [ ] FriendRequest 엔티티 (이미 존재 가정)

- [ ] **Repository Layer**
  - [ ] UserRepository: 검색 및 매칭 쿼리
  - [ ] FriendshipRepository (기존)
  - [ ] FriendRequestRepository (기존)

- [ ] **Service Layer**
  - [ ] PhoneHashService: SHA-256 해시화
  - [ ] UserSearchService: 8개 기능 구현
  - [ ] UserRecommendationService: 추천 로직

- [ ] **Controller Layer**
  - [ ] UserSearchController: 8개 REST API
  - [ ] RateLimitInterceptor: Redis 기반 제한

- [ ] **DTO Layer**
  - [ ] FindUsersByContactsRequest
  - [ ] FindUsersByContactsResponse
  - [ ] MatchedUserDTO
  - [ ] UserSearchDTO
  - [ ] RegisterPhoneRequest
  - [ ] UpdateSearchSettingsRequest

### Frontend (Flutter)

- [ ] **Repository 변경**
  - [ ] UserSearchRepository: Firestore → REST API 마이그레이션
  - [ ] dio 클라이언트 설정

- [ ] **Service 변경**
  - [ ] UserMatchingService: 백엔드 API 호출로 변경
  - [ ] 로컬 연락처 매핑 로직 유지

- [ ] **Controller 변경**
  - [ ] UserMatchingController: 상태 관리 유지
  - [ ] 에러 핸들링 개선

---

## 🚀 마이그레이션 우선순위

### Phase 1: 기본 검색 (1주)

1. **Feature 3**: 사용자 상세 조회
2. **Feature 2**: 사용자 검색 (ID, 닉네임)
3. **Feature 5**: 최근 가입자 조회

### Phase 2: 전화번호 관리 (1주)

4. **Feature 6**: 전화번호 등록
5. **Feature 7**: 전화번호 삭제
6. **Feature 8**: 검색 설정 업데이트

### Phase 3: 연락처 매칭 (2주)

7. **Feature 1**: 연락처 기반 사용자 매칭 (가장 복잡)
8. **Feature 4**: 추천 친구 목록

### Phase 4: 최적화 (1주)

- PostgreSQL 인덱스 튜닝
- Redis 캐싱
- Rate Limiting
- Full-Text Search 도입 (선택)

---

## 📝 구현 시 핵심 고려사항

### 1. 전화번호 해시화 전략

```java
// ✅ 권장: SHA-256 with Salt
public class PhoneHashService {
    
    @Value("${app.phone.hash.salt}")
    private String salt;
    
    public String hash(String phoneNumber) {
        String clean = cleanPhoneNumber(phoneNumber);
        String salted = clean + salt;
        
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] hash = digest.digest(salted.getBytes(StandardCharsets.UTF_8));
        return bytesToHex(hash);
    }
}
```

### 2. 성능 최적화

**인덱스 전략**:
```sql
-- 단일 컬럼 인덱스
CREATE INDEX idx_users_phone_hash ON users(phone_hash) WHERE phone_hash IS NOT NULL;
CREATE INDEX idx_users_user_id ON users(user_id);
CREATE INDEX idx_users_nickname ON users(nickname);
CREATE INDEX idx_users_created_at ON users(created_at DESC);

-- 복합 인덱스 (검색 허용된 사용자만)
CREATE INDEX idx_users_searchable 
ON users(phone_hash, allow_phone_search) 
WHERE allow_phone_search = true;

-- Full-Text Search 인덱스 (고급)
CREATE INDEX idx_users_fulltext 
ON users 
USING GIN (to_tsvector('simple', user_id || ' ' || nickname));
```

**쿼리 튜닝**:
```sql
-- EXPLAIN ANALYZE로 쿼리 플랜 확인
EXPLAIN ANALYZE
SELECT * FROM users 
WHERE phone_hash IN ('hash1', 'hash2', ...)
  AND allow_phone_search = true;

-- Index Scan을 사용하는지 확인
-- Seq Scan이 나오면 인덱스 추가 필요
```

### 3. 보안 체크리스트

- [x] 전화번호 서버 측 해시화 (클라이언트 해시 신뢰 안 함)
- [x] allow_phone_search = true인 사용자만 매칭
- [x] 현재 사용자 제외
- [x] Rate Limiting (분당 10회)
- [ ] HTTPS 필수
- [ ] Firebase ID Token 검증
- [ ] SQL Injection 방지 (JPA 사용)
- [ ] Salt 환경변수로 관리

### 4. Flutter 클라이언트 통합

**변경 전 (Firestore)**:
```dart
final hashedNumbers = phoneNumbers.map(_hashPhoneNumber).toList();

for (int i = 0; i < hashedNumbers.length; i += 10) {
  final batch = hashedNumbers.skip(i).take(10).toList();
  final querySnapshot = await _usersCollection
      .where('phone', whereIn: batch)
      .get();
  // ...
}
```

**변경 후 (REST API)**:
```dart
final response = await dio.post(
  '/api/v1/users/find-by-contacts',
  data: {
    'phoneNumbers': phoneNumbers, // 평문 전송 (HTTPS로 보호)
  },
  options: Options(
    headers: {
      'Authorization': 'Bearer ${await _auth.currentUser?.getIdToken()}',
    },
  ),
);

final matchedUsers = (response.data['matchedUsers'] as List)
    .map((json) => MatchedUserDTO.fromJson(json))
    .toList();
```

---

## 🔐 프라이버시 정책 문구

**사용자에게 표시할 내용**:

```
📱 연락처 기반 친구 찾기

SOI는 귀하의 프라이버시를 최우선으로 합니다:

✅ 연락처는 귀하의 디바이스에만 저장됩니다.
✅ 친구 찾기 시 전화번호만 암호화하여 일시적으로 사용합니다.
✅ 서버는 암호화된 전화번호만 저장하며, 실제 전화번호는 복구할 수 없습니다.
✅ 매칭 후 즉시 삭제되며, 영구 저장하지 않습니다.
✅ 검색 허용 설정을 언제든지 변경할 수 있습니다.

자세한 내용은 개인정보 처리방침을 참조해주세요.
```

---

**작성일**: 2025년 10월 22일  
**작성자**: SOI Development Team  
**버전**: 1.0.0
