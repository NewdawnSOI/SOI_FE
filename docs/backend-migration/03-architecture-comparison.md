# Firebase vs Spring Boot 아키텍처 비교

SOI 프로젝트의 Category 도메인을 예시로 Firebase와 Spring Boot 아키텍처를 상세히 비교합니다.

## 🏗️ 1. 전체 아키텍처 비교

### Firebase 아키텍처

```
┌─────────────────────────────────────────────────────┐
│                 Flutter App                          │
│                                                      │
│  ┌────────────┐   ┌────────────┐   ┌────────────┐ │
│  │ Controller │──▶│  Service   │──▶│ Repository │ │
│  │  (State)   │   │ (Logic)    │   │ (Firebase) │ │
│  └────────────┘   └────────────┘   └──────┬─────┘ │
│                                            │        │
└────────────────────────────────────────────┼────────┘
                                             │
                                             ▼
                                    ┌────────────────┐
                                    │   Firebase     │
                                    ├────────────────┤
                                    │  • Firestore   │
                                    │  • Storage     │
                                    │  • Auth        │
                                    │  • Functions   │
                                    └────────────────┘
```

**특징:**

- ❌ 비즈니스 로직이 Flutter에 분산
- ❌ 복잡한 쿼리가 클라이언트에서 실행
- ❌ 실시간 Stream 기반 (메모리 부담)
- ❌ 네트워크 호출 최적화 어려움

### Spring Boot 아키텍처

```
┌──────────────────────────────────┐         ┌────────────────────────────────┐
│       Flutter App                │         │      Spring Boot Backend       │
│                                  │         │                                │
│  ┌──────────┐   ┌────────────┐ │         │  ┌──────────┐   ┌──────────┐  │
│  │Controller│──▶│ Repository │─┼────▶────┼─▶│Controller│──▶│ Service  │  │
│  │ (State)  │   │ (API Call) │ │  REST   │  │ (API)    │   │ (Logic)  │  │
│  └──────────┘   └────────────┘ │  API    │  └──────────┘   └────┬─────┘  │
│                                  │         │                      │         │
└──────────────────────────────────┘         │                      ▼         │
                                              │              ┌────────────┐   │
                                              │              │ Repository │   │
                                              │              │ (JPA)      │   │
                                              │              └──────┬─────┘   │
                                              │                     │         │
                                              └─────────────────────┼─────────┘
                                                                    │
                                                                    ▼
                                                          ┌──────────────────┐
                                                          │   PostgreSQL     │
                                                          └──────────────────┘
```

**특징:**

- ✅ 비즈니스 로직이 백엔드에 집중
- ✅ SQL 기반 효율적인 쿼리
- ✅ Future 기반 + 캐싱 (메모리 효율)
- ✅ 네트워크 호출 최소화

---

## 📊 2. Category 도메인 상세 비교

### 2.1. 데이터 저장 구조

#### Firebase (Firestore)

```javascript
// NoSQL Document 구조
categories/ (collection)
  └─ categoryId/ (document)
      ├─ name: "가족"
      ├─ mates: ["user1", "user2", "user3"]  // Array
      ├─ categoryPhotoUrl: "https://..."
      ├─ createdBy: "user1"
      ├─ createdAt: Timestamp
      └─ photos/ (subcollection)
          └─ photoId/
              ├─ imageUrl: "https://..."
              ├─ audioUrl: "https://..."
              ├─ uploaderId: "user1"
              └─ uploadedAt: Timestamp
```

**문제점:**

- ❌ Array 쿼리 제한 (arrayContains 하나만 가능)
- ❌ JOIN 불가 (멤버 정보 별도 조회 필요)
- ❌ 트랜잭션 제한 (단일 문서만 원자적)
- ❌ 중복 데이터 (mates 배열에 userId만)

#### Spring Boot (PostgreSQL)

```sql
-- SQL Table 구조
CREATE TABLE categories (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category_photo_url TEXT,
    owner_id VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    FOREIGN KEY (owner_id) REFERENCES users(id)
);

CREATE TABLE category_members (
    id VARCHAR(255) PRIMARY KEY,
    category_id VARCHAR(255) NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    joined_at TIMESTAMP NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE(category_id, user_id)  -- 중복 방지
);

CREATE TABLE photos (
    id VARCHAR(255) PRIMARY KEY,
    category_id VARCHAR(255) NOT NULL,
    uploader_id VARCHAR(255) NOT NULL,
    image_url TEXT NOT NULL,
    audio_url TEXT,
    uploaded_at TIMESTAMP NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE,
    FOREIGN KEY (uploader_id) REFERENCES users(id)
);

CREATE INDEX idx_category_members_user ON category_members(user_id);
CREATE INDEX idx_photos_category ON photos(category_id);
```

