# 친구 삭제 & 차단 기능 구현 가이드 📋

> SOI 앱의 친구 관계 관리를 위한 삭제 및 차단 기능 구현 계획서

## 🎯 기능 요구사항

### 친구 삭제 (Remove Friend)
- ✅ **일방향 삭제**: 내 친구 목록에서만 친구 제거
- ✅ **카테고리 제약**: 삭제한 친구를 카테고리에 추가할 수 없음
- ✅ **비대칭 관계**: 상대방은 여전히 나를 친구로 보고 카테고리에 추가 가능

### 친구 차단 (Block Friend)  
- ✅ **양방향 제약**: 서로 카테고리에 추가할 수 없음
- ✅ **관계 유지**: 친구 관계는 유지하되 status만 'blocked'로 변경
- ✅ **복구 가능**: 차단 해제 시 정상 친구 관계로 복귀

## 🏗️ 현재 아키텍처 분석

### ✅ 이미 구현된 기능
```dart
// FriendService - 이미 존재
Future<void> removeFriend(String friendUid)     // 친구 삭제
Future<void> blockFriend(String friendUid)      // 친구 차단  
Future<void> unblockFriend(String friendUid)    // 차단 해제

// FriendRepository - 이미 존재
Future<void> removeFriend(String friendUid)     // 양방향 삭제로 구현됨 ⚠️
Future<void> blockFriend(String friendUid)      // status = 'blocked'
Future<void> unblockFriend(String friendUid)    // status = 'active'
```

### ❌ 누락된 기능
- **CategoryService**: 친구 관계 상태 확인 없음
- **카테고리 추가 검증**: `addUidToCategory()`에서 제약 확인 안 함
- **UI 필터링**: 추가 불가능한 친구들 구분 표시 없음

## 📝 단계별 구현 계획

### Phase 1: FriendRepository 핵심 수정 🔧

#### 1.1 친구 삭제를 일방향으로 변경
```dart
// 📁 lib/repositories/friend_repository.dart

/// 친구 삭제 - 일방향으로 수정
Future<void> removeFriend(String friendUid) async {
  final currentUid = _currentUserUid;
  if (currentUid == null) {
    throw Exception('사용자가 로그인되어 있지 않습니다');
  }

  try {
    // ❌ 기존: 양방향 삭제
    // await _firestore.runTransaction((transaction) async {
    //   // A의 friends에서 B 삭제 + B의 friends에서 A 삭제
    // });

    // ✅ 수정: 일방향 삭제
    await _usersCollection
        .doc(currentUid)           // 현재 사용자의
        .collection('friends')     // friends 서브컬렉션에서
        .doc(friendUid)           // 해당 친구만 삭제
        .delete();
        
    debugPrint('일방향 친구 삭제 완료: $currentUid -> $friendUid');
  } catch (e) {
    throw Exception('친구 삭제 실패: $e');
  }
}
```

