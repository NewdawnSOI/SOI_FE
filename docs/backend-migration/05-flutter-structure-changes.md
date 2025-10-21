# Flutter 프로젝트 구조 변경 가이드

Firebase 기반에서 REST API 기반으로 전환하면서 Flutter 프로젝트 구조가 어떻게 변경되는지 설명합니다.

## 📂 1. 전체 구조 비교

### 이전 (Firebase)

```
lib/
├── main.dart                    # Firebase 초기화
├── controllers/                 # 15 files - Stream 기반
│   ├── auth_controller.dart
│   ├── category_controller.dart
│   ├── friend_controller.dart
│   └── ...
├── services/                    # 17 files - 복잡한 비즈니스 로직
│   ├── auth_service.dart
│   ├── category_service.dart
│   ├── category_member_service.dart
│   ├── friend_check_service.dart
│   └── ...
├── repositories/                # 12 files - Firebase 직접 호출
│   ├── auth_repository.dart
│   ├── category_repository.dart
│   ├── friend_repository.dart
│   └── ...
├── models/                      # 13 files - 데이터 모델
│   ├── user.dart
│   ├── category.dart
│   └── ...
├── views/                       # 화면
├── widgets/                     # 재사용 위젯
└── utils/                       # 유틸리티
```

### 이후 (Spring Boot + REST API)

```
lib/
├── main.dart                    # ✅ API 클라이언트 DI
├── config/                      # ✅ 신규
│   ├── environment.dart         # 환경 설정
│   └── api_config.dart          # Dio 설정
├── api/                         # ✅ 신규
│   └── generated/               # OpenAPI Generator 출력
│       ├── lib/
│       │   ├── api.dart
│       │   ├── api/
│       │   │   ├── category_api.dart
│       │   │   ├── photo_api.dart
│       │   │   └── ...
│       │   └── model/
│       │       ├── category_dto.dart
│       │       ├── photo_dto.dart
│       │       └── ...
│       └── pubspec.yaml
├── controllers/                 # 15 files - ✏️ Future 기반으로 변경
│   ├── auth_controller.dart
│   ├── category_controller.dart
│   └── ...
├── services/                    # ✏️ 대부분 삭제 또는 단순화
│   ├── category_service.dart   # 간단한 래퍼만
│   └── ...
├── repositories/                # 12 files - ✏️ API 호출로 변경
│   ├── category_repository.dart
│   └── ...
├── models/                      # ⚠️ api/generated로 대체
├── views/                       # 화면 (변경 없음)
├── widgets/                     # 재사용 위젯 (변경 없음)
└── utils/                       # 유틸리티 (변경 없음)
```

**주요 변경사항:**

- ✅ `config/` 폴더 추가 (환경 설정)
- ✅ `api/generated/` 추가 (자동 생성 코드)
- ✏️ `controllers/` Stream → Future
- ✏️ `services/` 대부분 삭제
- ✏️ `repositories/` Firebase → API
- ⚠️ `models/` 자동 생성으로 대체

---

## 📁 2. 파일별 상세 변경

### 2.1. main.dart

#### 이전 (Firebase)

```dart
// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        // ❌ 직접 인스턴스 생성
        Provider(create: (_) => AuthRepository()),
        Provider(create: (_) => CategoryRepository()),

        ChangeNotifierProvider(
          create: (context) => AuthController(
            context.read<AuthRepository>(),
          ),
        ),
        // ... 15개 이상의 Provider
      ],
      child: MyApp(),
    ),
  );
}
```

#### 이후 (API)