**장점:**

- ✅ JOIN으로 멤버 정보 한 번에 조회
- ✅ Foreign Key로 데이터 무결성 보장
- ✅ ACID 트랜잭션
- ✅ 복잡한 쿼리 최적화 가능

---

### 2.2. 카테고리 목록 조회

#### Firebase (Flutter)

```dart
// lib/repositories/category_repository.dart
class CategoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FriendRepository _friendRepository;

  Stream<List<Category>> streamUserCategories(String userId) {
    return _firestore
        .collection('categories')
        .where('mates', arrayContains: userId)  // ❌ 제한적인 쿼리
        .snapshots()
        .asyncMap((snapshot) async {

      // ❌ 차단된 사용자 필터링을 클라이언트에서
      final blockedUsers = await _friendRepository.getBlockedUsers(userId);
      final blockedIds = blockedUsers.map((u) => u.id).toSet();

      final categories = snapshot.docs.map((doc) {
        return Category.fromFirestore(doc.data(), doc.id);
      }).toList();

      // ❌ 복잡한 필터링 로직
      return categories.where((category) {
        // 차단된 사용자가 포함된 카테고리 제외
        final hasBlockedUser = category.mates.any(
          (mateId) => blockedIds.contains(mateId)
        );
        return !hasBlockedUser;
      }).toList();
    });
  }
}
```

**문제:**

1. Firebase 2번 호출 (categories + blockedUsers)
2. 차단 필터링이 클라이언트에서 실행
3. 실시간 Stream으로 메모리 부담
4. 멤버 정보가 없음 (userId만)

#### Spring Boot (Backend)

```java
// src/main/java/com/soi/repository/CategoryRepository.java
public interface CategoryRepository extends JpaRepository<Category, String> {

    // ✅ 한 번의 쿼리로 모든 처리
    @Query("""
        SELECT DISTINCT c FROM Category c
        LEFT JOIN FETCH c.members m
        LEFT JOIN FETCH m.user u
        WHERE m.userId = :userId
        AND NOT EXISTS (
            SELECT 1 FROM Block b
            WHERE b.blockerId = :userId
            AND b.blockedId = m.userId
        )
        ORDER BY c.createdAt DESC
        """)
    List<Category> findUserCategoriesWithoutBlocked(@Param("userId") String userId);
}

// Service
@Service
@Transactional(readOnly = true)
public class CategoryService {

    public List<CategoryDTO> getUserCategories(String userId) {
        // ✅ 1번의 쿼리로 멤버 정보 + 차단 필터링
        List<Category> categories = categoryRepository.findUserCategoriesWithoutBlocked(userId);

        return categories.stream()
            .map(CategoryDTO::from)
            .collect(Collectors.toList());
    }
}
```

**장점:**

1. ✅ 단 1번의 SQL 쿼리
2. ✅ JOIN으로 멤버 정보 포함
3. ✅ 차단 필터링이 DB에서 처리
4. ✅ 인덱스 최적화 가능

#### Flutter (Frontend)

```dart
// lib/repositories/category_repository.dart
class CategoryRepository {
  final CategoryApi _api;  // 자동 생성

  Future<List<CategoryDTO>> getUserCategories() async {
    // ✅ 단순 API 호출
    final response = await _api.getCategories();
    return response.data?.data ?? [];
  }
}
```

**변화:**

- **이전:** 복잡한 로직 50줄 → **이후:** API 호출 3줄
- **네트워크:** Firebase 2회 → REST API 1회

---

### 2.3. 멤버 추가 (복잡한 비즈니스 로직)

#### Firebase (Flutter)