#### 1.2 카테고리 추가 가능 여부 확인 메서드 추가
```dart
// 📁 lib/repositories/friend_repository.dart

/// 카테고리 추가 가능 여부 확인
Future<bool> canAddToCategory(String requesterId, String targetId) async {
  try {
    // 1. requester가 target을 삭제했는지 확인
    final requesterFriend = await getFriend(targetId);
    if (requesterFriend == null) {
      debugPrint('❌ requester가 target을 삭제함: $requesterId -> $targetId');
      return false; // 삭제했거나 원래 친구 아님
    }
    
    // 2. requester가 target을 차단했는지 확인  
    if (requesterFriend.status == FriendStatus.blocked) {
      debugPrint('❌ requester가 target을 차단함: $requesterId -> $targetId');
      return false;
    }
    
    // 3. target이 requester를 차단했는지 확인 (양방향 차단)
    final targetFriend = await _getTargetUserFriend(requesterId, targetId);
    if (targetFriend?.status == FriendStatus.blocked) {
      debugPrint('❌ target이 requester를 차단함: $targetId -> $requesterId');
      return false;
    }
    
    debugPrint('✅ 카테고리 추가 가능: $requesterId -> $targetId');
    return true;
  } catch (e) {
    debugPrint('⚠️ canAddToCategory 에러: $e');
    return false; // 안전하게 false 반환
  }
}

/// 다른 사용자 관점에서 친구 정보 조회
Future<FriendModel?> _getTargetUserFriend(String requesterId, String targetId) async {
  try {
    final doc = await _usersCollection
        .doc(targetId)              // target 사용자의
        .collection('friends')      // friends 컬렉션에서
        .doc(requesterId)          // requester에 대한 친구 정보 조회
        .get();
        
    return doc.exists ? FriendModel.fromFirestore(doc) : null;
  } catch (e) {
    debugPrint('_getTargetUserFriend 에러: $e');
    return null;
  }
}

/// 카테고리 추가 불가 이유 반환
Future<String?> getCannotAddReason(String requesterId, String targetId) async {
  try {
    final requesterFriend = await getFriend(targetId);
    
    if (requesterFriend == null) {
      return '삭제된 친구는 카테고리에 추가할 수 없습니다.';
    }
    
    if (requesterFriend.status == FriendStatus.blocked) {
      return '차단된 친구는 카테고리에 추가할 수 없습니다.';
    }
    
    // target이 requester를 차단했는지 확인
    final targetFriend = await _getTargetUserFriend(requesterId, targetId);
    if (targetFriend?.status == FriendStatus.blocked) {
      return '이 사용자가 회원님을 차단하여 카테고리에 추가할 수 없습니다.';
    }
    
    return null; // 추가 가능
  } catch (e) {
    return '확인 중 오류가 발생했습니다.';
  }
}
```

### Phase 2: FriendService 확장 📦

```dart
// 📁 lib/services/friend_service.dart

/// 카테고리 추가 가능 여부 확인 (비즈니스 로직 래퍼)
Future<bool> canAddToCategory(String requesterId, String targetId) async {
  try {
    if (requesterId.isEmpty || targetId.isEmpty) {
      return false;
    }
    
    if (requesterId == targetId) {
      return false; // 자기 자신 추가 불가
    }
    
    return await _friendRepository.canAddToCategory(requesterId, targetId);
  } catch (e) {
    debugPrint('FriendService.canAddToCategory 에러: $e');
    return false;
  }
}

/// 카테고리 추가 불가 이유 반환
Future<String?> getCannotAddReason(String requesterId, String targetId) async {
  try {
    if (requesterId == targetId) {
      return '자기 자신은 이미 카테고리 멤버입니다.';
    }
    
    return await _friendRepository.getCannotAddReason(requesterId, targetId);
  } catch (e) {
    return '확인 중 오류가 발생했습니다.';
  }
}

/// 친구 관계 상태 확인
Future<FriendshipRelation> getFriendshipRelation(String currentUserId, String targetUserId) async {
  try {
    final myFriend = await _friendRepository.getFriend(targetUserId);
    final theirFriend = await _friendRepository._getTargetUserFriend(currentUserId, targetUserId);
    
    // 내가 상대를 어떻게 보는지
    if (myFriend == null) {
      // 상대가 나를 어떻게 보는지
      if (theirFriend?.status == FriendStatus.blocked) {
        return FriendshipRelation.blockedByOther;
      }
      return FriendshipRelation.notFriends;
    }
    
    if (myFriend.status == FriendStatus.blocked) {
      return FriendshipRelation.blockedByMe;
    }
    
    if (theirFriend?.status == FriendStatus.blocked) {
      return FriendshipRelation.blockedByOther;
    }
    
    return FriendshipRelation.friends;
  } catch (e) {
    return FriendshipRelation.unknown;
  }
}
```

#### 새로운 enum 추가
```dart
// 📁 lib/models/friendship_relation.dart

/// 친구 관계 상태
enum FriendshipRelation {
  friends,          // 정상 친구 관계
  blockedByMe,      // 내가 상대를 차단
  blockedByOther,   // 상대가 나를 차단
  notFriends,       // 친구 관계 없음 (삭제되었거나 원래 친구 아님)
  unknown,          // 확인 불가
}

extension FriendshipRelationExtension on FriendshipRelation {
  String get displayText {
    switch (this) {
      case FriendshipRelation.friends:
        return '친구';
      case FriendshipRelation.blockedByMe:
        return '차단함';
      case FriendshipRelation.blockedByOther:
        return '차단됨';
      case FriendshipRelation.notFriends:
        return '친구 아님';
      case FriendshipRelation.unknown:
        return '확인 중';
    }
  }
  
  bool get canAddToCategory {
    return this == FriendshipRelation.friends;
  }
}
```

