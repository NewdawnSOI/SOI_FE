# 백엔드/프론트엔드 역할 분리

Firebase 구조에서 Spring Boot 백엔드로 전환할 때 각 레이어의 책임과 역할을 명확히 정의합니다.

## 🎯 핵심 원칙

### Firebase 시절 (이전)

```
Flutter App
├─ Controllers (상태 관리 + 비즈니스 로직)
├─ Services (복잡한 비즈니스 로직)
└─ Repositories (Firebase 직접 호출)
```

**문제:** 비즈니스 로직이 프론트엔드에 분산되어 있음

### Spring Boot 시절 (이후)

```
Spring Boot Backend
└─ 모든 비즈니스 로직

Flutter App
├─ Controllers (상태 관리만)
├─ Services (API 호출 래퍼)
└─ Repositories (API 클라이언트 호출)
```

**해결:** 비즈니스 로직은 백엔드에서만, 프론트엔드는 UI/UX에만 집중

---

## 📋 1. 역할 분리 표

### 백엔드 책임 (Spring Boot)

| 영역                | 세부 항목      | 예시                                     |
| ------------------- | -------------- | ---------------------------------------- |
| **비즈니스 로직**   | 데이터 검증    | 친구 확인, 차단 여부, 카테고리 인원 제한 |
|                     | 상태 계산      | 멤버 초대 수락 필요 여부                 |
|                     | 복잡한 필터링  | 차단된 사용자 카테고리 제외              |
|                     | 권한 체크      | 카테고리 소유자만 멤버 추가 가능         |
| **데이터 관리**     | CRUD 작업      | Create, Read, Update, Delete             |
|                     | 트랜잭션 처리  | 멤버 추가 + 알림 전송 (원자성)           |
|                     | 데이터 일관성  | Foreign Key, Unique 제약                 |
| **알림/백그라운드** | FCM 푸시 알림  | 사진 업로드 알림, 좋아요 알림            |
|                     | 스케줄링       | 매일 0시 통계 생성                       |
|                     | 이메일/SMS     | 초대 링크 발송                           |
| **보안**            | 인증           | JWT 토큰 생성/검증                       |
|                     | 권한 부여      | Role 기반 접근 제어                      |
|                     | 민감 정보 보호 | 다른 사용자 전화번호 노출 방지           |
| **통합**            | 외부 API       | Firebase Storage, Google Maps            |
|                     | 결제           | Stripe, Toss Payments                    |
|                     | 분석           | Mixpanel, Amplitude                      |

### 프론트엔드 책임 (Flutter)

| 영역                | 세부 항목         | 예시                       |
| ------------------- | ----------------- | -------------------------- |
| **UI/UX**           | 화면 렌더링       | 카테고리 목록, 사진 그리드 |
|                     | 애니메이션        | 페이지 전환, 로딩 스피너   |
|                     | 사용자 입력       | TextField, Button 이벤트   |
| **상태 관리**       | 로컬 상태         | 로딩 중, 에러 메시지       |
|                     | 캐시 관리         | 이미지 캐시, API 응답 캐시 |
|                     | Provider 상태     | ChangeNotifier 업데이트    |
| **클라이언트 검증** | 입력 형식         | 이메일 형식, 전화번호 길이 |
|                     | 필수 입력         | 빈 값 체크                 |
|                     | UI 피드백         | 실시간 에러 메시지         |
| **로컬 저장소**     | SharedPreferences | 토큰, 사용자 설정          |
|                     | SQLite            | 오프라인 데이터            |
| **네이티브 연동**   | 카메라            | 사진 촬영                  |
|                     | 녹음              | 음성 메모                  |
|                     | 권한 요청         | 카메라, 마이크, 연락처     |

---

## 🔄 2. 비즈니스 로직 이관 예시

### 예시 1: 친구 확인 로직

#### ❌ 이전 (Firebase - Flutter)