```dart
// lib/services/category_member_service.dart
class CategoryMemberService {
  final CategoryRepository _categoryRepository;
  final FriendRepository _friendRepository;
  final InviteRepository _inviteRepository;
  final UserRepository _userRepository;

  Future<Map<String, dynamic>> addMember({
    required String categoryId,
    required String currentUserId,
    required String targetUserId,
  }) async {
    // ❌ 복잡한 검증 로직이 Flutter에

    // 1. 친구 확인 (Firestore 조회)
    final friends = await _friendRepository.getFriends(currentUserId);
    if (!friends.any((f) => f.id == targetUserId)) {
      throw Exception('친구가 아닙니다');
    }

    // 2. 차단 확인 (Firestore 조회)
    final blocked = await _friendRepository.getBlockedUsers(currentUserId);
    if (blocked.any((u) => u.id == targetUserId)) {
      throw Exception('차단된 사용자입니다');
    }

    // 3. 카테고리 조회 (Firestore 조회)
    final category = await _categoryRepository.getCategory(categoryId);

    // 4. 권한 확인
    if (category.createdBy != currentUserId) {
      throw Exception('권한이 없습니다');
    }

    // 5. 중복 확인
    if (category.mates.contains(targetUserId)) {
      throw Exception('이미 멤버입니다');
    }

    // 6. 인원 제한
    if (category.mates.length >= 10) {
      throw Exception('카테고리 인원이 가득 찼습니다');
    }

    // 7. 양방향 친구 확인 (Firestore 조회)
    final targetFriends = await _friendRepository.getFriends(targetUserId);
    final isMutualFriend = targetFriends.any((f) => f.id == currentUserId);

    if (isMutualFriend) {
      // 바로 추가 (Firestore 업데이트)
      await _categoryRepository.addMember(categoryId, targetUserId);
      return {'requiresAcceptance': false};
    } else {
      // 초대 생성 (Firestore 추가)
      final inviteId = await _inviteRepository.createInvite(
        categoryId: categoryId,
        inviterId: currentUserId,
        inviteeId: targetUserId,
      );

      // 알림 전송 (FCM - Cloud Functions 트리거)
      // (자동으로 처리됨)

      return {
        'requiresAcceptance': true,
        'inviteId': inviteId,
      };
    }
  }
}
```

**문제:**

- ❌ Firestore 6번 호출
- ❌ 복잡한 로직 150줄
- ❌ 트랜잭션 없음 (중간 실패 시 불일치)
- ❌ 네트워크 지연 누적

#### Spring Boot (Backend)

```java
// src/main/java/com/soi/service/CategoryService.java
@Service
@RequiredArgsConstructor
public class CategoryService {

    private final CategoryRepository categoryRepository;
    private final FriendRepository friendRepository;
    private final InviteRepository inviteRepository;
    private final NotificationService notificationService;

    @Transactional  // ✅ ACID 트랜잭션
    public AddMemberResponse addMember(
        String categoryId,
        String currentUserId,
        AddMemberRequest request
    ) {
        String targetUserId = request.getTargetUserId();

        // ✅ 모든 검증을 한 곳에서

        // 1. 카테고리 조회 + 권한 확인 (1 query)
        Category category = categoryRepository.findById(categoryId)
            .orElseThrow(() -> new NotFoundException("Category not found"));

        if (!category.isOwner(currentUserId)) {
            throw new ForbiddenException("Only owner can add members");
        }

        // 2-3. 친구 + 차단 확인 (1 query - JOIN)
        if (!friendRepository.areFriendsAndNotBlocked(currentUserId, targetUserId)) {
            throw new FriendNotFoundException("User is not your friend or is blocked");
        }

        // 4. 중복 확인 (메모리 - 이미 로드됨)
        if (category.hasMember(targetUserId)) {
            throw new AlreadyMemberException("User is already a member");
        }

        // 5. 인원 제한 (메모리)
        if (category.getMemberCount() >= MAX_MEMBERS) {
            throw new CategoryFullException("Category is full");
        }

        // 6. 양방향 친구 확인 (이미 위에서 확인됨)
        boolean isMutualFriend = friendRepository.areFriends(targetUserId, currentUserId);

        if (isMutualFriend) {
            // 바로 추가
            category.addMember(targetUserId);
            categoryRepository.save(category);

            // 비동기 알림
            notificationService.notifyMemberAdded(category, targetUserId);

            return AddMemberResponse.builder()
                .requiresAcceptance(false)
                .message("Member added successfully")
                .build();
        } else {
            // 초대 생성
            Invite invite = Invite.create(categoryId, currentUserId, targetUserId);
            inviteRepository.save(invite);

            // 비동기 알림
            notificationService.notifyInviteSent(invite);

            return AddMemberResponse.builder()
                .requiresAcceptance(true)
                .inviteId(invite.getId())
                .message("Invitation sent")
                .build();
        }

        // ✅ 트랜잭션: 중간에 실패하면 모두 롤백
    }
}
```