### Phase 3: CategoryService 핵심 수정 🎯

```dart
// 📁 lib/services/category_service.dart

class CategoryService {
  // FriendService 의존성 추가
  FriendService? _friendService;
  FriendService get friendService {
    _friendService ??= FriendService(
      friendRepository: FriendRepository(),
      userSearchRepository: UserSearchRepository(),
    );
    return _friendService!;
  }

  /// 카테고리에 사용자 추가 (UID로) - 핵심 수정
  Future<AuthResult> addUidToCategory({
    required String categoryId,
    required String uid,
  }) async {
    try {
      debugPrint('🎯 카테고리 사용자 추가 시도: $categoryId <- $uid');
      
      // 1. 현재 사용자 확인
      final currentUserId = _getCurrentUserId(); // AuthService에서 가져오기
      if (currentUserId == null || currentUserId.isEmpty) {
        return AuthResult.failure('로그인이 필요합니다.');
      }
      
      // 2. 자기 자신 추가 시도 확인
      if (currentUserId == uid) {
        return AuthResult.failure('자기 자신은 이미 카테고리 멤버입니다.');
      }
      
      // 3. 카테고리 존재 확인
      final category = await _repository.getCategory(categoryId);
      if (category == null) {
        return AuthResult.failure('카테고리를 찾을 수 없습니다.');
      }
      
      // 4. 이미 멤버인지 확인
      if (category.mates.contains(uid)) {
        return AuthResult.failure('이미 카테고리 멤버입니다.');
      }
      
      // 5. 친구 관계 확인 (핵심 로직)
      final canAdd = await friendService.canAddToCategory(currentUserId, uid);
      if (!canAdd) {
        final reason = await friendService.getCannotAddReason(currentUserId, uid);
        debugPrint('❌ 카테고리 추가 불가: $reason');
        return AuthResult.failure(reason ?? '이 사용자를 카테고리에 추가할 수 없습니다.');
      }
      
      // 6. 실제 추가 실행
      await _repository.addUidToCategory(categoryId: categoryId, uid: uid);
      debugPrint('✅ 카테고리 사용자 추가 성공');
      
      return AuthResult.success(null);
    } catch (e) {
      debugPrint('💥 addUidToCategory 에러: $e');
      return AuthResult.failure('카테고리에 사용자 추가 실패: $e');
    }
  }

  /// 카테고리에 사용자 추가 (닉네임으로) - 동일한 검증 적용
  Future<AuthResult> addUserToCategory({
    required String categoryId,
    required String nickName,
  }) async {
    try {
      // 1. 닉네임으로 UID 찾기
      final userSearchRepository = UserSearchRepository();
      final user = await userSearchRepository.searchUserByNickname(nickName);
      
      if (user == null) {
        return AuthResult.failure('사용자를 찾을 수 없습니다: $nickName');
      }
      
      // 2. UID로 추가 (동일한 검증 로직 적용)
      return await addUidToCategory(categoryId: categoryId, uid: user.uid);
    } catch (e) {
      return AuthResult.failure('카테고리에 사용자 추가 실패: $e');
    }
  }

  /// 현재 사용자 UID 가져오기
  String? _getCurrentUserId() {
    // AuthService 또는 FirebaseAuth에서 현재 사용자 UID 반환
    return FirebaseAuth.instance.currentUser?.uid;
  }
}
```

### Phase 4: UI 수정 🎨