```dart
// lib/services/category_member_service.dart
class CategoryMemberService {
  final FriendRepository _friendRepository;

  /// 멤버 추가 전 친구인지 확인
  Future<void> addMember({
    required String categoryId,
    required String currentUserId,
    required String targetUserId,
  }) async {
    // ❌ 비즈니스 로직이 프론트엔드에 있음!

    // 1. 친구 목록 가져오기
    final friends = await _friendRepository.getFriends(currentUserId);

    // 2. 친구인지 확인
    final isFriend = friends.any((f) => f.id == targetUserId);
    if (!isFriend) {
      throw Exception('친구가 아닙니다');
    }

    // 3. 차단 여부 확인
    final blockedUsers = await _friendRepository.getBlockedUsers(currentUserId);
    final isBlocked = blockedUsers.any((u) => u.id == targetUserId);
    if (isBlocked) {
      throw Exception('차단된 사용자입니다');
    }

    // 4. 이미 멤버인지 확인
    final category = await _categoryRepository.getCategory(categoryId);
    final isAlreadyMember = category.mates.contains(targetUserId);
    if (isAlreadyMember) {
      throw Exception('이미 멤버입니다');
    }

    // 5. 인원 제한 확인
    if (category.mates.length >= 10) {
      throw Exception('카테고리 인원이 가득 찼습니다');
    }

    // 6. 대상 사용자도 나를 친구로 추가했는지 확인
    final targetFriends = await _friendRepository.getFriends(targetUserId);
    final requiresAcceptance = !targetFriends.any((f) => f.id == currentUserId);

    if (requiresAcceptance) {
      // 초대 생성
      await _inviteRepository.createInvite(...);
    } else {
      // 바로 추가
      await _categoryRepository.addMember(categoryId, targetUserId);
    }
  }
}
```

#### ✅ 이후 (Spring Boot - Backend)

```java
// src/main/java/com/soi/service/CategoryService.java
@Service
@RequiredArgsConstructor
public class CategoryService {

    private final CategoryRepository categoryRepository;
    private final FriendRepository friendRepository;
    private final UserRepository userRepository;
    private final InviteRepository inviteRepository;

    @Transactional
    public AddMemberResponse addMember(
        String categoryId,
        String currentUserId,
        AddMemberRequest request
    ) {
        String targetUserId = request.getTargetUserId();

        // ✅ 모든 비즈니스 로직이 백엔드에!

        // 1. 카테고리 조회 및 권한 확인
        Category category = categoryRepository.findById(categoryId)
            .orElseThrow(() -> new NotFoundException("Category not found"));

        if (!category.isOwner(currentUserId)) {
            throw new ForbiddenException("Only owner can add members");
        }

        // 2. 친구 확인
        if (!friendRepository.areFriends(currentUserId, targetUserId)) {
            throw new FriendNotFoundException("User is not your friend");
        }

        // 3. 차단 확인
        if (friendRepository.isBlocked(currentUserId, targetUserId)) {
            throw new BlockedUserException("User is blocked");
        }

        // 4. 중복 확인
        if (category.hasMember(targetUserId)) {
            throw new AlreadyMemberException("User is already a member");
        }

        // 5. 인원 제한
        if (category.getMates().size() >= MAX_MEMBERS) {
            throw new CategoryFullException("Category is full");
        }

        // 6. 양방향 친구 확인
        boolean isMutualFriend = friendRepository.areFriends(targetUserId, currentUserId);

        if (isMutualFriend) {
            // 바로 추가
            category.addMember(targetUserId);
            categoryRepository.save(category);

            return AddMemberResponse.builder()
                .requiresAcceptance(false)
                .message("Member added successfully")
                .build();
        } else {
            // 초대 생성
            Invite invite = Invite.builder()
                .categoryId(categoryId)
                .inviterId(currentUserId)
                .inviteeId(targetUserId)
                .build();

            inviteRepository.save(invite);

            return AddMemberResponse.builder()
                .requiresAcceptance(true)
                .inviteId(invite.getId())
                .message("Invitation sent")
                .build();
        }
    }
}
```

