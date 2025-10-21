# 개발 워크플로우 실전 시나리오

백엔드와 프론트엔드가 협업하는 실제 개발 시나리오를 단계별로 설명합니다.

## 🎬 시나리오 1: 새로운 API 추가

### 상황

"사진 좋아요 기능"을 추가해야 합니다.

### 백엔드 개발자 작업

#### Step 1: Entity 추가

```java
// src/main/java/com/soi/domain/PhotoLike.java
@Entity
@Table(name = "photo_likes")
@Getter
@NoArgsConstructor
public class PhotoLike {
    @Id
    private String id;

    @Column(nullable = false)
    private String photoId;

    @Column(nullable = false)
    private String userId;

    @Column(nullable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        if (id == null) {
            id = UUID.randomUUID().toString();
        }
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
    }
}
```

#### Step 2: DTO 생성

```java
// src/main/java/com/soi/dto/photo/PhotoLikeResponse.java
@Getter
@Builder
public class PhotoLikeResponse {
    private String photoId;
    private int likeCount;
    private boolean isLikedByMe;
    private List<String> recentLikerNames;  // 최근 3명
}
```

#### Step 3: Repository 추가

```java
// src/main/java/com/soi/repository/PhotoLikeRepository.java
public interface PhotoLikeRepository extends JpaRepository<PhotoLike, String> {

    @Query("SELECT pl FROM PhotoLike pl WHERE pl.photoId = :photoId AND pl.userId = :userId")
    Optional<PhotoLike> findByPhotoIdAndUserId(
        @Param("photoId") String photoId,
        @Param("userId") String userId
    );

    @Query("SELECT COUNT(pl) FROM PhotoLike pl WHERE pl.photoId = :photoId")
    int countByPhotoId(@Param("photoId") String photoId);

    @Query("SELECT pl FROM PhotoLike pl WHERE pl.photoId = :photoId ORDER BY pl.createdAt DESC")
    List<PhotoLike> findRecentByPhotoId(@Param("photoId") String photoId, Pageable pageable);
}
```

#### Step 4: Service 비즈니스 로직

```java
// src/main/java/com/soi/service/PhotoLikeService.java
@Service
@RequiredArgsConstructor
@Slf4j
public class PhotoLikeService {

    private final PhotoLikeRepository likeRepository;
    private final PhotoRepository photoRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;

    @Transactional
    public PhotoLikeResponse toggleLike(String photoId, String userId) {
        // 1. 사진 존재 확인
        Photo photo = photoRepository.findById(photoId)
            .orElseThrow(() -> new NotFoundException("Photo not found"));

        // 2. 기존 좋아요 확인
        Optional<PhotoLike> existingLike = likeRepository
            .findByPhotoIdAndUserId(photoId, userId);

        if (existingLike.isPresent()) {
            // 좋아요 취소
            likeRepository.delete(existingLike.get());
            log.info("User {} unliked photo {}", userId, photoId);
        } else {
            // 좋아요 추가
            PhotoLike newLike = PhotoLike.builder()
                .photoId(photoId)
                .userId(userId)
                .build();
            likeRepository.save(newLike);

            // 알림 전송 (비동기)
            if (!photo.getUploaderId().equals(userId)) {
                notificationService.sendLikeNotification(photo, userId);
            }

            log.info("User {} liked photo {}", userId, photoId);
        }

        // 3. 응답 생성
        return buildPhotoLikeResponse(photoId, userId);
    }

    @Transactional(readOnly = true)
    public PhotoLikeResponse getPhotoLikes(String photoId, String currentUserId) {
        return buildPhotoLikeResponse(photoId, currentUserId);
    }

    private PhotoLikeResponse buildPhotoLikeResponse(String photoId, String userId) {
        int likeCount = likeRepository.countByPhotoId(photoId);
        boolean isLiked = likeRepository.findByPhotoIdAndUserId(photoId, userId).isPresent();

        List<PhotoLike> recentLikes = likeRepository
            .findRecentByPhotoId(photoId, PageRequest.of(0, 3));

        List<String> recentLikerNames = recentLikes.stream()
            .map(like -> userRepository.findById(like.getUserId())
                .map(User::getName)
                .orElse("Unknown"))
            .collect(Collectors.toList());

        return PhotoLikeResponse.builder()
            .photoId(photoId)
            .likeCount(likeCount)
            .isLikedByMe(isLiked)
            .recentLikerNames(recentLikerNames)
            .build();
    }
}
```