**장점:**

- ✅ SQL 쿼리 2번 (JOIN 활용)
- ✅ 트랜잭션으로 데이터 무결성 보장
- ✅ 비즈니스 로직이 한 곳에 집중
- ✅ 쉬운 유지보수

#### Flutter (Frontend)

```dart
// lib/repositories/category_repository.dart
class CategoryRepository {
  final CategoryApi _api;

  Future<AddMemberResponse> addMember({
    required String categoryId,
    required String targetUserId,
  }) async {
    // ✅ 단순 API 호출
    final request = AddMemberRequest((b) => b
      ..targetUserId = targetUserId
    );

    final response = await _api.addMember(
      id: categoryId,
      addMemberRequest: request,
    );

    return response.data!.data!;
  }
}
```

**변화:**

- **이전:** 복잡한 로직 150줄 → **이후:** API 호출 10줄
- **네트워크:** Firestore 6회 → REST API 1회
- **코드 복잡도:** 높음 → 낮음

---

## 📈 3. 성능 비교

### 카테고리 목록 조회 시나리오

#### Firebase

```
사용자 요청
  ↓
Flutter: 카테고리 조회 (Firestore)  ─────────────────▶ 500ms
  ↓ (20개 카테고리)
Flutter: 차단 목록 조회 (Firestore)  ─────────────────▶ 300ms
  ↓
Flutter: 클라이언트 필터링  ──────────────────────────▶ 50ms
  ↓
Flutter: 각 멤버 정보 조회 (20 * 3명 = 60 requests) ▶ 3000ms
  ↓
총 시간: ~3850ms
```

#### Spring Boot

```
사용자 요청
  ↓
Flutter: API 호출  ───────────────────────────────────▶ 200ms
  ↓
Backend: SQL 쿼리 (JOIN + WHERE)  ────────────────────▶ 50ms
  ↓
총 시간: ~250ms
```

**성능 개선: 15배 빠름 (3850ms → 250ms)**

---

### 멤버 추가 시나리오

#### Firebase

```
사용자 요청
  ↓
Flutter: 친구 목록 조회  ──────────────────────────────▶ 300ms
Flutter: 차단 목록 조회  ──────────────────────────────▶ 300ms
Flutter: 카테고리 조회  ──────────────────────────────▶ 200ms
Flutter: 대상 사용자 친구 목록 조회  ──────────────────▶ 300ms
Flutter: 멤버 추가 또는 초대 생성  ─────────────────────▶ 200ms
  ↓
총 시간: ~1300ms (+ 트랜잭션 없음)
```

#### Spring Boot

```
사용자 요청
  ↓
Flutter: API 호출  ───────────────────────────────────▶ 200ms
  ↓
Backend: SQL 쿼리 2개 + 비즈니스 로직  ────────────────▶ 80ms
  ↓
총 시간: ~280ms (+ 트랜잭션 보장)
```

**성능 개선: 4.6배 빠름 (1300ms → 280ms)**

---

## 💰 4. 비용 비교 (예상)

### Firebase (월 10만 MAU 기준)

```
Firestore Reads:
- 카테고리 목록: 사용자당 20개 * 10회/일 = 200 reads
- 차단 목록: 사용자당 5개 * 10회/일 = 50 reads
- 멤버 정보: 사용자당 60개 * 10회/일 = 600 reads
─────────────────────────────────────────────────────
총 reads/일: 850 * 100,000 = 85,000,000 reads
총 reads/월: 85M * 30 = 2,550,000,000 reads

비용: $0.06 per 100K reads
     = 2,550M / 100K * $0.06
     = $1,530/월 (읽기만)

Firestore Writes: ~$500/월
Storage: ~$200/월
Functions: ~$300/월
─────────────────────────────────────────────────────
총 Firebase 비용: ~$2,530/월
```

### Spring Boot (AWS 기준)

```
EC2 (t3.medium) * 2:   $60/월
RDS (db.t3.medium):    $80/월
Load Balancer:         $20/월
S3 (이미지):           $50/월
CloudFront:            $30/월
─────────────────────────────────────────────────────
총 AWS 비용: ~$240/월
```

**비용 절감: 약 90% ($2,530 → $240)**

---

## 🔒 5. 보안 비교

### Firebase Security Rules