#### ✅ 이후 (Flutter - Frontend)

```dart
// lib/repositories/category_repository.dart
class CategoryRepository {
  final CategoryApi _api;  // 자동 생성된 API 클라이언트

  CategoryRepository(this._api);

  /// 멤버 추가 (간단해짐!)
  Future<AddMemberResponse> addMember({
    required String categoryId,
    required String targetUserId,
  }) async {
    try {
      final request = AddMemberRequest((b) => b
        ..targetUserId = targetUserId
      );

      final response = await _api.addMember(
        id: categoryId,
        addMemberRequest: request,
      );

      return response.data!.data!;
    } on DioException catch (e) {
      // ✅ 에러는 백엔드에서 이미 판단됨
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    // 백엔드의 에러 코드를 사용자 친화적 메시지로 변환만
    final errorCode = e.response?.data?['error']?['code'];
    switch (errorCode) {
      case 'FRIEND_NOT_FOUND':
        return Exception('친구를 먼저 추가해주세요');
      case 'BLOCKED_USER':
        return Exception('차단된 사용자입니다');
      case 'ALREADY_MEMBER':
        return Exception('이미 멤버입니다');
      case 'CATEGORY_FULL':
        return Exception('카테고리 인원이 가득 찼습니다 (최대 10명)');
      default:
        return Exception(e.message);
    }
  }
}
```

**비교:**

- **이전:** Flutter Service 150줄 → **이후:** Flutter Repository 30줄
- **이전:** 6단계 검증 로직 → **이후:** API 1회 호출
- **이전:** Firebase 6번 호출 → **이후:** REST API 1번 호출

---

### 예시 2: 사진 업로드

#### ❌ 이전 (Firebase - Flutter)

```dart
// lib/services/photo_service.dart
class PhotoService {
  Future<void> uploadPhoto({
    required String categoryId,
    required File imageFile,
    required File audioFile,
  }) async {
    // ❌ 복잡한 업로드 로직이 프론트에

    // 1. 이미지 압축 (프론트)
    final compressed = await _compressImage(imageFile);

    // 2. Firebase Storage 업로드 (직접)
    final imageUrl = await _uploadToStorage(
      'photos/${categoryId}/${uuid}.jpg',
      compressed,
    );

    // 3. 오디오 업로드 (직접)
    final audioUrl = await _uploadToStorage(
      'audios/${categoryId}/${uuid}.aac',
      audioFile,
    );

    // 4. Firestore 문서 생성 (직접)
    await FirebaseFirestore.instance
        .collection('categories')
        .doc(categoryId)
        .collection('photos')
        .add({
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'uploaderId': currentUserId,
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    // 5. 알림 전송 (직접)
    await _sendNotifications(categoryId);
  }
}
```

#### ✅ 이후 (Spring Boot - Backend)

```java
// src/main/java/com/soi/service/PhotoService.java
@Service
@RequiredArgsConstructor
public class PhotoService {

    private final FirebaseStorageService storageService;
    private final PhotoRepository photoRepository;
    private final NotificationService notificationService;

    @Transactional
    public PhotoDTO uploadPhoto(
        String categoryId,
        String userId,
        MultipartFile imageFile,
        MultipartFile audioFile
    ) {
        // ✅ 백엔드에서 모든 처리

        // 1. 권한 확인
        validateUploadPermission(categoryId, userId);

        // 2. 이미지 압축 및 업로드
        String imageUrl = storageService.uploadImage(
            String.format("photos/%s/%s.jpg", categoryId, UUID.randomUUID()),
            imageFile,
            ImageQuality.HIGH
        );

        // 3. 오디오 업로드
        String audioUrl = storageService.uploadAudio(
            String.format("audios/%s/%s.aac", categoryId, UUID.randomUUID()),
            audioFile
        );

        // 4. DB 저장
        Photo photo = Photo.builder()
            .categoryId(categoryId)
            .uploaderId(userId)
            .imageUrl(imageUrl)
            .audioUrl(audioUrl)
            .build();

        photo = photoRepository.save(photo);

        // 5. 비동기 알림
        notificationService.notifyPhotoUpload(categoryId, photo.getId());

        return PhotoDTO.from(photo);
    }
}
```