#### Step 5: Controller + OpenAPI 애노테이션

```java
// src/main/java/com/soi/controller/PhotoLikeController.java
@RestController
@RequestMapping("/api/v1/photos/{photoId}/likes")
@RequiredArgsConstructor
@Tag(name = "PhotoLike", description = "사진 좋아요 API")
public class PhotoLikeController {

    private final PhotoLikeService likeService;

    @Operation(
        summary = "좋아요 토글",
        description = "사진 좋아요를 추가하거나 취소합니다. 이미 좋아요를 눌렀다면 취소되고, 아니면 추가됩니다."
    )
    @ApiResponses({
        @ApiResponse(
            responseCode = "200",
            description = "성공",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = PhotoLikeResponse.class),
                examples = @ExampleObject(
                    name = "좋아요 추가 성공",
                    value = "{\"photoId\":\"photo123\",\"likeCount\":5,\"isLikedByMe\":true,\"recentLikerNames\":[\"Alice\",\"Bob\",\"Charlie\"]}"
                )
            )
        ),
        @ApiResponse(responseCode = "404", description = "사진을 찾을 수 없음")
    })
    @PostMapping
    public ResponseEntity<ApiResponse<PhotoLikeResponse>> toggleLike(
        @Parameter(description = "사진 ID", required = true, example = "photo123")
        @PathVariable String photoId,
        @Parameter(hidden = true) @AuthenticationPrincipal String userId
    ) {
        PhotoLikeResponse response = likeService.toggleLike(photoId, userId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @Operation(
        summary = "좋아요 정보 조회",
        description = "사진의 좋아요 수와 최근 좋아요를 누른 사용자 목록을 조회합니다"
    )
    @GetMapping
    public ResponseEntity<ApiResponse<PhotoLikeResponse>> getPhotoLikes(
        @PathVariable String photoId,
        @Parameter(hidden = true) @AuthenticationPrincipal String userId
    ) {
        PhotoLikeResponse response = likeService.getPhotoLikes(photoId, userId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}
```

#### Step 6: 테스트 및 배포

```bash
# 1. 로컬 테스트
./mvnw test
curl -X POST http://localhost:8080/api/v1/photos/photo123/likes \
  -H "Authorization: Bearer $TOKEN"

# 2. OpenAPI 스펙 확인
open http://localhost:8080/swagger-ui.html

# 3. Dev 서버 배포
git add .
git commit -m "feat: Add photo like feature"
git push origin main

# 4. CI/CD 자동 배포 (GitHub Actions)
# → https://dev-api.soi.app 에 배포됨
```

#### Step 7: 프론트엔드에 알림

```
✅ Photo Like API 배포 완료

**Endpoints:**
- POST /api/v1/photos/{photoId}/likes - 좋아요 토글
- GET /api/v1/photos/{photoId}/likes - 좋아요 정보 조회

**OpenAPI Spec:**
https://dev-api.soi.app/v3/api-docs.yaml

**Swagger UI:**
https://dev-api.soi.app/swagger-ui.html

좋아요 기능 API 사용 가능합니다!
```

---

### 프론트엔드 개발자 작업 (당신)

#### Step 1: API 클라이언트 재생성

```bash
# OpenAPI 스펙 다운로드 및 Flutter 클라이언트 생성
make update-api

# 출력:
# 📥 Downloading OpenAPI spec from dev server...
# ✅ OpenAPI spec downloaded
# 🔧 Generating Dart/Dio client...
# ✅ Client generated at lib/api/generated
# 📦 Installing dependencies...
# ✅ Dependencies installed
```

#### Step 2: 생성된 코드 확인

