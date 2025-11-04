# SOI API 서비스 레이어

Spring Boot API를 Flutter에서 사용하기 쉽게 래핑한 서비스 레이어입니다.

## 구조

```
lib/api/
├── api.dart                    # 모든 API 관련 export
├── common/                     # 공통 클래스
│   ├── api_client.dart        # API 클라이언트 싱글톤
│   ├── api_response.dart      # 응답 래퍼
│   ├── api_exception.dart     # 예외 처리
│   └── api_result.dart        # Result 패턴 (Success/Failure)
└── services/                   # API 서비스
    ├── user_service.dart      # 사용자 관련 API
    ├── friend_service.dart    # 친구 관련 API
    └── media_service.dart     # 미디어 관련 API
```

## 사용 방법

### 1. Import

```dart
import 'package:soi/api/api.dart';
```

### 2. 사용자 서비스 예시

```dart
final userService = UserService();

// SMS 인증 발송
final result = await userService.sendAuthSMS('01012345678');
result.when(
  success: (sent) => print('인증 발송: $sent'),
  failure: (error) => print('에러: ${error.message}'),
);

// 사용자 생성
final createResult = await userService.createUser(
  name: '홍길동',
  userId: 'gildong',
  phone: '01012345678',
  birthDate: '1990-01-01',
  serviceAgreed: true,
  privacyPolicyAgreed: true,
  marketingAgreed: false,
);

// 로그인
final loginResult = await userService.login('01012345678');
if (loginResult.isSuccess) {
  final user = loginResult.dataOrNull;
  print('로그인 성공: ${user?.userId}');
}

// ID 중복 체크
final checkResult = await userService.checkUserIdDuplicate('gildong');
final isAvailable = checkResult.dataOrNull ?? false;
```

### 3. 친구 서비스 예시

```dart
final friendService = FriendService();

// 친구 추가
await friendService.addFriend(
  requesterId: 1,
  receiverId: 2,
);

// 친구 목록 조회
final friendsResult = await friendService.getAllFriends(1);
friendsResult.when(
  success: (friends) {
    for (var friend in friends) {
      print('친구: ${friend.userId}');
    }
  },
  failure: (error) => print('에러: ${error.message}'),
);

// 친구 차단
await friendService.blockFriend(
  requesterId: 1,
  receiverId: 2,
);

// 친구 상태 업데이트
await friendService.updateFriendStatus(
  friendId: 1,
  status: FriendUpdateRespDtoStatusEnum.ACCEPTED,
);
```

### 4. 미디어 서비스 예시

```dart
final mediaService = MediaService();

// 단일 파일 업로드
final file = File('/path/to/image.jpg');
final uploadResult = await mediaService.uploadSingleMedia(
  file: file,
  type: 'PROFILE',
  id: 1,
);

if (uploadResult.isSuccess) {
  final s3Key = uploadResult.dataOrThrow;
  print('S3 Key: $s3Key');

  // Presigned URL 가져오기
  final urlResult = await mediaService.getPresignedUrl(s3Key);
  final url = urlResult.dataOrNull;
  print('이미지 URL: $url');
}

// 여러 파일 업로드
final files = [
  File('/path/to/image1.jpg'),
  File('/path/to/image2.jpg'),
];

final multiUploadResult = await mediaService.uploadMedia(
  files: files,
  types: 'PHOTO,PHOTO',
  id: 1,
);
```

## ApiResult 패턴

모든 API 호출은 `ApiResult<T>` 타입을 반환합니다.

### 패턴 매칭 방식

```dart
final result = await userService.login('01012345678');

result.when(
  success: (user) {
    // 성공 시 처리
    print('User ID: ${user.id}');
  },
  failure: (exception) {
    // 실패 시 처리
    print('Error: ${exception.message}');
  },
);
```

### 직접 체크 방식

```dart
if (result.isSuccess) {
  final user = result.dataOrNull;
  // 성공 처리
} else {
  final error = result.exceptionOrNull;
  // 실패 처리
}
```

### Throw 방식 (에러 발생 시 예외 던짐)

```dart
try {
  final user = result.dataOrThrow; // 실패 시 ApiException throw
  // 성공 처리
} on ApiException catch (e) {
  // 에러 처리
  print(e.message);
}
```

## 에러 처리

### ApiException 타입

- `ApiException.networkError()` - 네트워크 에러
- `ApiException.serverError()` - 서버 에러 (500)
- `ApiException.unauthorized()` - 인증 필요 (401)
- `ApiException.forbidden()` - 권한 없음 (403)
- `ApiException.notFound()` - 리소스 없음 (404)
- `ApiException.badRequest()` - 잘못된 요청 (400)

### 사용 예시

```dart
result.when(
  success: (data) => handleSuccess(data),
  failure: (exception) {
    switch (exception.statusCode) {
      case 401:
        // 로그인 페이지로 이동
        break;
      case 404:
        // 리소스 없음 메시지
        break;
      default:
        // 일반 에러 처리
        showToast(exception.message);
    }
  },
);
```

## 인증 토큰 설정

```dart
// 로그인 후 토큰 설정
SoiApiClient().setAuthToken('your-jwt-token');

// 로그아웃 시 토큰 제거
SoiApiClient().clearAuthToken();
```

## Base URL 변경 (개발/프로덕션)

```dart
// 개발 서버
SoiApiClient().setBaseUrl('http://localhost:8080');

// 프로덕션 서버 (기본값)
SoiApiClient().setBaseUrl('https://newdawnsoi.site');
```

## Provider와 통합 예시

```dart
class UserRepository {
  final UserService _userService = UserService();

  Future<UserRespDto?> login(String phone) async {
    final result = await _userService.login(phone);
    return result.dataOrNull;
  }
}

// Provider에서 사용
class AuthController with ChangeNotifier {
  final UserRepository _repository = UserRepository();
  UserRespDto? _currentUser;

  Future<bool> login(String phone) async {
    final user = await _repository.login(phone);
    if (user != null) {
      _currentUser = user;
      notifyListeners();
      return true;
    }
    return false;
  }
}
```

## 주의사항

1. **자동 생성된 코드 수정 금지**: `api/generated/` 내부 파일은 수정하지 마세요.
2. **Service 레이어 사용**: 직접 API 클래스를 사용하지 말고 Service를 통해 호출하세요.
3. **에러 처리 필수**: 모든 API 호출은 반드시 에러 처리를 해야 합니다.
4. **Result 패턴 활용**: `ApiResult`의 when 메서드를 활용하면 안전합니다.

## 로깅

모든 서비스는 `dart:developer`의 log를 사용하여 디버그 로그를 출력합니다:

- 📱 SMS 관련
- 👤 사용자 관련
- 🔐 로그인 관련
- 👥 친구 관련
- 📤 업로드 관련
- 🔗 URL 관련
- ✅ 성공
- ❌ 실패