#### 4.1 FriendListAddScreen 필터링 개선
```dart
// 📁 lib/views/about_friends/friend_list_add_screen.dart

class _FriendListAddScreenState extends State<FriendListAddScreen> {
  late FriendService _friendService;
  Map<String, FriendshipRelation> _friendshipRelations = {};
  
  @override
  void initState() {
    super.initState();
    _friendService = FriendService(
      friendRepository: FriendRepository(),
      userSearchRepository: UserSearchRepository(),
    );
    _loadFriendshipRelations();
  }
  
  /// 친구 관계 상태 로드
  void _loadFriendshipRelations() async {
    final authController = context.read<AuthController>();
    final currentUserId = authController.getUserId;
    
    if (currentUserId == null) return;
    
    final relations = <String, FriendshipRelation>{};
    
    for (final friend in _friends) {
      final relation = await _friendService.getFriendshipRelation(
        currentUserId, 
        friend.userId,
      );
      relations[friend.userId] = relation;
    }
    
    if (mounted) {
      setState(() {
        _friendshipRelations = relations;
      });
    }
  }
  
  /// 추가 가능한 친구들만 필터링
  List<FriendModel> get _addableFriends {
    return _friends.where((friend) {
      // 차단된 친구 제외
      final relation = _friendshipRelations[friend.userId];
      if (relation?.canAddToCategory != true) {
        return false;
      }
      
      // 이미 카테고리에 있는 멤버 제외
      if (widget.categoryMemberUids?.contains(friend.userId) == true) {
        return false;
      }
      
      return true;
    }).toList();
  }
  
  /// 친구 항목 UI 구성
  Widget _buildFriendItem(FriendModel friend) {
    final relation = _friendshipRelations[friend.userId];
    final isAddable = relation?.canAddToCategory == true;
    final isAlreadyMember = widget.categoryMemberUids?.contains(friend.userId) == true;
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: isAddable ? const Color(0xFF1c1c1c) : Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAddable ? Colors.transparent : Colors.grey[600]!,
          width: 1,
        ),
      ),
      child: ListTile(
        enabled: isAddable && !isAlreadyMember,
        leading: CircleAvatar(
          backgroundImage: friend.profileImageUrl != null
              ? NetworkImage(friend.profileImageUrl!)
              : null,
          child: friend.profileImageUrl == null
              ? Icon(Icons.person, color: Colors.grey[400])
              : null,
          backgroundColor: Colors.grey[700],
        ),
        title: Text(
          friend.name,
          style: TextStyle(
            color: isAddable ? Colors.white : Colors.grey[400],
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: _buildSubtitle(friend, relation, isAlreadyMember),
        trailing: _buildTrailing(friend, relation, isAddable, isAlreadyMember),
        onTap: isAddable && !isAlreadyMember 
            ? () => _toggleFriendSelection(friend.userId)
            : null,
      ),
    );
  }
  
  /// 서브타이틀 구성
  Widget? _buildSubtitle(FriendModel friend, FriendshipRelation? relation, bool isAlreadyMember) {
    String? subtitleText;
    Color subtitleColor = Colors.grey[400]!;
    
    if (isAlreadyMember) {
      subtitleText = '이미 카테고리 멤버';
      subtitleColor = Colors.blue[300]!;
    } else if (relation != null && !relation.canAddToCategory) {
      subtitleText = relation.displayText;
      subtitleColor = Colors.red[300]!;
    }
    
    return subtitleText != null
        ? Text(
            subtitleText,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 14.sp,
            ),
          )
        : null;
  }
  
  /// 트레일링 아이콘 구성
  Widget? _buildTrailing(FriendModel friend, FriendshipRelation? relation, bool isAddable, bool isAlreadyMember) {
    if (isAlreadyMember) {
      return Icon(Icons.check_circle, color: Colors.blue[300], size: 24.sp);
    }
    
    if (!isAddable) {
      return Icon(Icons.block, color: Colors.red[300], size: 24.sp);
    }
    
    final isSelected = _selectedFriendUids.contains(friend.userId);
    return Icon(
      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
      color: isSelected ? Colors.green : Colors.grey[400],
      size: 24.sp,
    );
  }
}
```

