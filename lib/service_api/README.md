# Service API Layer - 초보자를 위한 완벽 가이드 📚

> 💡 **이 문서는 무엇인가요?**  
> OpenAPI로 자동 생성된 복잡한 API 코드를 우리가 실제로 사용하기 쉽게 포장(wrapping)한 코드입니다.  
> 마치 복잡한 리모컨을 간단한 버튼 몇 개로 만든 것과 같아요!

## 🤔 왜 이게 필요한가요?

### 문제 상황

OpenAPI Generator가 만들어준 API 코드(`friend_api_api.dart`)는 이렇게 생겼어요:

```dart
// 😰 너무 복잡해요!
final response = await friendApi.create(
  friendReqDto: FriendReqDto(requesterId: 1, receiverId: 2),
);

// 에러 처리도 복잡하고...
try {
  // API 호출
} on DioException catch (e) {
  // 에러 타입이 뭐지? 어떻게 처리하지?
  if (e.type == DioExceptionType.connectionTimeout) {
    // ...
  } else if (e.type == DioExceptionType.badResponse) {
    // ...
  }
  // 케이스가 너무 많아요 😭
}
```

### 우리의 해결책

Service Layer를 만들어서 이렇게 간단하게 바꿨어요:

```dart
// ✨ 훨씬 간단해요!
final result = await friendService.addFriend(
  requesterId: 1,
  receiverId: 2,
);

// 에러 처리도 쉬워요!
result.when(
  success: (friend) => print('성공! 친구 ID: ${friend.id}'),
  failure: (error) => print('실패: ${error.message}'),
);
```

## 📁 폴더 구조 설명

우리 프로젝트의 `lib/service_api/` 폴더는 이렇게 구성되어 있어요:

```
lib/service_api/
├── common/                        # 공통으로 사용하는 도구들
│   ├── api_result.dart           # ⭐ 성공/실패를 표현하는 타입
│   └── dio_exception_handler.dart # 🛠️ 에러를 알기 쉽게 변환
├── friend_service.dart            # 👥 친구 기능 Service
└── README.md                      # 📖 이 문서
```

### 각 파일이 하는 일

#### 1️⃣ `api_result.dart` - 성공/실패를 명확하게 구분

**일상 비유:** 시험 결과지 같은 거예요

- **성공(Success)**: "합격! 점수는 95점"
- **실패(Failure)**: "불합격. 이유: 시간 초과"

**코드로 보면:**

```dart
// 성공한 경우
ApiResult.success(친구데이터);

// 실패한 경우
ApiResult.failure(에러정보);
```

**왜 필요한가요?**

- 일반적인 코드는 에러가 나면 앱이 터질 수 있어요 💥
- `ApiResult`를 사용하면 에러도 결과의 일부로 안전하게 처리해요 ✅

#### 2️⃣ `dio_exception_handler.dart` - 에러 메시지 번역기

**일상 비유:** 의학 용어를 일반인도 알기 쉽게 설명해주는 의사 선생님

**변환 예시:**

```dart
// Before: DioException (개발자용 에러)
"DioExceptionType.connectionTimeout occurred"

// After: ApiFailure (사용자 친화적 메시지)
"⏰ 요청 시간이 초과되었습니다. 네트워크를 확인해주세요."
```

**처리하는 에러 종류:**

- 🌐 네트워크 연결 끊김
- ⏰ 시간 초과
- 🔐 로그인 필요 (401)
- 🚫 권한 없음 (403)
- 📡 서버 오류 (500)

#### 3️⃣ `friend_service.dart` - 친구 기능의 사령탑

**일상 비유:** 패스트푸드 점원

- 손님(개발자): "빅맥 세트 주세요"
- 점원(Service): 주방에 복잡한 주문 전달 → 음식 받아서 → 손님에게 전달

**제공하는 기능:**

```dart
// 1. 친구 추가 요청 보내기
friendService.addFriend(requesterId: 나, receiverId: 상대방)

// 2. 친구 요청 수락하기
friendService.acceptFriendRequest(friendshipId: 123)

// 3. 친구 요청 취소하기
friendService.cancelFriendRequest(friendshipId: 123)

// 4. 친구 차단하기
friendService.blockFriend(friendshipId: 123)
```