```dart
// lib/api/generated/lib/api/photo_like_api.dart (자동 생성됨!)
class PhotoLikeApi {
  /// 좋아요 토글
  Future<Response<ApiResponsePhotoLikeResponse>> toggleLike({
    required String photoId,
    CancelToken? cancelToken,
  }) async {
    final path = '/api/v1/photos/$photoId/likes';
    return await _dio.post<Object>(path, cancelToken: cancelToken);
  }

  /// 좋아요 정보 조회
  Future<Response<ApiResponsePhotoLikeResponse>> getPhotoLikes({
    required String photoId,
    CancelToken? cancelToken,
  }) async {
    final path = '/api/v1/photos/$photoId/likes';
    return await _dio.get<Object>(path, cancelToken: cancelToken);
  }
}

// lib/api/generated/lib/model/photo_like_response.dart (자동 생성됨!)
class PhotoLikeResponse {
  final String photoId;
  final int likeCount;
  final bool isLikedByMe;
  final List<String> recentLikerNames;

  PhotoLikeResponse({
    required this.photoId,
    required this.likeCount,
    required this.isLikedByMe,
    required this.recentLikerNames,
  });
}
```

#### Step 3: Repository 추가

```dart
// lib/repositories/photo_like_repository.dart (신규 생성)
import 'package:soi_api/api.dart';
import 'package:dio/dio.dart';

class PhotoLikeRepository {
  final PhotoLikeApi _api;

  PhotoLikeRepository(this._api);

  /// 좋아요 토글
  Future<PhotoLikeResponse> toggleLike(String photoId) async {
    try {
      final response = await _api.toggleLike(photoId: photoId);
      return response.data!.data!;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 좋아요 정보 조회
  Future<PhotoLikeResponse> getPhotoLikes(String photoId) async {
    try {
      final response = await _api.getPhotoLikes(photoId: photoId);
      return response.data!.data!;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    if (e.response?.statusCode == 404) {
      return Exception('사진을 찾을 수 없습니다');
    }
    return Exception(e.message);
  }
}
```

#### Step 4: Controller 추가

```dart
// lib/controllers/photo_like_controller.dart (신규 생성)
import 'package:flutter/foundation.dart';
import '../repositories/photo_like_repository.dart';
import 'package:soi_api/api.dart';

class PhotoLikeController extends ChangeNotifier {
  final PhotoLikeRepository _repository;

  // 캐시: photoId -> PhotoLikeResponse
  final Map<String, PhotoLikeResponse> _likesCache = {};

  // 로딩 상태
  final Set<String> _loadingPhotoIds = {};

  PhotoLikeController(this._repository);

  /// 좋아요 정보 가져오기
  PhotoLikeResponse? getLikes(String photoId) => _likesCache[photoId];

  bool isLoading(String photoId) => _loadingPhotoIds.contains(photoId);

  /// 좋아요 토글
  Future<void> toggleLike(String photoId) async {
    if (_loadingPhotoIds.contains(photoId)) return;

    _loadingPhotoIds.add(photoId);
    notifyListeners();

    try {
      final response = await _repository.toggleLike(photoId);
      _likesCache[photoId] = response;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Toggle like error: $e');
      rethrow;
    } finally {
      _loadingPhotoIds.remove(photoId);
      notifyListeners();
    }
  }

  /// 좋아요 정보 로드
  Future<void> loadLikes(String photoId) async {
    try {
      final response = await _repository.getPhotoLikes(photoId);
      _likesCache[photoId] = response;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Load likes error: $e');
    }
  }

  /// 여러 사진의 좋아요 정보 일괄 로드
  Future<void> loadMultipleLikes(List<String> photoIds) async {
    await Future.wait(
      photoIds.map((id) => loadLikes(id))
    );
  }

  @override
  void dispose() {
    _likesCache.clear();
    _loadingPhotoIds.clear();
    super.dispose();
  }
}
```

#### Step 5: main.dart에 DI 추가

```dart
// lib/main.dart
void main() async {
  // ...

  runApp(
    MultiProvider(
      providers: [
        // 기존 Providers...

        // PhotoLike API 추가
        Provider<PhotoLikeApi>(
          create: (_) => PhotoLikeApi(apiClient.dio),
        ),

        Provider<PhotoLikeRepository>(
          create: (context) => PhotoLikeRepository(
            context.read<PhotoLikeApi>(),
          ),
        ),

        ChangeNotifierProvider<PhotoLikeController>(
          create: (context) => PhotoLikeController(
            context.read<PhotoLikeRepository>(),
          ),
        ),
      ],
      child: MyApp(),
    ),
  );
}
```

#### Step 6: UI 구현