```dart
// lib/main.dart
import 'config/environment.dart';
import 'config/api_config.dart';
import 'package:soi_api/api.dart';  // ✅ 자동 생성

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 환경 설정
  const envString = String.fromEnvironment('ENV', defaultValue: 'dev');
  final environment = Environment.values.firstWhere(
    (e) => e.name == envString,
    orElse: () => Environment.dev,
  );
  EnvironmentConfig.setEnvironment(environment);

  debugPrint('🚀 Environment: ${environment.name}');
  debugPrint('📡 API URL: ${EnvironmentConfig.apiBaseUrl}');

  // ✅ Dio 클라이언트 생성
  final dio = ApiConfig.createDio();

  runApp(
    MultiProvider(
      providers: [
        // ✅ API 클라이언트들
        Provider<CategoryApi>(
          create: (_) => CategoryApi(dio),
        ),
        Provider<PhotoApi>(
          create: (_) => PhotoApi(dio),
        ),
        Provider<FriendApi>(
          create: (_) => FriendApi(dio),
        ),

        // ✅ Repository들
        Provider<CategoryRepository>(
          create: (context) => CategoryRepository(
            context.read<CategoryApi>(),
          ),
        ),

        // ✅ Controller들
        ChangeNotifierProvider<CategoryController>(
          create: (context) => CategoryController(
            context.read<CategoryRepository>(),
          ),
        ),
        // ...
      ],
      child: MyApp(),
    ),
  );
}
```

---

### 2.2. Controllers

#### 이전 (Stream 기반)

```dart
// lib/controllers/category_controller.dart
class CategoryController extends ChangeNotifier {
  final CategoryRepository _repository;

  List<Category> _categories = [];
  List<Category> get categories => _categories;

  StreamSubscription? _subscription;

  CategoryController(this._repository) {
    _initStream();
  }

  // ❌ Stream 기반
  void _initStream() {
    _subscription = _repository.streamUserCategories().listen((categories) {
      _categories = categories;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

#### 이후 (Future + 캐시)

```dart
// lib/controllers/category_controller.dart
class CategoryController extends ChangeNotifier {
  final CategoryRepository _repository;

  List<CategoryDTO> _categories = [];
  List<CategoryDTO> get categories => _categories;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  DateTime? _lastFetchTime;

  CategoryController(this._repository);