## 🎯 핵심 개념 3가지

### 💎 개념 1: ApiResult - 결과를 안전하게 담는 상자

**기존 방식의 문제점:**

```dart
// ❌ 에러가 나면 앱이 터져요!
String getUserName() {
  return api.getName(); // 만약 서버가 다운되면? 💥
}
```

**우리 방식:**

```dart
// ✅ 에러가 나도 안전해요!
ApiResult<String> getUserName() {
  try {
    return ApiResult.success(api.getName());
  } catch (e) {
    return ApiResult.failure(ApiFailure(message: "에러 발생"));
  }
}

// 사용할 때
final result = getUserName();
if (result.isSuccess) {
  print("이름: ${result.dataOrNull}"); // 성공한 경우
} else {
  print("에러: ${result.failureOrNull?.message}"); // 실패한 경우
}
```

**중요한 속성들:**

```dart
result.isSuccess     // true면 성공
result.isFailure     // true면 실패
result.dataOrNull    // 성공했을 때 데이터 (없으면 null)
result.failureOrNull // 실패했을 때 에러 정보 (없으면 null)
```

### 🎭 개념 2: when 메서드 - 양자택일 처리

**일상 비유:** 갈림길에서 선택하기

```
성공하면 → 왼쪽 길로 가기
실패하면 → 오른쪽 길로 가기
```

**코드:**

```dart
result.when(
  success: (data) {
    // ✅ 성공했을 때 실행
    print("성공! 데이터: $data");
    // 화면 업데이트, 메시지 표시 등
  },
  failure: (error) {
    // ❌ 실패했을 때 실행
    print("실패! 이유: ${error.message}");
    // 에러 메시지 표시
  },
);
```

**장점:**

- 성공과 실패를 모두 처리하도록 강제해요 (빠뜨릴 수 없어요!)
- 코드가 깔끔하고 읽기 쉬워요

### 🛡️ 개념 3: 입력값 검증 - 미리 막기

**일상 비유:** 놀이기구 탑승 전 키 재기

**예시:**

```dart
// ❌ 나쁜 예: 검증 없이 바로 서버로 전송
friendService.addFriend(requesterId: -1, receiverId: 0);
// → 서버 에러 발생! 💥

// ✅ 좋은 예: Service에서 미리 검증
Future<ApiResult<Friend>> addFriend({
  required int requesterId,
  required int receiverId,
}) async {
  // 검증 1: 자기 자신에게 친구 요청?
  if (requesterId == receiverId) {
    return ApiResult.failure(
      ApiFailure(message: "자기 자신에게 친구 요청을 보낼 수 없습니다"),
    );
  }

  // 검증 2: 유효한 ID인가?
  if (requesterId <= 0 || receiverId <= 0) {
    return ApiResult.failure(
      ApiFailure(message: "유효하지 않은 사용자 ID입니다"),
    );
  }

  // 검증 통과! 서버에 요청
  return DioExceptionHandler.catchError(() async {
    // 실제 API 호출
  });
}
```

**장점:**

- 서버에 불필요한 요청을 보내지 않아요 (효율적!)
- 사용자에게 즉시 피드백을 줄 수 있어요
- 서버 비용을 절약해요

## 🚀 실제로 사용하는 법 (단계별 가이드)

### 📝 Step 1: 패키지 설치하기

프로젝트 최상단의 `pubspec.yaml` 파일을 열고 dependencies에 추가:

```yaml
dependencies:
  # ... 기존 패키지들 ...

  # 🆕 새로 추가할 패키지들
  dio: ^5.9.0 # HTTP 통신 라이브러리
  soi_api: # 우리가 만든 API 패키지
    path: lib/api/generated
```

터미널에서 실행:

```bash
flutter pub get
```

### 🏗️ Step 2: Service 인스턴스 만들기 (초기 설정)

**방법 A: 간단한 방법 (테스트용)**