```dart
// lib/widgets/photo_like_button.dart (신규 생성)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/photo_like_controller.dart';

class PhotoLikeButton extends StatelessWidget {
  final String photoId;

  const PhotoLikeButton({
    Key? key,
    required this.photoId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoLikeController>(
      builder: (context, controller, child) {
        final likes = controller.getLikes(photoId);
        final isLoading = controller.isLoading(photoId);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 좋아요 버튼
            IconButton(
              icon: Icon(
                likes?.isLikedByMe == true
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: likes?.isLikedByMe == true
                    ? Colors.red
                    : Colors.grey,
              ),
              onPressed: isLoading
                  ? null
                  : () => _handleToggleLike(context, controller),
            ),

            // 좋아요 수
            if (likes != null && likes.likeCount > 0) ...[
              Text(
                '${likes.likeCount}',
                style: const TextStyle(fontSize: 12),
              ),

              // 최근 좋아요 사용자
              if (likes.recentLikerNames.isNotEmpty)
                Text(
                  likes.recentLikerNames.join(', '),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _handleToggleLike(
    BuildContext context,
    PhotoLikeController controller,
  ) async {
    try {
      await controller.toggleLike(photoId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('좋아요 실패: $e')),
      );
    }
  }
}
```

#### Step 7: 기존 화면에 통합

```dart
// lib/views/category_detail_screen.dart (수정)
class CategoryDetailScreen extends StatefulWidget {
  // ...
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {

  @override
  void initState() {
    super.initState();
    _loadPhotosAndLikes();
  }

  Future<void> _loadPhotosAndLikes() async {
    final photoController = context.read<PhotoController>();
    final likeController = context.read<PhotoLikeController>();

    // 사진 목록 로드
    await photoController.loadPhotos(widget.categoryId);

    // 모든 사진의 좋아요 정보 일괄 로드
    final photoIds = photoController.photos.map((p) => p.id).toList();
    await likeController.loadMultipleLikes(photoIds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ...
      body: GridView.builder(
        // ...
        itemBuilder: (context, index) {
          final photo = photos[index];
          return Stack(
            children: [
              // 사진
              Image.network(photo.url),

              // 좋아요 버튼 추가 ✅
              Positioned(
                bottom: 8,
                right: 8,
                child: PhotoLikeButton(photoId: photo.id),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

#### Step 8: 테스트

```bash
# 1. Dev 환경으로 실행
flutter run --dart-define=ENV=dev

# 2. 테스트 시나리오
# - 사진 좋아요 클릭
# - 좋아요 취소
# - 좋아요 수 표시 확인
# - 최근 좋아요 사용자 목록 확인
```

---

## 🎬 시나리오 2: 기존 API 수정

### 상황

Category API에서 "멤버 프로필 이미지"를 추가로 반환해야 합니다.

### 백엔드 개발자 작업

#### Step 1: DTO 수정

```java
// src/main/java/com/soi/dto/category/CategoryMemberDTO.java (신규)
@Getter
@Builder
public class CategoryMemberDTO {
    private String userId;
    private String name;
    private String profileImageUrl;  // ✅ 추가
}

// src/main/java/com/soi/dto/category/CategoryDTO.java (수정)
@Getter
@Builder
public class CategoryDTO {
    private String id;
    private String name;
    private List<CategoryMemberDTO> mates;  // ✅ String → CategoryMemberDTO
    private String categoryPhotoUrl;
    private LocalDateTime createdAt;
}
```

#### Step 2: Service 수정

```java
// src/main/java/com/soi/service/CategoryService.java
@Service
@RequiredArgsConstructor
public class CategoryService {

    private final CategoryRepository categoryRepository;
    private final UserRepository userRepository;

    @Transactional(readOnly = true)
    public List<CategoryDTO> getUserCategories(String userId) {
        List<Category> categories = categoryRepository.findByUserId(userId);

        return categories.stream()
            .map(this::toCategoryDTO)
            .collect(Collectors.toList());
    }

    private CategoryDTO toCategoryDTO(Category category) {
        // ✅ 멤버 정보를 User 테이블에서 조회
        List<CategoryMemberDTO> members = category.getMates().stream()
            .map(userId -> userRepository.findById(userId)
                .map(user -> CategoryMemberDTO.builder()
                    .userId(user.getId())
                    .name(user.getName())
                    .profileImageUrl(user.getProfileImageUrl())  // ✅ 추가
                    .build())
                .orElse(null))
            .filter(Objects::nonNull)
            .collect(Collectors.toList());

        return CategoryDTO.builder()
            .id(category.getId())
            .name(category.getName())
            .mates(members)  // ✅ 변경
            .categoryPhotoUrl(category.getCategoryPhotoUrl())
            .createdAt(category.getCreatedAt())
            .build();
    }
}
```

#### Step 3: 배포

```bash
git add .
git commit -m "feat: Add profile image URL to category members"
git push origin main