  // ✅ Future 기반 + 캐싱
  Future<void> loadCategories({bool forceReload = false}) async {
    // 캐시 유효성 확인
    if (!forceReload && _lastFetchTime != null) {
      final diff = DateTime.now().difference(_lastFetchTime!);
      if (diff.inSeconds < 30) {  // 30초 캐시
        return;
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      _categories = await _repository.getUserCategories();
      _lastFetchTime = DateTime.now();
    } catch (e) {
      debugPrint('❌ Load categories error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ 수동 새로고침
  Future<void> refresh() async {
    await loadCategories(forceReload: true);
  }

  @override
  void dispose() {
    _categories.clear();
    super.dispose();
  }
}
```

---

### 2.3. Services

#### 이전 (복잡한 비즈니스 로직)

```dart
// lib/services/category_member_service.dart
class CategoryMemberService {
  final CategoryRepository _categoryRepository;
  final FriendRepository _friendRepository;
  final InviteRepository _inviteRepository;

  // ❌ 150줄의 복잡한 로직
  Future<void> addMember({
    required String categoryId,
    required String currentUserId,
    required String targetUserId,
  }) async {
    // 친구 확인
    final friends = await _friendRepository.getFriends(currentUserId);
    if (!friends.any((f) => f.id == targetUserId)) {
      throw Exception('친구가 아닙니다');
    }

    // 차단 확인
    final blocked = await _friendRepository.getBlockedUsers(currentUserId);
    if (blocked.any((u) => u.id == targetUserId)) {
      throw Exception('차단된 사용자입니다');
    }

    // 이미 멤버인지 확인
    final category = await _categoryRepository.getCategory(categoryId);
    if (category.mates.contains(targetUserId)) {
      throw Exception('이미 멤버입니다');
    }

    // ... 더 많은 로직
  }
}
```

#### 이후 (삭제 또는 단순화)

```dart
// lib/services/category_service.dart (대부분 삭제됨)

// ⚠️ 대부분의 Service 파일은 삭제하고,
// Repository에서 직접 API를 호출합니다.

// 필요한 경우 간단한 래퍼만 유지:
class CategoryService {
  final CategoryRepository _repository;

  CategoryService(this._repository);

  // ✅ 단순 래퍼 (선택적)
  Future<List<CategoryDTO>> getUserCategories() {
    return _repository.getUserCategories();
  }
}
```

---

### 2.4. Repositories

#### 이전 (Firebase 직접 호출)

```dart
// lib/repositories/category_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ❌ Firebase 직접 호출
  Stream<List<Category>> streamUserCategories(String userId) {
    return _firestore
        .collection('categories')
        .where('mates', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Category.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<void> addMember(String categoryId, String userId) async {
    await _firestore.collection('categories').doc(categoryId).update({
      'mates': FieldValue.arrayUnion([userId]),
    });
  }
}
```

#### 이후 (API 호출)

```dart
// lib/repositories/category_repository.dart
import 'package:soi_api/api.dart';  // ✅ 자동 생성
import 'package:dio/dio.dart';

class CategoryRepository {
  final CategoryApi _api;  // ✅ 자동 생성된 API 클라이언트

  CategoryRepository(this._api);

  // ✅ API 호출
  Future<List<CategoryDTO>> getUserCategories() async {
    try {
      final response = await _api.getCategories();
      return response.data?.data ?? [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

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
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    // 에러 처리
    final errorCode = e.response?.data?['error']?['code'];
    switch (errorCode) {
      case 'FRIEND_NOT_FOUND':
        return Exception('친구를 먼저 추가해주세요');
      case 'CATEGORY_FULL':
        return Exception('카테고리 인원이 가득 찼습니다');
      default:
        return Exception(e.message ?? '알 수 없는 오류');
    }
  }
}
```

---

### 2.5. Models

#### 이전 (수동 작성)

```dart
// lib/models/category.dart
class Category {
  final String id;
  final String name;
  final List<String> mates;
  final String? categoryPhotoUrl;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    required this.mates,
    this.categoryPhotoUrl,
    required this.createdAt,
  });

  // ❌ 수동으로 fromJson 작성
  factory Category.fromFirestore(Map<String, dynamic> data, String id) {
    return Category(
      id: id,
      name: data['name'] as String,
      mates: List<String>.from(data['mates'] ?? []),
      categoryPhotoUrl: data['categoryPhotoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
```

#### 이후 (자동 생성)

```dart
// lib/api/generated/lib/model/category_dto.dart (자동 생성됨!)
class CategoryDTO {
  final String id;
  final String name;
  final List<CategoryMemberDTO> mates;
  final String? categoryPhotoUrl;
  final DateTime createdAt;

  CategoryDTO({
    required this.id,
    required this.name,
    required this.mates,
    this.categoryPhotoUrl,
    required this.createdAt,
  });

  // ✅ 자동 생성된 fromJson, toJson
  factory CategoryDTO.fromJson(Map<String, dynamic> json) => _$CategoryDTOFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryDTOToJson(this);
}

// ⚠️ lib/models/category.dart 파일은 삭제
```

---

## 📊 3. 파일 수 변화

| 폴더             | 이전 (Firebase) | 이후 (API) | 변화                |
| ---------------- | --------------- | ---------- | ------------------- |
| `config/`        | 0               | 2          | ✅ 신규             |
| `api/generated/` | 0               | 자동 생성  | ✅ 신규             |
| `controllers/`   | 15              | 15         | ✏️ 수정             |
| `services/`      | 17              | ~3         | ❌ 대부분 삭제      |
| `repositories/`  | 12              | 12         | ✏️ 수정             |
| `models/`        | 13              | 0          | ❌ 삭제 (자동 생성) |
| `views/`         | -               | -          | 변경 없음           |
| `widgets/`       | -               | -          | 변경 없음           |

**총 파일 수:**

- **이전:** ~60개 (수동 작성)
- **이후:** ~35개 (수동) + 자동 생성

---

## 🔧 4. pubspec.yaml 변경

#### 이전

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter

  # Firebase
  firebase_core: ^2.24.0
  firebase_auth: ^4.15.0
  cloud_firestore: ^4.13.0
  firebase_storage: ^11.5.0

  # 상태 관리
  provider: ^6.1.1
```

#### 이후

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter

  # ✅ HTTP 클라이언트
  dio: ^5.4.0

  # ✅ 자동 생성 API 클라이언트
  soi_api:
    path: lib/api/generated

  # 상태 관리 (동일)
  provider: ^6.1.1

  # ✅ 로컬 저장소
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0

  # UI (동일)
  google_fonts: ^6.1.0
  flutter_screenutil: ^5.9.0

# ✅ 개발 의존성 추가
dev_dependencies:
  flutter_test:
    sdk: flutter

  # 코드 생성
  build_runner: ^2.4.6
  json_serializable: ^6.7.1
```

---

## 🚀 5. 마이그레이션 단계별 체크리스트

### Phase 1: 기본 설정

- [ ] `config/environment.dart` 생성
- [ ] `config/api_config.dart` 생성
- [ ] `main.dart` 수정 (환경 설정 + Dio 초기화)
- [ ] `.vscode/launch.json` 생성
- [ ] `pubspec.yaml` 업데이트
- [ ] `Makefile` 생성

### Phase 2: API 클라이언트 생성

- [ ] OpenAPI Generator 설치
- [ ] `make generate-api` 실행
- [ ] `lib/api/generated/` 폴더 확인
- [ ] `.gitignore`에 `lib/api/generated/` 추가

### Phase 3: Category 도메인 마이그레이션

- [ ] `CategoryRepository` 수정 (Firebase → API)
- [ ] `CategoryController` 수정 (Stream → Future)
- [ ] `category_service.dart` 삭제 또는 단순화
- [ ] `models/category.dart` 삭제
- [ ] UI 테스트

### Phase 4: 다른 도메인 반복

- [ ] Photo 도메인
- [ ] Friend 도메인
- [ ] Comment 도메인
- [ ] ... (15개 도메인)

### Phase 5: 정리

- [ ] 사용하지 않는 Firebase 패키지 제거
- [ ] 사용하지 않는 Service 파일 삭제
- [ ] 사용하지 않는 Model 파일 삭제
- [ ] 전체 테스트

---

## 📋 6. 도메인별 마이그레이션 우선순위

### 1순위 (핵심 기능)

1. **Auth** - 인증/로그인
2. **Category** - 카테고리 관리
3. **Photo** - 사진 업로드/조회
4. **Friend** - 친구 관리

### 2순위 (주요 기능)

5. **Comment** - 댓글
6. **Invite** - 초대
7. **Notification** - 알림

### 3순위 (부가 기능)

8. **User Profile** - 프로필 관리
9. **Settings** - 설정
10. **Block** - 차단

**추천 순서:**

1. Auth 먼저 (모든 API가 인증 필요)
2. Category 다음 (메인 화면)
3. Photo (사진 업로드)
4. 나머지 순차적으로

---

## 🎯 7. 실전 예시: Category 마이그레이션

### Before

```
lib/
├── controllers/
│   └── category_controller.dart        (Stream, 100줄)
├── services/
│   ├── category_service.dart           (복잡한 로직, 200줄)
│   └── category_member_service.dart    (멤버 관리, 150줄)
├── repositories/
│   └── category_repository.dart        (Firebase, 120줄)
└── models/
    └── category.dart                   (모델, 50줄)
```

### After

```
lib/
├── config/
│   ├── environment.dart                ✅ 신규
│   └── api_config.dart                 ✅ 신규
├── api/
│   └── generated/
│       └── lib/
│           ├── api/
│           │   └── category_api.dart   ✅ 자동 생성
│           └── model/
│               └── category_dto.dart   ✅ 자동 생성
├── controllers/
│   └── category_controller.dart        ✏️ Future, 80줄
├── services/
│   └── (삭제됨)                        ❌
├── repositories/
│   └── category_repository.dart        ✏️ API 호출, 60줄
└── models/
    └── (삭제됨)                        ❌ 자동 생성으로 대체
```

**결과:**

- **수동 코드:** 620줄 → 140줄 (77% 감소)
- **파일 수:** 5개 → 2개 + 자동 생성
- **복잡도:** 높음 → 낮음

---

## 📝 다음 단계

프로젝트 구조 변경을 이해했다면:

👉 **[3. 아키텍처 비교로 이동](./03-architecture-comparison.md)** - Firebase vs Spring Boot 상세 비교
👉 **[README로 돌아가기](./README.md)** - 전체 가이드 확인