#### ✅ 이후 (Flutter - Frontend)

```dart
// lib/repositories/photo_repository.dart
class PhotoRepository {
  final PhotoApi _api;

  Future<PhotoDTO> uploadPhoto({
    required String categoryId,
    required File imageFile,
    required File audioFile,
  }) async {
    // ✅ 간단한 멀티파트 요청만
    final response = await _api.uploadPhoto(
      categoryId: categoryId,
      imageFile: MultipartFile.fromFileSync(imageFile.path),
      audioFile: MultipartFile.fromFileSync(audioFile.path),
    );

    return response.data!.data!;
  }
}
```

**비교:**

- **이전:** 5단계 복잡한 로직 → **이후:** 단순 파일 업로드
- **이전:** Firebase SDK 직접 사용 → **이후:** REST API 호출
- **이전:** 알림 로직 포함 → **이후:** 백엔드에서 처리

---

## 🧩 3. 데이터 검증 분리

### 클라이언트 검증 (Flutter)

**목적:** 빠른 UI 피드백

```dart
// lib/widgets/create_category_form.dart
class CreateCategoryForm extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            decoration: InputDecoration(labelText: '카테고리 이름'),
            validator: (value) {
              // ✅ 클라이언트 검증: 빠른 피드백
              if (value == null || value.isEmpty) {
                return '카테고리 이름을 입력하세요';
              }
              if (value.length > 50) {
                return '50자 이하로 입력하세요';
              }
              return null;
            },
          ),

          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // 검증 통과 후 API 호출
                _createCategory();
              }
            },
            child: Text('생성'),
          ),
        ],
      ),
    );
  }
}
```

### 서버 검증 (Spring Boot)

**목적:** 데이터 무결성 보장

```java
// src/main/java/com/soi/dto/category/CreateCategoryRequest.java
@Getter
@NoArgsConstructor
public class CreateCategoryRequest {

    @NotBlank(message = "카테고리 이름은 필수입니다")
    @Size(max = 50, message = "카테고리 이름은 50자 이하여야 합니다")
    private String name;

    @Size(max = 10, message = "초기 멤버는 최대 10명입니다")
    private List<String> initialMemberIds;
}

// Service에서 추가 검증
@Service
public class CategoryService {

    @Transactional
    public CategoryDTO createCategory(String userId, CreateCategoryRequest request) {
        // ✅ 서버 검증: 데이터 무결성

        // 1. Bean Validation (자동)
        // @NotBlank, @Size 등이 자동으로 검증됨

        // 2. 비즈니스 검증
        if (categoryRepository.countByUserId(userId) >= MAX_CATEGORIES_PER_USER) {
            throw new LimitExceededException("카테고리는 최대 50개까지 생성 가능합니다");
        }

        // 3. 관계 검증
        for (String memberId : request.getInitialMemberIds()) {
            if (!friendRepository.areFriends(userId, memberId)) {
                throw new FriendNotFoundException(
                    String.format("User %s is not your friend", memberId)
                );
            }
        }

        // ... 생성 로직
    }
}
```

**분리 전략:**

- **클라이언트:** 형식, 길이, 필수 입력 → 빠른 피드백
- **서버:** 비즈니스 규칙, 관계 검증, 보안 → 데이터 무결성

---

## 🔐 4. 보안 관련 역할

### 인증 (Authentication)

```java
// Backend: JWT 토큰 생성 및 검증
@Service
public class AuthService {

    public AuthResponse login(LoginRequest request) {
        // ✅ 백엔드에서만 JWT 생성
        User user = userRepository.findByPhone(request.getPhone())
            .orElseThrow(() -> new UnauthorizedException("Invalid credentials"));

        String accessToken = jwtTokenProvider.createAccessToken(user.getId());
        String refreshToken = jwtTokenProvider.createRefreshToken(user.getId());

        return AuthResponse.builder()
            .accessToken(accessToken)
            .refreshToken(refreshToken)
            .user(UserDTO.from(user))
            .build();
    }
}
```