# CI/CD 자동 배포 → Dev 서버
```

---

### 프론트엔드 개발자 작업

#### Step 1: API 재생성

```bash
make update-api
```

#### Step 2: 변경사항 확인

```dart
// ❌ 이전 (String 리스트)
class CategoryDTO {
  final String id;
  final String name;
  final List<String> mates;  // 단순 userId 배열
  // ...
}

// ✅ 이후 (객체 리스트)
class CategoryDTO {
  final String id;
  final String name;
  final List<CategoryMemberDTO> mates;  // 멤버 정보 포함
  // ...
}

// ✅ 새로 생성된 DTO
class CategoryMemberDTO {
  final String userId;
  final String name;
  final String profileImageUrl;

  CategoryMemberDTO({
    required this.userId,
    required this.name,
    required this.profileImageUrl,
  });
}
```

#### Step 3: 코드 수정 (컴파일 에러 수정)

```dart
// lib/widgets/category_card.dart (수정)
class CategoryCard extends StatelessWidget {
  final CategoryDTO category;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text(category.name),

          // ❌ 이전 코드
          // Text('멤버: ${category.mates.length}명'),

          // ✅ 새 코드
          Row(
            children: category.mates.map((member) {
              return CircleAvatar(
                backgroundImage: member.profileImageUrl != null
                    ? NetworkImage(member.profileImageUrl!)
                    : null,
                child: member.profileImageUrl == null
                    ? Text(member.name[0])
                    : null,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
```

#### Step 4: 테스트

```bash
flutter run --dart-define=ENV=dev
```

---

## 🎬 시나리오 3: 에러 처리

### 상황

서버 에러가 발생했을 때 사용자 친화적인 메시지를 표시해야 합니다.

### 백엔드: 표준 에러 응답

```java
// src/main/java/com/soi/dto/ApiResponse.java
@Getter
@Builder
public class ApiResponse<T> {
    private boolean success;
    private T data;
    private ErrorDetail error;

    @Getter
    @Builder
    public static class ErrorDetail {
        private String code;        // "FRIEND_NOT_FOUND"
        private String message;     // "친구를 찾을 수 없습니다"
        private String field;       // "targetUserId" (validation error)
        private Map<String, Object> metadata;
    }
}

// GlobalExceptionHandler.java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(NotFoundException.class)
    public ResponseEntity<ApiResponse<?>> handleNotFound(NotFoundException e) {
        ApiResponse<?> response = ApiResponse.builder()
            .success(false)
            .error(ApiResponse.ErrorDetail.builder()
                .code("NOT_FOUND")
                .message(e.getMessage())
                .build())
            .build();

        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(response);
    }

    @ExceptionHandler(FriendNotFoundException.class)
    public ResponseEntity<ApiResponse<?>> handleFriendNotFound(FriendNotFoundException e) {
        ApiResponse<?> response = ApiResponse.builder()
            .success(false)
            .error(ApiResponse.ErrorDetail.builder()
                .code("FRIEND_NOT_FOUND")
                .message("친구를 찾을 수 없습니다")
                .metadata(Map.of("userId", e.getUserId()))
                .build())
            .build();

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }
}
```

### 프론트엔드: 에러 처리

```dart
// lib/config/api_config.dart (수정)
class ApiConfig {
  static Dio createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: EnvironmentConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // 에러 인터셉터 추가
    dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        final errorMessage = _parseErrorMessage(error);

        // 사용자 친화적 메시지로 변환
        final userFriendlyError = DioException(
          requestOptions: error.requestOptions,
          response: error.response,
          type: error.type,
          message: errorMessage,
        );

        handler.next(userFriendlyError);
      },
    ));

    return dio;
  }