```dart
import 'package:dio/dio.dart';
import 'package:soi_api/soi_api.dart';
import 'package:soi/service_api/friend_service.dart';

void main() {
  // 1단계: Dio 만들기 (HTTP 통신 도구)
  final dio = Dio(BaseOptions(
    baseUrl: 'https://your-api-server.com', // 서버 주소
    connectTimeout: const Duration(seconds: 10), // 10초 기다리기
    receiveTimeout: const Duration(seconds: 10),
  ));

  // 2단계: API 클라이언트 만들기
  final friendApi = FriendAPIApi(dio);

  // 3단계: Service 만들기
  final friendService = FriendService(friendApi);

  // 4단계: 사용하기
  friendService.addFriend(requesterId: 1, receiverId: 2);
}
```

**방법 B: Provider 사용 (실전용 - 권장!)**

왜 Provider를 쓰나요?

- 🌐 앱 전체에서 Service를 공유할 수 있어요
- 🔄 Service를 한 번만 만들어도 돼요
- 🧪 테스트하기 쉬워요

**providers.dart 파일 만들기:**

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:soi_api/soi_api.dart';
import 'package:soi/service_api/friend_service.dart';

/// 앱 전체에 Service를 제공하는 위젯
class AppProviders extends StatelessWidget {
  final Widget child;  // 우리 앱의 나머지 부분