#### 4.2 에러 메시지 개선
```dart
// 📁 lib/controllers/category_controller.dart

/// 카테고리에 사용자를 추가합니다 (UID로) - 에러 처리 개선
Future<void> addUidToCategory(String categoryId, String uid) async {
  try {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _categoryService.addUidToCategory(
      categoryId: categoryId,
      uid: uid,
    );

    _isLoading = false;

    if (!result.isSuccess) {
      _error = result.error;
      
      // 사용자 친화적인 에러 메시지 표시
      _showContextualError(result.error);
      
      notifyListeners();
      throw Exception(result.error);
    }
    
    // 성공 시 새로고침
    invalidateCache();
  } catch (e) {
    _isLoading = false;
    _error = e.toString();
    notifyListeners();
    rethrow;
  }
}

/// 상황별 에러 메시지 표시
void _showContextualError(String? error) {
  if (error == null) return;
  
  String userMessage;
  String emoji;
  
  if (error.contains('차단')) {
    userMessage = '차단된 친구는 카테고리에 추가할 수 없습니다';
    emoji = '🚫';
  } else if (error.contains('삭제')) {
    userMessage = '삭제된 친구는 카테고리에 추가할 수 없습니다';
    emoji = '❌';
  } else if (error.contains('이미 카테고리 멤버')) {
    userMessage = '이미 카테고리에 참여 중인 친구입니다';
    emoji = '👥';
  } else if (error.contains('자기 자신')) {
    userMessage = '본인은 이미 카테고리 멤버입니다';
    emoji = '👤';
  } else {
    userMessage = '카테고리 추가에 실패했습니다';
    emoji = '⚠️';
  }
  
  // 글로벌 메시지 표시 (SnackBar, Toast 등)
  _showGlobalMessage('$emoji $userMessage');
}

void _showGlobalMessage(String message) {
  // 구현은 앱의 전역 메시지 시스템에 따라
  // 예: Get.snackbar, ScaffoldMessenger, 커스텀 Toast 등
}
```

### Phase 5: 기존 카테고리 멤버 관리 🔄

```dart
// 📁 lib/services/category_service.dart

/// 친구 관계 변경 시 카테고리에서 자동 제거
Future<void> handleFriendshipChange({
  required String currentUserId,
  required String targetUserId,
  required String action, // 'delete' or 'block'
}) async {
  try {
    debugPrint('🔄 친구 관계 변경 처리: $currentUserId $action $targetUserId');
    
    // 1. 현재 사용자가 멤버인 모든 카테고리 조회
    final categories = await getUserCategories(currentUserId);
    
    for (final category in categories) {
      // 2. 해당 카테고리에 targetUser가 멤버인지 확인
      if (category.mates.contains(targetUserId)) {
        
        if (action == 'delete') {
          // 삭제의 경우: targetUser는 그대로 두되, currentUser가 나가기
          debugPrint('친구 삭제로 인한 카테고리 나가기: ${category.name}');
          // 필요에 따라 구현
          
        } else if (action == 'block') {
          // 차단의 경우: 양쪽 다 해당 카테고리에서 상대방 제거 알림
          debugPrint('친구 차단으로 인한 카테고리 관계 정리: ${category.name}');
          
          // 차단 알림 생성 (선택사항)
          await notificationService.createBlockNotification(
            categoryId: category.id,
            blockerUserId: currentUserId,
            blockedUserId: targetUserId,
          );
        }
      }
    }
  } catch (e) {
    debugPrint('handleFriendshipChange 에러: $e');
  }
}
```

## 🧪 테스트 시나리오

### 테스트 케이스 1: 친구 삭제
```dart
// 테스트 시나리오
void testFriendDelete() async {
  // Given: A와 B가 친구 관계
  await addFriend(userA, userB);
  
  // When: A가 B를 친구 삭제
  await friendService.removeFriend(userB.uid);
  
  // Then 1: A의 친구 목록에서 B 사라짐
  final aFriends = await friendRepository.getFriendsList();
  assert(!aFriends.any((f) => f.userId == userB.uid));
  
  // Then 2: B는 여전히 A를 친구로 봄
  // (B의 관점에서 확인 필요)
  
  // Then 3: A가 B를 카테고리에 추가 시도 → 실패
  final result = await categoryService.addUidToCategory(
    categoryId: testCategory.id,
    uid: userB.uid,
  );
  assert(!result.isSuccess);
  
  // Then 4: B가 A를 카테고리에 추가 → 성공해야 함
  // (B의 권한으로 테스트 필요)
}
```