  static String _parseErrorMessage(DioException error) {
    // 1. 서버 응답 파싱
    if (error.response?.data != null) {
      try {
        final data = error.response!.data;
        if (data is Map<String, dynamic> && data['error'] != null) {
          final errorDetail = data['error'];

          // 에러 코드별 메시지 매핑
          final code = errorDetail['code'] as String?;
          switch (code) {
            case 'FRIEND_NOT_FOUND':
              return '친구를 찾을 수 없습니다. 먼저 친구를 추가해주세요.';
            case 'CATEGORY_FULL':
              return '카테고리 인원이 가득 찼습니다 (최대 10명)';
            case 'ALREADY_MEMBER':
              return '이미 카테고리에 포함된 멤버입니다';
            case 'BLOCKED_USER':
              return '차단된 사용자입니다';
            default:
              return errorDetail['message'] ?? '알 수 없는 오류가 발생했습니다';
          }
        }
      } catch (e) {
        debugPrint('Error parsing server error: $e');
      }
    }

    // 2. 네트워크 에러
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return '서버 연결 시간이 초과되었습니다';
    }

    if (error.type == DioExceptionType.connectionError) {
      return '네트워크 연결을 확인해주세요';
    }

    // 3. HTTP 상태 코드
    switch (error.response?.statusCode) {
      case 400:
        return '잘못된 요청입니다';
      case 401:
        return '로그인이 필요합니다';
      case 403:
        return '권한이 없습니다';
      case 404:
        return '요청한 리소스를 찾을 수 없습니다';
      case 500:
        return '서버 오류가 발생했습니다';
      default:
        return error.message ?? '알 수 없는 오류가 발생했습니다';
    }
  }
}
```

사용 예시:

```dart
// lib/controllers/category_controller.dart
class CategoryController extends ChangeNotifier {
  Future<void> addMember(String categoryId, String userId) async {
    try {
      await _repository.addMember(categoryId: categoryId, targetUserId: userId);
      Fluttertoast.showToast(msg: '멤버를 추가했습니다');
    } catch (e) {
      // ✅ ApiConfig에서 변환한 사용자 친화적 메시지
      Fluttertoast.showToast(
        msg: e.toString(),
        backgroundColor: Colors.red,
      );
    }
  }
}
```

---

## ⏰ 타임라인 예시

### 새 기능 개발 (좋아요 기능)

| 시간        | 작업                         | 담당   |
| ----------- | ---------------------------- | ------ |
| Day 1 오전  | Entity, DTO, Service 개발    | 백엔드 |
| Day 1 오후  | Controller, 테스트, Dev 배포 | 백엔드 |
| Day 1 17:00 | 프론트에 API 완료 알림       | 백엔드 |
| Day 2 오전  | `make update-api` 실행       | 프론트 |
| Day 2 오전  | Repository, Controller 추가  | 프론트 |
| Day 2 오후  | UI 구현 및 테스트            | 프론트 |
| Day 2 17:00 | 기능 완료                    | 프론트 |

**총 소요 시간: 2일**

---

## 📝 커뮤니케이션 템플릿

### 백엔드 → 프론트

```
✅ [기능명] API 배포 완료

**Environment:** Dev
**Endpoints:**
- POST /api/v1/photos/{photoId}/likes - 좋아요 토글
- GET /api/v1/photos/{photoId}/likes - 좋아요 정보 조회

**Changes:**
- PhotoLikeResponse에 recentLikerNames 추가
- likeCount 타입 변경 (String → int)

**OpenAPI Spec:**
https://dev-api.soi.app/v3/api-docs.yaml

**Swagger UI:**
https://dev-api.soi.app/swagger-ui.html

**Notes:**
- 자신의 사진에는 알림이 가지 않습니다
- 최근 3명의 좋아요 사용자 이름이 포함됩니다

명령어: `make update-api`
```

### 프론트 → 백엔드

````
🐛 API 에러 발견

**Endpoint:** POST /api/v1/categories/{id}/members
**Error:**
- 친구가 아닌 사용자를 추가할 때 500 에러 발생
- 기대: 400 Bad Request with "FRIEND_NOT_FOUND"

**Reproduction:**
```bash
curl -X POST https://dev-api.soi.app/api/v1/categories/cat123/members \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"targetUserId": "non_friend_user"}'
````

**Response:**

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "NullPointerException"
  }
}
```

```

---

## 📝 다음 단계

개발 워크플로우를 이해했다면:

👉 **[8. 개발 환경 설정으로 이동](./08-environment-setup.md)**
```