  const AppProviders({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    // Dio 인스턴스 (HTTP 통신 도구)
    final dio = Dio(BaseOptions(
      baseUrl: 'https://your-api-server.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    return MultiProvider(
      providers: [
        // 🔧 API 클라이언트 제공
        Provider<FriendAPIApi>(
          create: (_) => FriendAPIApi(dio),
        ),

        // 🎁 Service 제공
        ProxyProvider<FriendAPIApi, FriendService>(
          update: (_, api, __) => FriendService(api),
        ),

        // 💡 나중에 UserService, CategoryService 등도 여기 추가
      ],
      child: child,
    );
  }
}
```

**main.dart에서 사용:**

```dart
void main() {
  runApp(
    // 앱 전체를 AppProviders로 감싸기
    AppProviders(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FriendListScreen(),
    );
  }
}
```

### 🎨 Step 3: 화면에서 사용하기

#### 예제 1: 친구 추가 버튼

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:soi/service_api/friend_service.dart';

class FriendListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('친구 목록')),

      // ➕ 친구 추가 버튼
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.person_add),
        onPressed: () async {
          // 1️⃣ Provider에서 Service 가져오기
          final friendService = context.read<FriendService>();

          // 2️⃣ API 호출
          final result = await friendService.addFriend(
            requesterId: 1,  // 내 ID
            receiverId: 2,   // 친구 ID
          );

          // 3️⃣ 결과 처리
          result.when(
            success: (friend) {
              // ✅ 성공!
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('친구 추가 성공! 🎉'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            failure: (error) {
              // ❌ 실패...
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('에러: ${error.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            },
          );
        },
      ),

      body: ListView(/* 친구 목록 */),
    );
  }
}
```

#### 예제 2: 완전한 친구 추가 화면 (실전 코드)

````dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:soi/service_api/friend_service.dart';

#### 예제 2: 완전한 친구 추가 화면 (실전 코드)

이제 처음부터 끝까지 완전한 화면을 만들어볼게요!

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:soi/service_api/friend_service.dart';

/// 친구 추가 화면
class AddFriendScreen extends StatefulWidget {
  final int currentUserId;  // 현재 로그인한 사용자 ID

  const AddFriendScreen({
    required this.currentUserId,
    super.key,
  });

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  // 📝 텍스트 입력을 관리하는 컨트롤러
  final _userIdController = TextEditingController();

  // 🔄 로딩 중인지 표시
  bool _isLoading = false;

  @override
  void dispose() {
    // 메모리 누수 방지: 사용 완료된 컨트롤러는 꼭 dispose!
    _userIdController.dispose();
    super.dispose();
  }

  /// 친구 추가 버튼을 눌렀을 때 실행되는 함수
  Future<void> _addFriend() async {
    // 1️⃣ 입력값 가져오기
    final targetUserIdStr = _userIdController.text.trim();

    // 2️⃣ 빈 값 체크
    if (targetUserIdStr.isEmpty) {
      _showError('사용자 ID를 입력해주세요');
      return;
    }

    // 3️⃣ 숫자로 변환 (실패하면 null)
    final targetUserId = int.tryParse(targetUserIdStr);
    if (targetUserId == null) {
      _showError('숫자만 입력해주세요');
      return;
    }

    // 4️⃣ 로딩 시작
    setState(() => _isLoading = true);

    try {
      // 5️⃣ Service 가져오기
      final friendService = context.read<FriendService>();

      // 6️⃣ API 호출
      final result = await friendService.addFriend(
        requesterId: widget.currentUserId,
        receiverId: targetUserId,
      );

      // 7️⃣ 결과 처리
      result.when(
        success: (friend) {
          // ✅ 성공: 성공 메시지 보여주고 화면 닫기
          _showSuccess('친구 요청을 보냈습니다! 🎉');
          Navigator.pop(context, friend);  // 이전 화면으로 돌아가며 결과 전달
        },
        failure: (error) {
          // ❌ 실패: 에러 메시지 표시
          _showError(error.message);
        },
      );
    } finally {
      // 8️⃣ 로딩 종료 (성공/실패 상관없이 무조건 실행)
      if (mounted) {  // 화면이 아직 있는지 확인
        setState(() => _isLoading = false);
      }
    }
  }

  /// 에러 메시지를 보여주는 함수
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// 성공 메시지를 보여주는 함수
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('친구 추가'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📝 텍스트 입력 필드
            TextField(
              controller: _userIdController,
              keyboardType: TextInputType.number,  // 숫자 키보드
              decoration: InputDecoration(
                labelText: '친구 ID',
                hintText: '추가할 친구의 ID를 입력하세요',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              enabled: !_isLoading,  // 로딩 중에는 입력 불가
            ),

            SizedBox(height: 16),

            // 🔘 친구 추가 버튼
            ElevatedButton(
              onPressed: _isLoading ? null : _addFriend,  // 로딩 중에는 버튼 비활성화
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      '친구 추가',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
````

**코드 설명:**

1. **상태 관리**

   - `_userIdController`: 입력한 텍스트를 저장
   - `_isLoading`: 지금 API 호출 중인지 표시

2. **입력 검증**

   - 빈 값 체크
   - 숫자 형식 체크
   - 사용자에게 친절한 에러 메시지

3. **로딩 처리**

   - 버튼 비활성화로 중복 클릭 방지
   - 로딩 인디케이터 표시
   - `finally` 블록으로 확실하게 로딩 종료

4. **UI/UX**
   - SnackBar로 결과 알림
   - 성공/실패에 따라 다른 색상
   - 로딩 중에는 입력 비활성화

#### 예제 3: 친구 목록 + 상태별 처리

```dart
import 'package:flutter/material.dart';
import 'package:soi_api/soi_api.dart';
import 'package:soi/service_api/friend_service.dart';

class FriendListItem extends StatelessWidget {
  final FriendRespDto friend;
  final FriendService friendService;

  const FriendListItem({
    required this.friend,
    required this.friendService,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(friend.id.toString()),
      ),
      title: Text('친구 #${friend.receiverId}'),
      subtitle: _buildSubtitle(),
      trailing: _buildActionButton(context),
    );
  }

  /// 친구 상태에 따라 다른 부제목 표시
  Widget _buildSubtitle() {
    if (FriendService.isPending(friend)) {
      return Text('⏳ 대기 중', style: TextStyle(color: Colors.orange));
    } else if (FriendService.isAccepted(friend)) {
      return Text('✅ 친구', style: TextStyle(color: Colors.green));
    } else if (FriendService.isBlocked(friend)) {
      return Text('🚫 차단됨', style: TextStyle(color: Colors.red));
    } else {
      return Text('❌ 취소됨', style: TextStyle(color: Colors.grey));
    }
  }

  /// 친구 상태에 따라 다른 버튼 표시
  Widget? _buildActionButton(BuildContext context) {
    if (FriendService.isPending(friend)) {
      // 대기 중 → 수락/거절 버튼
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.check, color: Colors.green),
            onPressed: () => _acceptFriend(context),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.red),
            onPressed: () => _cancelFriend(context),
          ),
        ],
      );
    } else if (FriendService.isAccepted(friend)) {
      // 친구 → 차단 버튼
      return IconButton(
        icon: Icon(Icons.block, color: Colors.red),
        onPressed: () => _blockFriend(context),
      );
    }
    return null;
  }

  /// 친구 요청 수락
  Future<void> _acceptFriend(BuildContext context) async {
    final result = await friendService.acceptFriendRequest(
      friendshipId: friend.id!,
    );

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ 친구 요청을 수락했습니다')),
        );
      },
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${error.message}')),
        );
      },
    );
  }

  /// 친구 요청 취소
  Future<void> _cancelFriend(BuildContext context) async {
    final result = await friendService.cancelFriendRequest(
      friendshipId: friend.id!,
    );

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 친구 요청을 거절했습니다')),
        );
      },
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${error.message}')),
        );
      },
    );
  }

  /// 친구 차단
  Future<void> _blockFriend(BuildContext context) async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('친구 차단'),
        content: Text('정말 이 친구를 차단하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('차단', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await friendService.blockFriend(
      friendshipId: friend.id!,
    );

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🚫 친구를 차단했습니다')),
        );
      },
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${error.message}')),
        );
      },
    );
  }
}
```

## 🔍 자주 사용하는 패턴들

### 패턴 1: 로딩 상태 관리

```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  bool _isLoading = false;

  Future<void> _doSomething() async {
    // ✅ 올바른 로딩 상태 관리
    setState(() => _isLoading = true);

    try {
      final result = await friendService.addFriend(...);
      // 결과 처리
    } finally {
      // ⭐ finally를 사용하면 에러가 나도 로딩이 꺼져요!
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _doSomething,  // 로딩 중엔 비활성화
      child: _isLoading ? CircularProgressIndicator() : Text('실행'),
    );
  }
}
```

### 패턴 2: 에러 메시지 표시

```dart
/// SnackBar 사용 (간단한 메시지)
void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      action: SnackBarAction(
        label: '확인',
        textColor: Colors.white,
        onPressed: () {},
      ),
    ),
  );
}

/// Dialog 사용 (중요한 메시지)
void _showErrorDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('오류', style: TextStyle(color: Colors.red)),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('확인'),
        ),
      ],
    ),
  );
}
```

### 패턴 3: 결과에 따른 화면 전환

```dart
Future<void> _addFriendAndNavigate() async {
  final result = await friendService.addFriend(...);

  result.when(
    success: (friend) {
      // ✅ 성공: 다음 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FriendDetailScreen(friend: friend),
        ),
      );
    },
    failure: (error) {
      // ❌ 실패: 에러 메시지만 표시하고 현재 화면 유지
      _showError(error.message);
    },
  );
}
```

### 패턴 4: 여러 API를 순차적으로 호출

```dart
Future<void> _addMultipleFriends(List<int> userIds) async {
  for (final userId in userIds) {
    final result = await friendService.addFriend(
      requesterId: currentUserId,
      receiverId: userId,
    );

    // 하나라도 실패하면 중단
    if (result.isFailure) {
      _showError('친구 추가 실패: ${result.failureOrNull?.message}');
      break;
    }
  }

  _showSuccess('모든 친구 추가 완료!');
}
```

## 💡 초보자가 자주 하는 실수와 해결법

### ❌ 실수 1: ApiResult를 벗겨내지 않고 사용

```dart
// ❌ 나쁜 예
final result = await friendService.addFriend(...);
print(result);  // ApiResult<FriendRespDto> 전체가 출력됨

// ✅ 좋은 예
final result = await friendService.addFriend(...);
result.when(
  success: (friend) => print(friend),  // FriendRespDto만 출력
  failure: (error) => print(error.message),
);
```

### ❌ 실수 2: 에러 처리를 안 함

```dart
// ❌ 나쁜 예: 에러가 나면 앱이 멈춤
final result = await friendService.addFriend(...);
final friend = result.dataOrNull!;  // 💥 실패하면 null인데 !를 써서 에러!

// ✅ 좋은 예
final result = await friendService.addFriend(...);
if (result.isSuccess) {
  final friend = result.dataOrNull!;  // 성공 확인 후 사용
  print(friend);
} else {
  print('에러 발생');
}
```

### ❌ 실수 3: mounted 체크를 안 함

```dart
// ❌ 나쁜 예: 화면이 사라진 후 setState 호출 → 에러!
Future<void> _loadData() async {
  final result = await someApi();
  setState(() {  // 💥 화면이 이미 사라졌을 수 있어요!
    _data = result;
  });
}

// ✅ 좋은 예
Future<void> _loadData() async {
  final result = await someApi();
  if (mounted) {  // 화면이 아직 있는지 확인
    setState(() {
      _data = result;
    });
  }
}
```

### ❌ 실수 4: 컨트롤러를 dispose 안 함

```dart
// ❌ 나쁜 예: 메모리 누수!
class _MyScreenState extends State<MyScreen> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
  // dispose가 없어요! 💥
}

// ✅ 좋은 예
class _MyScreenState extends State<MyScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();  // 꼭 정리!
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
}
```

## 🎓 학습 체크리스트

공부하면서 하나씩 체크해보세요!

- [ ] `ApiResult`가 무엇인지 이해했나요?
- [ ] `when` 메서드로 성공/실패를 처리할 수 있나요?
- [ ] Service를 Provider로 제공할 수 있나요?
- [ ] 화면에서 `context.read<Service>()`로 Service를 가져올 수 있나요?
- [ ] 로딩 상태를 관리할 수 있나요?
- [ ] 에러 메시지를 사용자에게 보여줄 수 있나요?
- [ ] `mounted` 체크의 중요성을 이해했나요?
- [ ] 컨트롤러를 `dispose()`하는 것을 기억하나요?

## 📊 전체 흐름도

```
사용자 행동 (버튼 클릭)
    ↓
화면 (View)
    ↓
Service 호출 (friendService.addFriend)
    ↓
입력값 검증 ✓
    ↓
API 호출 (OpenAPI 생성 코드)
    ↓
서버 응답
    ↓
DioException 발생? → DioExceptionHandler → ApiFailure
    ↓
ApiResult<FriendRespDto> 반환
    ↓
when 메서드로 처리
    ├─ success → UI 업데이트, 성공 메시지
    └─ failure → 에러 메시지 표시
```

## 🔗 다음 단계

### 지금 할 수 있는 것들

1. ✅ 친구 추가 기능 구현
2. ✅ 친구 요청 수락/거절
3. ✅ 친구 차단
4. ✅ 에러 처리

### 앞으로 배울 것들

1. 🔲 `UserService` 만들기 (사용자 정보)
2. 🔲 `CategoryService` 만들기 (카테고리)
3. 🔲 캐싱 추가 (같은 데이터 반복 요청 방지)
4. 🔲 재시도 로직 (네트워크 에러 시 자동 재시도)
5. 🔲 테스트 코드 작성

## 📚 도움이 되는 자료

- [OpenAPI Generator 가이드](../docs/dev/flutter_open_api_generator.md)
- [Dio 공식 문서](https://pub.dev/packages/dio)
- [Provider 패턴 배우기](https://pub.dev/packages/provider)
- [Flutter 공식 문서](https://flutter.dev)

## 💬 질문이 있나요?

이 코드를 이해하는 데 어려움이 있다면:

1. 주석을 꼼꼼히 읽어보세요 📖
2. 예제 코드를 직접 타이핑해보세요 ⌨️
3. 디버그 모드로 실행해서 각 단계를 확인해보세요 🔍
4. 시니어 개발자에게 질문하세요 🙋

**Remember**: 모든 시니어 개발자도 처음엔 초보였습니다! 천천히, 하나씩 이해하며 가면 됩니다. 화이팅! 🚀

---

**작성일**: 2025년 11월 2일  
**대상**: 대학교 1학년 ~ 주니어 개발자  
**난이도**: ⭐⭐ (기초 ~ 초중급)

````

## 🔍 헬퍼 메서드 활용

`FriendService`는 친구 상태를 확인하는 편리한 static 메서드들을 제공합니다:

```dart
import 'package:soi_api/soi_api.dart';
import 'package:soi/service_api/friend_service.dart';

void checkFriendStatus(FriendRespDto friend) {
  if (FriendService.isPending(friend)) {
    print('대기 중인 친구 요청입니다');
    // "수락" 버튼 표시
  } else if (FriendService.isAccepted(friend)) {
    print('이미 친구입니다');
    // 친구 프로필 표시
  } else if (FriendService.isBlocked(friend)) {
    print('차단된 사용자입니다');
    // 차단 해제 옵션 표시
  } else if (FriendService.isCancelled(friend)) {
    print('취소된 요청입니다');
  }
}
````

## 🧪 테스트하기

Service는 테스트하기 쉽게 설계되어 있습니다:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:soi_api/soi_api.dart';
import 'package:soi/service_api/friend_service.dart';

@GenerateMocks([FriendAPIApi])
void main() {
  late MockFriendAPIApi mockApi;
  late FriendService service;

  setUp(() {
    mockApi = MockFriendAPIApi();
    service = FriendService(mockApi);
  });

  group('FriendService', () {
    test('친구 추가 성공', () async {
      // Given: API가 성공 응답을 반환
      final expectedFriend = FriendRespDto(
        id: 1,
        requesterId: 1,
        receiverId: 2,
        status: FriendRespDtoStatusEnum.PENDING,
      );

      when(mockApi.create(friendReqDto: anyNamed('friendReqDto')))
          .thenAnswer((_) async => Response(
                data: ApiResponseDtoFriendRespDto(
                  success: true,
                  data: expectedFriend,
                ),
                requestOptions: RequestOptions(),
              ));

      // When: 친구 추가 요청
      final result = await service.addFriend(
        requesterId: 1,
        receiverId: 2,
      );

      // Then: 성공 결과 반환
      expect(result.isSuccess, true);
      expect(result.dataOrNull?.id, 1);
    });

    test('자기 자신에게 친구 요청시 에러', () async {
      // When: 같은 ID로 친구 추가 시도
      final result = await service.addFriend(
        requesterId: 1,
        receiverId: 1,
      );

      // Then: 실패 결과 반환
      expect(result.isFailure, true);
      expect(
        result.failureOrNull?.message,
        '자기 자신에게 친구 요청을 보낼 수 없습니다',
      );
    });
  });
}
```

## 📊 에러 처리 플로우

```
API 호출
    ↓
DioException 발생?
    ↓
DioExceptionHandler.handle()
    ↓
ApiFailure 생성
    ↓
ApiResult.failure() 반환
    ↓
UI에서 error.message 표시
```

## 🎓 주니어 개발자를 위한 팁

### 1. **항상 Result 타입으로 감싸기**

```dart
// ❌ 나쁜 예: Exception을 직접 throw
Future<FriendRespDto> addFriend() async {
  return await api.create(...); // DioException이 throw될 수 있음!
}

// ✅ 좋은 예: ApiResult로 감싸기
Future<ApiResult<FriendRespDto>> addFriend() async {
  return DioExceptionHandler.catchError(() async {
    return await api.create(...);
  });
}
```

### 2. **when 메서드로 안전하게 처리**

```dart
// ✅ 성공/실패 케이스를 모두 처리
result.when(
  success: (data) => print(data),
  failure: (error) => print(error),
);
```

### 3. **입력값은 항상 검증**

```dart
if (userId <= 0) {
  return ApiResult.failure(
    ApiFailure(message: '유효하지 않은 ID입니다'),
  );
}
```

### 4. **로딩 상태 관리**

```dart
setState(() => _isLoading = true);
try {
  final result = await service.addFriend(...);
  // 결과 처리
} finally {
  setState(() => _isLoading = false);
}
```

## 🔗 다음 단계

1. ✅ `FriendService` 완성
2. 🔲 `UserService` 추가 (사용자 정보 API)
3. 🔲 `CategoryService` 추가 (카테고리 API)
4. 🔲 에러 로깅 추가 (Firebase Crashlytics 연동)
5. 🔲 재시도 로직 추가 (네트워크 에러시)
6. 🔲 캐싱 레이어 추가

## 📚 참고 자료

- [OpenAPI Generator 문서](docs/dev/flutter_open_api_generator.md)
- [Dio 공식 문서](https://pub.dev/packages/dio)
- [Provider 패턴](https://pub.dev/packages/provider)
