# 코드 개선 권장사항 가이드

> 📅 작성일: 2025-10-16
> 🎯 목적: SOLID 원칙 준수를 위한 구체적인 리팩토링 가이드
> 📊 우선순위: High → Medium → Low

## 📑 목차

1. [High Priority - 즉시 개선 권장](#high-priority)
2. [Medium Priority - 점진적 개선](#medium-priority)
3. [Low Priority - 선택적 개선](#low-priority)
4. [마이그레이션 전략](#마이그레이션-전략)
5. [예상 효과](#예상-효과)

---

## 🔴 High Priority - 즉시 개선 권장

### 1. 인터페이스/추상 클래스 도입

#### 📌 문제점
```dart
// 현재: lib/services/photo_service.dart
class PhotoService {
  final PhotoRepository _photoRepository = PhotoRepository();
  final AudioRepository _audioRepository = AudioRepository();

  // ...
}
```

**문제**:
- 구체 클래스에 직접 의존 → 테스트 어려움
- Mock 객체 주입 불가능
- 확장성 제한 (새로운 구현체 추가 시 코드 수정 필요)

#### ✅ 해결 방안

**Step 1: 인터페이스 정의**

```dart
// lib/interfaces/i_photo_repository.dart
abstract class IPhotoRepository {
  /// 이미지를 스토리지에 업로드
  Future<String?> uploadImageToStorage({
    required File imageFile,
    required String categoryId,
    required String userId,
    String? customFileName,
  });

  /// 사진 메타데이터를 Firestore에 저장
  Future<String?> savePhotoToFirestore({
    required PhotoDataModel photo,
    required String categoryId,
  });

  /// 카테고리별 사진 목록 조회
  Future<List<PhotoDataModel>> getPhotosByCategory(String categoryId);

  /// 사진 삭제 (soft delete)
  Future<bool> deletePhoto({
    required String categoryId,
    required String photoId,
  });

  /// 사진 ID로 조회
  Future<PhotoDataModel?> getPhotoById({
    required String categoryId,
    required String photoId,
  });
}
```

**Step 2: 기존 Repository에 인터페이스 구현**

```dart
// lib/repositories/photo_repository.dart
class PhotoRepository implements IPhotoRepository {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  Future<String?> uploadImageToStorage({
    required File imageFile,
    required String categoryId,
    required String userId,
    String? customFileName,
  }) async {
    // 기존 구현 유지
  }

  @override
  Future<String?> savePhotoToFirestore({
    required PhotoDataModel photo,
    required String categoryId,
  }) async {
    // 기존 구현 유지
  }

  // ... 나머지 메서드들
}
```

**Step 3: Service에 의존성 주입**

```dart
// lib/services/photo_service.dart
class PhotoService {
  final IPhotoRepository _photoRepository;
  final IAudioRepository _audioRepository;

  // 생성자 주입
  PhotoService({
    required IPhotoRepository photoRepository,
    required IAudioRepository audioRepository,
  })  : _photoRepository = photoRepository,
        _audioRepository = audioRepository;

  // 기존 메서드들은 그대로 유지
  Future<PhotoUploadResult> uploadPhoto({
    required File imageFile,
    File? audioFile,
    required String categoryId,
    required String userId,
    required List<String> userIds,
    String? caption,
  }) async {
    // 기존 로직 유지
  }
}
```

**Step 4: Provider 설정**

```dart
// lib/main.dart
void main() {
  runApp(
    MultiProvider(
      providers: [
        // Repositories
        Provider<IPhotoRepository>(
          create: (_) => PhotoRepository(),
        ),
        Provider<IAudioRepository>(
          create: (_) => AudioRepository(),
        ),
        Provider<ICategoryRepository>(
          create: (_) => CategoryRepository(),
        ),

        // Services
        Provider<PhotoService>(
          create: (context) => PhotoService(
            photoRepository: context.read<IPhotoRepository>(),
            audioRepository: context.read<IAudioRepository>(),
          ),
        ),

        // Controllers
        ChangeNotifierProvider<PhotoController>(
          create: (context) => PhotoController(
            photoService: context.read<PhotoService>(),
          ),
        ),
      ],
      child: MyApp(),
    ),
  );
}
```

#### 📊 효과
- ✅ 테스트 용이성: Mock 객체 주입 가능
- ✅ 확장성: 새로운 구현체 추가 용이 (예: MockPhotoRepository)
- ✅ 유지보수성: 인터페이스 변경 시 컴파일 타임에 오류 발견
- ✅ SOLID: OCP, DIP 원칙 준수

#### 📁 적용 대상 파일
```
lib/repositories/
  ├── photo_repository.dart
  ├── audio_repository.dart
  ├── category_repository.dart
  ├── friend_repository.dart
  ├── comment_record_repository.dart
  └── emoji_reaction_repository.dart

lib/interfaces/ (새로 생성)
  ├── i_photo_repository.dart
  ├── i_audio_repository.dart
  ├── i_category_repository.dart
  ├── i_friend_repository.dart
  ├── i_comment_record_repository.dart
  └── i_emoji_reaction_repository.dart

lib/services/
  ├── photo_service.dart (생성자 주입으로 수정)
  ├── audio_service.dart
  ├── category_service.dart
  └── ... (모든 Service)
```

---

### 2. CategoryService 분리 (God Class 해결)

#### 📌 문제점
```dart
// 현재: lib/services/category_service.dart
class CategoryService {
  // 42개 메서드가 하나의 클래스에!

  // 카테고리 CRUD
  Future<void> createCategory(...) {}
  Future<void> updateCategory(...) {}
  Future<void> deleteCategory(...) {}

  // 초대 관리
  Future<void> acceptPendingInvite(...) {}
  Future<void> declinePendingInvite(...) {}

  // 멤버 관리
  Future<void> addUserToCategory(...) {}
  Future<void> removeUidFromCategory(...) {}

  // 사진 관리
  Future<void> addPhotoToCategory(...) {}
  Future<void> removePhotoFromCategory(...) {}

  // 커버 사진 관리
  Future<void> updateCoverPhotoFromGallery(...) {}
  Future<void> updateCoverPhotoFromCategory(...) {}
  Future<void> deleteCoverPhoto(...) {}
}
```

**문제**:
- SRP 위반: 너무 많은 책임
- 테스트 어려움: 42개 메서드 테스트
- 유지보수 어려움: 코드 이해와 수정 힘듦

#### ✅ 해결 방안

**새로운 구조**
```
CategoryService (기본 CRUD)
  - createCategory
  - updateCategory
  - deleteCategory
  - getCategory
  - getUserCategories

CategoryMemberService (멤버 관리)
  - addMember
  - removeMember
  - getMemberList
  - isUserMember

CategoryInviteService (초대 관리)
  - createInvite
  - acceptInvite
  - declineInvite
  - getInvites

CategoryPhotoService (사진 관리)
  - addPhoto
  - removePhoto
  - getPhotos

CategoryCoverService (커버 사진)
  - updateCover
  - deleteCover
  - getCover
```

**구현 예시**

```dart
// lib/services/category/category_service.dart
class CategoryService {
  final ICategoryRepository _repository;

  CategoryService({required ICategoryRepository repository})
      : _repository = repository;

  /// 카테고리 생성
  Future<String> createCategory({
    required String name,
    required String userId,
    List<String>? mates,
  }) async {
    // 검증
    if (name.isEmpty) {
      throw ArgumentError('카테고리 이름이 필요합니다.');
    }

    return await _repository.createCategory(
      name: name,
      userId: userId,
      mates: mates ?? [userId],
    );
  }

  /// 카테고리 조회
  Future<CategoryDataModel?> getCategory(String categoryId) async {
    return await _repository.getCategory(categoryId);
  }

  /// 사용자의 카테고리 목록
  Future<List<CategoryDataModel>> getUserCategories(String userId) async {
    return await _repository.getUserCategories(userId);
  }

  /// 카테고리 업데이트
  Future<void> updateCategory({
    required String categoryId,
    String? name,
    bool? isPinned,
  }) async {
    await _repository.updateCategory(
      categoryId: categoryId,
      name: name,
      isPinned: isPinned,
    );
  }

  /// 카테고리 삭제
  Future<void> deleteCategory(String categoryId) async {
    await _repository.deleteCategory(categoryId);
  }
}
```

```dart
// lib/services/category/category_member_service.dart
class CategoryMemberService {
  final ICategoryRepository _repository;
  final IFriendService _friendService;

  CategoryMemberService({
    required ICategoryRepository repository,
    required IFriendService friendService,
  })  : _repository = repository,
        _friendService = friendService;

  /// 멤버 추가
  Future<void> addMember({
    required String categoryId,
    required String userId,
  }) async {
    // 친구인지 확인
    final canAdd = await _friendService.canAddToCategory(userId);
    if (!canAdd) {
      throw Exception('친구만 추가할 수 있습니다.');
    }

    await _repository.addUserToCategory(
      categoryId: categoryId,
      userId: userId,
    );
  }

  /// 멤버 제거
  Future<void> removeMember({
    required String categoryId,
    required String userId,
  }) async {
    await _repository.removeUidFromCategory(
      categoryId: categoryId,
      userId: userId,
    );
  }

  /// 멤버 확인
  Future<bool> isUserMember({
    required String categoryId,
    required String userId,
  }) async {
    return await _repository.isUserMemberOfCategory(
      categoryId: categoryId,
      userId: userId,
    );
  }
}
```

```dart
// lib/services/category/category_invite_service.dart
class CategoryInviteService {
  final ICategoryInviteRepository _inviteRepository;
  final INotificationService _notificationService;

  CategoryInviteService({
    required ICategoryInviteRepository inviteRepository,
    required INotificationService notificationService,
  })  : _inviteRepository = inviteRepository,
        _notificationService = notificationService;

  /// 초대 생성
  Future<String> createInvite({
    required String categoryId,
    required String fromUserId,
    required String toUserId,
  }) async {
    // 초대 생성
    final inviteId = await _inviteRepository.createInvite(
      categoryId: categoryId,
      fromUserId: fromUserId,
      toUserId: toUserId,
    );

    // 알림 생성
    await _notificationService.createCategoryInviteNotification(
      inviteId: inviteId,
      categoryId: categoryId,
      fromUserId: fromUserId,
      toUserId: toUserId,
    );

    return inviteId;
  }

  /// 초대 수락
  Future<void> acceptInvite(String inviteId) async {
    await _inviteRepository.acceptInvite(inviteId);
  }

  /// 초대 거절
  Future<void> declineInvite(String inviteId) async {
    await _inviteRepository.declineInvite(inviteId);
  }
}
```

```dart
// lib/services/category/category_cover_service.dart
class CategoryCoverService {
  final ICategoryRepository _repository;

  CategoryCoverService({required ICategoryRepository repository})
      : _repository = repository;

  /// 갤러리에서 커버 사진 업데이트
  Future<void> updateCoverFromGallery({
    required String categoryId,
    required File imageFile,
  }) async {
    final imageUrl = await _repository.uploadCoverImage(
      categoryId: categoryId,
      imageFile: imageFile,
    );

    await _repository.updateCategory(
      categoryId: categoryId,
      categoryPhotoUrl: imageUrl,
    );
  }

  /// 카테고리 사진에서 커버 선택
  Future<void> updateCoverFromCategory({
    required String categoryId,
    required String photoUrl,
  }) async {
    await _repository.updateCategory(
      categoryId: categoryId,
      categoryPhotoUrl: photoUrl,
    );
  }

  /// 커버 사진 삭제
  Future<void> deleteCover(String categoryId) async {
    await _repository.updateCategory(
      categoryId: categoryId,
      categoryPhotoUrl: null,
    );
  }
}
```

**Provider 설정**

```dart
// lib/main.dart
MultiProvider(
  providers: [
    // Category 관련 Services
    Provider<CategoryService>(
      create: (context) => CategoryService(
        repository: context.read<ICategoryRepository>(),
      ),
    ),
    Provider<CategoryMemberService>(
      create: (context) => CategoryMemberService(
        repository: context.read<ICategoryRepository>(),
        friendService: context.read<IFriendService>(),
      ),
    ),
    Provider<CategoryInviteService>(
      create: (context) => CategoryInviteService(
        inviteRepository: context.read<ICategoryInviteRepository>(),
        notificationService: context.read<INotificationService>(),
      ),
    ),
    Provider<CategoryCoverService>(
      create: (context) => CategoryCoverService(
        repository: context.read<ICategoryRepository>(),
      ),
    ),
  ],
)
```

#### 📊 효과
- ✅ SRP 준수: 각 클래스가 단일 책임
- ✅ 테스트 용이성: 작은 단위로 테스트 가능
- ✅ 가독성: 코드 이해와 수정 용이
- ✅ 재사용성: 필요한 Service만 주입받아 사용

---

### 3. Singleton 패턴 제거

#### 📌 문제점
```dart
// 현재: 많은 Service 클래스들
class PhotoService {
  static final PhotoService _instance = PhotoService._internal();
  factory PhotoService() => _instance;
  PhotoService._internal();

  // ...
}

class CategoryService {
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;
  CategoryService._internal();

  // ...
}
```

**문제**:
- 테스트 어려움: 매번 동일한 인스턴스 사용
- Mock 객체 주입 불가능
- 생명주기 관리 어려움
- 순환 의존성 발생 위험

#### ✅ 해결 방안

**Step 1: Singleton 제거 및 일반 클래스로 변경**

```dart
// lib/services/photo_service.dart
class PhotoService {
  final IPhotoRepository _photoRepository;
  final IAudioRepository _audioRepository;
  final ICategoryService _categoryService;
  final INotificationService _notificationService;

  // Singleton 제거, 의존성 주입으로 변경
  PhotoService({
    required IPhotoRepository photoRepository,
    required IAudioRepository audioRepository,
    required ICategoryService categoryService,
    required INotificationService notificationService,
  })  : _photoRepository = photoRepository,
        _audioRepository = audioRepository,
        _categoryService = categoryService,
        _notificationService = notificationService;

  // 기존 메서드들
}
```

**Step 2: Provider로 생명주기 관리**

```dart
// lib/main.dart
void main() {
  runApp(
    MultiProvider(
      providers: [
        // Repositories (앱 전체에서 단일 인스턴스)
        Provider<IPhotoRepository>(
          create: (_) => PhotoRepository(),
        ),

        // Services (앱 전체에서 단일 인스턴스)
        Provider<PhotoService>(
          create: (context) => PhotoService(
            photoRepository: context.read<IPhotoRepository>(),
            audioRepository: context.read<IAudioRepository>(),
            categoryService: context.read<ICategoryService>(),
            notificationService: context.read<INotificationService>(),
          ),
        ),

        // Controllers (화면별 또는 기능별로 생명주기 관리)
        ChangeNotifierProvider<PhotoController>(
          create: (context) => PhotoController(
            photoService: context.read<PhotoService>(),
          ),
        ),
      ],
      child: MyApp(),
    ),
  );
}
```

**Step 3: 테스트 시 Mock 객체 주입**

```dart
// test/services/photo_service_test.dart
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockPhotoRepository extends Mock implements IPhotoRepository {}
class MockAudioRepository extends Mock implements IAudioRepository {}

void main() {
  late PhotoService photoService;
  late MockPhotoRepository mockPhotoRepository;
  late MockAudioRepository mockAudioRepository;

  setUp(() {
    mockPhotoRepository = MockPhotoRepository();
    mockAudioRepository = MockAudioRepository();

    // Mock 객체를 주입하여 테스트
    photoService = PhotoService(
      photoRepository: mockPhotoRepository,
      audioRepository: mockAudioRepository,
      categoryService: MockCategoryService(),
      notificationService: MockNotificationService(),
    );
  });

  test('사진 업로드 성공 시 photoId 반환', () async {
    // Given
    when(mockPhotoRepository.uploadImageToStorage(
      imageFile: any,
      categoryId: any,
      userId: any,
    )).thenAnswer((_) async => 'https://example.com/image.jpg');

    // When
    final result = await photoService.uploadPhoto(...);

    // Then
    expect(result.isSuccess, true);
    expect(result.photoId, isNotEmpty);
  });
}
```

#### 📊 효과
- ✅ 테스트 용이성: Mock 객체 자유롭게 주입
- ✅ 생명주기 관리: Provider가 자동으로 관리
- ✅ 순환 의존성 해결: 명확한 의존성 그래프
- ✅ 유연성: 상황에 따라 다른 구현체 주입 가능

---

## 🟡 Medium Priority - 점진적 개선

### 4. AudioController 분리

#### 📌 문제점
```dart
// 현재: lib/controllers/audio_controller.dart
class AudioController extends ChangeNotifier {
  // 56개 메서드!

  // 녹음 관련 (15개)
  Future<void> startRecording() {}
  Future<void> stopRecording() {}
  Future<void> pauseRecording() {}
  // ...

  // 재생 관련 (12개)
  Future<void> playAudioFromUrl() {}
  Future<void> pauseRealtimeAudio() {}
  Future<void> stopRealtimeAudio() {}
  // ...

  // 업로드 관련 (8개)
  Future<void> uploadAudio() {}
  // ...

  // 파형 데이터 (10개)
  // ...
}
```

#### ✅ 해결 방안

```dart
// lib/controllers/audio/recording_controller.dart
class RecordingController extends ChangeNotifier {
  final IAudioService _audioService;

  bool _isRecording = false;
  String? _currentRecordingPath;
  Duration _recordingDuration = Duration.zero;

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;
  Duration get recordingDuration => _recordingDuration;

  RecordingController({required IAudioService audioService})
      : _audioService = audioService;

  Future<void> startRecording() async {
    // 녹음 시작
    final path = await _audioService.startRecording();
    _currentRecordingPath = path;
    _isRecording = true;
    notifyListeners();
  }

  Future<void> stopRecording() async {
    await _audioService.stopRecording();
    _isRecording = false;
    notifyListeners();
  }

  Future<void> pauseRecording() async {
    // 일시정지 로직
  }

  Future<void> resumeRecording() async {
    // 재개 로직
  }
}
```

```dart
// lib/controllers/audio/playback_controller.dart
class PlaybackController extends ChangeNotifier {
  final IAudioService _audioService;

  bool _isPlaying = false;
  String? _currentAudioUrl;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  PlaybackController({required IAudioService audioService})
      : _audioService = audioService;

  Future<void> play(String audioUrl) async {
    await _audioService.playAudio(audioUrl);
    _currentAudioUrl = audioUrl;
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> pause() async {
    await _audioService.pauseAudio();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> stop() async {
    await _audioService.stopAudio();
    _isPlaying = false;
    _currentAudioUrl = null;
    notifyListeners();
  }

  void seekTo(Duration position) {
    _position = position;
    notifyListeners();
  }
}
```

---

### 5. FriendRepository 도메인 분리

```dart
// lib/repositories/friend/friend_repository.dart
class FriendRepository implements IFriendRepository {
  // 기본 CRUD만
  Future<List<FriendModel>> getFriendsList(String userId) async {}
  Future<void> addFriend(...) async {}
  Future<void> removeFriend(...) async {}
}

// lib/repositories/friend/friend_block_repository.dart
class FriendBlockRepository implements IFriendBlockRepository {
  Future<void> blockFriend(...) async {}
  Future<void> unblockFriend(...) async {}
  Future<List<String>> getBlockedUsers(String userId) async {}
}

// lib/repositories/friend/friend_search_repository.dart
class FriendSearchRepository implements IFriendSearchRepository {
  Future<List<FriendModel>> searchFriends(String query) async {}
}
```

---

## 🟢 Low Priority - 선택적 개선

### 6. Result 패턴 도입

```dart
// lib/core/result.dart
class Result<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  Result._({this.data, this.error, required this.isSuccess});

  factory Result.success(T data) {
    return Result._(data: data, isSuccess: true);
  }

  factory Result.failure(String error) {
    return Result._(error: error, isSuccess: false);
  }

  // 편의 메서드
  R when<R>({
    required R Function(T data) success,
    required R Function(String error) failure,
  }) {
    if (isSuccess && data != null) {
      return success(data as T);
    } else {
      return failure(error ?? 'Unknown error');
    }
  }
}
```

```dart
// 사용 예시
Future<Result<PhotoDataModel>> uploadPhoto(...) async {
  try {
    final photo = await _repository.uploadPhoto(...);
    return Result.success(photo);
  } catch (e) {
    return Result.failure(e.toString());
  }
}

// UI에서 사용
final result = await photoService.uploadPhoto(...);
result.when(
  success: (photo) {
    // 성공 처리
    showSnackBar('사진 업로드 완료');
  },
  failure: (error) {
    // 실패 처리
    showErrorDialog(error);
  },
);
```

---

## 🚀 마이그레이션 전략

### Phase 1: 기반 작업 (1-2주)
1. ✅ 인터페이스 정의 (모든 Repository, Service)
2. ✅ Provider 설정
3. ✅ 기존 코드에 인터페이스 구현

### Phase 2: 핵심 개선 (2-3주)
4. ✅ CategoryService 분리
5. ✅ Singleton 제거
6. ✅ 테스트 작성

### Phase 3: 점진적 개선 (2-3주)
7. ✅ AudioController 분리
8. ✅ FriendRepository 분리
9. ✅ 문서화

### Phase 4: 고급 기능 (선택)
10. ✅ Result 패턴 도입
11. ✅ 통합 테스트
12. ✅ CI/CD 설정

---

## 📊 예상 효과

| 개선 항목 | 테스트 용이성 | 유지보수성 | 확장성 | 결합도 | 개발 시간 |
|-----------|---------------|-----------|--------|--------|-----------|
| 인터페이스 도입 | ⬆️⬆️⬆️ | ⬆️⬆️ | ⬆️⬆️⬆️ | ⬇️⬇️⬇️ | 2주 |
| CategoryService 분리 | ⬆️⬆️ | ⬆️⬆️⬆️ | ⬆️⬆️ | ⬇️⬇️ | 1주 |
| Singleton 제거 | ⬆️⬆️⬆️ | ⬆️⬆️ | ⬆️ | ⬇️⬇️⬇️ | 1주 |
| Controller 분리 | ⬆️ | ⬆️⬆️⬆️ | ⬆️⬆️ | ⬇️⬇️ | 1주 |
| Repository 분리 | ⬆️⬆️ | ⬆️⬆️ | ⬆️⬆️ | ⬇️⬇️ | 1주 |

**총 예상 시간**: 6-8주
**예상 효과**: 코드 품질 ⭐⭐⭐ → ⭐⭐⭐⭐⭐

---

## 🎯 체크리스트

### High Priority
- [ ] IPhotoRepository 인터페이스 생성
- [ ] IAudioRepository 인터페이스 생성
- [ ] ICategoryRepository 인터페이스 생성
- [ ] IFriendRepository 인터페이스 생성
- [ ] ICommentRecordRepository 인터페이스 생성
- [ ] IEmojiReactionRepository 인터페이스 생성
- [ ] Provider 설정
- [ ] CategoryService 5개로 분리
- [ ] Singleton 패턴 제거 (모든 Service)

### Medium Priority
- [ ] AudioController 4개로 분리
- [ ] FriendRepository 3개로 분리
- [ ] 단위 테스트 작성

### Low Priority
- [ ] Result 패턴 도입
- [ ] 통합 테스트 작성
- [ ] API 문서화

---

## 📚 참고 자료

- [Provider 패턴 공식 문서](https://pub.dev/packages/provider)
- [Dependency Injection in Flutter](https://flutter.dev/docs/development/data-and-backend/state-mgmt/options#provider)
- [Clean Architecture in Flutter](https://resocoder.com/category/tutorials/flutter/clean-architecture/)
- [SOLID Principles](https://refactoring.guru/design-patterns/solid-principles)

---

**작성자**: Claude Code with Serena MCP
**마지막 업데이트**: 2025-10-16