```javascript
// firestore.rules
match /categories/{categoryId} {
  // ❌ 복잡한 룰 작성 어려움
  allow read: if request.auth != null &&
              request.auth.uid in resource.data.mates &&
              // 차단 확인은 불가능 (다른 컬렉션 조회 불가)
              true;

  allow write: if request.auth != null &&
               request.auth.uid == resource.data.createdBy;
}

// ❌ 문제:
// - 차단된 사용자 필터링 불가
// - 복잡한 비즈니스 로직 불가
// - 친구 관계 확인 어려움
```

### Spring Boot Security

```java
// SecurityConfig.java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/auth/**").permitAll()
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}

// Service에서 상세 권한 검증
@Service
public class CategoryService {

    public CategoryDTO getCategory(String categoryId, String userId) {
        Category category = categoryRepository.findById(categoryId)
            .orElseThrow(() -> new NotFoundException("Category not found"));

        // ✅ 복잡한 권한 검증 가능
        if (!category.hasMember(userId)) {
            throw new ForbiddenException("Not a member");
        }

        // ✅ 차단 확인
        if (blockRepository.isBlocked(userId, category.getOwnerId())) {
            throw new ForbiddenException("Blocked");
        }

        return CategoryDTO.from(category);
    }
}
```

**장점:**

- ✅ 복잡한 권한 로직 구현 가능
- ✅ 차단, 친구 관계 등 다양한 검증
- ✅ JWT 기반 인증
- ✅ Role 기반 권한 관리

---

## 📝 6. 유지보수성 비교

### 새 기능 추가: "카테고리 멤버에 역할 부여"

#### Firebase

```dart
// ❌ 여러 파일 수정 필요

// 1. models/category.dart - 모델 변경
class Category {
  final Map<String, String> memberRoles;  // 추가
}

// 2. repositories/category_repository.dart - 쿼리 변경
Stream<List<Category>> streamCategories() {
  // Firestore 쿼리 수정
}

// 3. services/category_service.dart - 로직 추가
Future<void> changeMemberRole(...) {
  // 권한 확인, 역할 변경 로직
}

// 4. services/category_member_service.dart - 로직 수정
Future<void> addMember(...) {
  // 기본 역할 부여 로직 추가
}

// 5. controllers/category_controller.dart - 상태 관리 수정
// 6. views/category_detail_screen.dart - UI 변경

총 6개 파일 수정, 테스트 어려움
```

#### Spring Boot

```java
// ✅ 백엔드만 수정

// 1. Entity 변경
@Entity
public class CategoryMember {
    @Enumerated(EnumType.STRING)
    private MemberRole role;  // 추가
}

// 2. DTO 변경
public class CategoryMemberDTO {
    private MemberRole role;  // 추가
}

// 3. Service 로직 추가
@Service
public class CategoryService {
    @Transactional
    public void changeMemberRole(String categoryId, String memberId, MemberRole newRole) {
        // 권한 확인, 역할 변경
    }
}

// 4. Controller 엔드포인트 추가
@PutMapping("/{id}/members/{memberId}/role")
public ResponseEntity<?> changeMemberRole(...) {
    // ...
}

// 5. OpenAPI 배포
// 6. Flutter에서 make update-api 실행

총 4개 파일 수정 (백엔드만),
Flutter는 자동 생성된 클라이언트 사용
```

---

## ✅ 7. 결론

| 항목            | Firebase         | Spring Boot    | 승자            |
| --------------- | ---------------- | -------------- | --------------- |
| **개발 속도**   | 빠름 (초기)      | 보통           | Firebase        |
| **코드 복잡도** | 높음 (Flutter)   | 낮음 (Flutter) | Spring Boot     |
| **성능**        | 느림 (다중 호출) | 빠름 (최적화)  | **Spring Boot** |
| **비용**        | 높음 ($2,530/월) | 낮음 ($240/월) | **Spring Boot** |
| **확장성**      | 제한적           | 높음           | **Spring Boot** |
| **보안**        | 제한적           | 유연함         | **Spring Boot** |
| **유지보수**    | 어려움           | 쉬움           | **Spring Boot** |
| **트랜잭션**    | 제한적           | ACID           | **Spring Boot** |

**종합 평가:**

- **초기 프로토타입:** Firebase 유리
- **실제 서비스:** Spring Boot 압도적 우위

---

## 📝 다음 단계

아키텍처 비교를 이해했다면:

👉 **[README로 돌아가기](./README.md)** - 전체 마이그레이션 가이드 확인