### 테스트 케이스 2: 친구 차단
```dart
void testFriendBlock() async {
  // Given: A와 B가 친구 관계
  await addFriend(userA, userB);
  
  // When: A가 B를 차단
  await friendService.blockFriend(userB.uid);
  
  // Then 1: A가 B를 카테고리에 추가 시도 → 실패
  final resultA = await categoryService.addUidToCategory(
    categoryId: testCategory.id,
    uid: userB.uid,
  );
  assert(!resultA.isSuccess);
  
  // Then 2: B가 A를 카테고리에 추가 시도 → 실패 (양방향)
  final resultB = await categoryService.addUidToCategory(
    categoryId: testCategory2.id,
    uid: userA.uid,
  );
  assert(!resultB.isSuccess);
  
  // Then 3: A가 B 차단 해제
  await friendService.unblockFriend(userB.uid);
  
  // Then 4: 정상 관계 복구 확인
  final resultAfterUnblock = await categoryService.addUidToCategory(
    categoryId: testCategory.id,
    uid: userB.uid,
  );
  assert(resultAfterUnblock.isSuccess);
}
```

## 🚀 구현 체크리스트

### Phase 1: Repository 수정 ✅
- [ ] `FriendRepository.removeFriend()` 일방향으로 수정
- [ ] `canAddToCategory()` 메서드 추가
- [ ] `_getTargetUserFriend()` 메서드 추가
- [ ] `getCannotAddReason()` 메서드 추가
- [ ] 단위 테스트 작성

### Phase 2: Service 확장 ✅
- [ ] `FriendService.canAddToCategory()` 래퍼 추가
- [ ] `getCannotAddReason()` 래퍼 추가
- [ ] `getFriendshipRelation()` 메서드 추가
- [ ] `FriendshipRelation` enum 생성
- [ ] 비즈니스 로직 테스트

### Phase 3: Category 검증 ✅
- [ ] `CategoryService`에 `FriendService` 의존성 추가
- [ ] `addUidToCategory()` 검증 로직 추가
- [ ] `addUserToCategory()` 검증 로직 추가
- [ ] 에러 메시지 개선
- [ ] 통합 테스트

### Phase 4: UI 개선 ✅
- [ ] `FriendListAddScreen` 필터링 로직 추가
- [ ] 친구 상태별 UI 구분 표시
- [ ] 에러 메시지 사용자 친화적으로 개선
- [ ] 로딩 상태 및 피드백 개선
- [ ] UI/UX 테스트

### Phase 5: 고급 기능 ⭐
- [ ] 기존 카테고리 멤버 관리
- [ ] 친구 관계 변경 시 알림
- [ ] 관리자 대시보드 (선택사항)
- [ ] 성능 최적화

## 📋 주의사항

### 1. 데이터 일관성
- Firestore 트랜잭션 사용으로 데이터 일관성 보장
- 캐시 무효화 타이밍 주의

### 2. 성능 고려사항
- 친구 관계 확인 쿼리 최적화
- 대용량 친구 목록 처리 시 페이지네이션 고려
- Stream 구독 관리로 메모리 누수 방지

### 3. 사용자 경험
- 명확한 에러 메시지 제공
- 적절한 로딩 인디케이터
- 되돌리기 기능 고려 (친구 삭제 실수 시)

### 4. 보안 고려사항
- 권한 검증을 서버사이드에서도 수행
- 악의적인 카테고리 추가 시도 방지
- 개인정보 보호 정책 준수

## 🏁 마무리

이 구현 계획을 통해 SOI 앱의 친구 삭제 및 차단 기능을 체계적으로 구현할 수 있습니다. 각 단계별로 테스트를 진행하고, 사용자 피드백을 반영하여 점진적으로 개선해 나가세요.

**핵심 포인트:**
- ✅ **일방향 삭제**: 삭제한 사람만 제약
- ✅ **양방향 차단**: 서로 카테고리 추가 불가
- ✅ **명확한 UI**: 상태별 구분 표시
- ✅ **안전한 검증**: 서버사이드 권한 확인

좋은 사용자 경험을 위해 단계별로 차근차근 구현해 보세요! 🚀