```dart
// Frontend: 토큰 저장 및 전송
class AuthRepository {
  Future<AuthResponse> login(String phone, String verificationCode) async {
    final response = await _api.login(
      loginRequest: LoginRequest((b) => b
        ..phone = phone
        ..verificationCode = verificationCode
      ),
    );

    // ✅ 프론트는 토큰만 저장
    final authResponse = response.data!.data!;
    await _secureStorage.write(
      key: 'access_token',
      value: authResponse.accessToken,
    );

    return authResponse;
  }
}
```

### 권한 부여 (Authorization)

```java
// Backend: 권한 검증
@Service
public class CategoryService {

    public void deleteCategory(String categoryId, String userId) {
        Category category = categoryRepository.findById(categoryId)
            .orElseThrow(() -> new NotFoundException("Category not found"));

        // ✅ 백엔드에서만 권한 체크
        if (!category.isOwner(userId)) {
            throw new ForbiddenException("Only owner can delete category");
        }

        categoryRepository.delete(category);
    }
}
```

```dart
// Frontend: UI에만 반영
class CategoryCard extends StatelessWidget {
  final CategoryDTO category;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    // ✅ UI 표시 여부만 결정 (보안은 백엔드)
    final isOwner = category.ownerId == currentUserId;

    return Card(
      child: Column(
        children: [
          Text(category.name),

          if (isOwner)  // 주인에게만 삭제 버튼 표시
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _deleteCategory(context),
            ),
        ],
      ),
    );
  }
}
```

**보안 원칙:**

- **클라이언트:** UI 표시 여부만 결정 (보안 X)
- **서버:** 실제 권한 검증 (보안 O)
- 클라이언트 검증은 우회 가능하므로 서버에서 반드시 재검증

---

## 📊 5. 복잡도 비교

### Firebase 구조 (이전)

```
CategoryMemberService.addMember() - 150줄
├─ FriendRepository.getFriends() - Firestore 호출
├─ FriendRepository.getBlockedUsers() - Firestore 호출
├─ CategoryRepository.getCategory() - Firestore 호출
├─ FriendRepository.getFriends(targetUser) - Firestore 호출
└─ InviteRepository.createInvite() - Firestore 호출

총 5번의 네트워크 호출, 복잡한 로직이 Flutter에
```

### Spring Boot 구조 (이후)

```
CategoryRepository.addMember() - 30줄
└─ CategoryApi.addMember() - 자동 생성

CategoryService.addMember() - 80줄 (Backend)
└─ 모든 검증 및 비즈니스 로직

총 1번의 API 호출, 간결한 Flutter 코드
```

---

## ✅ 체크리스트: 어디에 구현할까?

새로운 기능을 개발할 때 이 체크리스트를 사용하세요:

### 백엔드에 구현

- [ ] 친구 관계 확인
- [ ] 차단 여부 확인
- [ ] 권한 검증 (소유자, 관리자 등)
- [ ] 데이터 일관성 검증
- [ ] 복잡한 필터링 (SQL JOIN)
- [ ] 트랜잭션 처리
- [ ] 알림 전송
- [ ] 외부 API 호출
- [ ] 민감 정보 처리

### 프론트엔드에 구현

- [ ] 입력 형식 검증 (이메일, 전화번호)
- [ ] UI 상태 관리 (로딩, 에러)
- [ ] 애니메이션
- [ ] 이미지 캐싱
- [ ] 로컬 저장소 (토큰, 설정)
- [ ] 카메라/녹음 제어
- [ ] 사용자 친화적 에러 메시지

---

## 📝 다음 단계

역할 분리를 이해했다면:

👉 **[5. Flutter 프로젝트 구조 변경으로 이동](./05-flutter-structure-changes.md)**
