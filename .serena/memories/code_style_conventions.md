# SOI 코드 스타일 및 컨벤션

## Dart/Flutter 코딩 스타일

### 파일 및 폴더 명명
- **파일명**: snake_case (예: `camera_screen.dart`, `auth_controller.dart`)
- **폴더명**: snake_case (예: `about_camera`, `about_auth`)
- **클래스명**: PascalCase (예: `CameraScreen`, `AuthController`)

### 클래스 구조
```dart
class ExampleController extends ChangeNotifier {
  // 1. Private 멤버 변수
  final ExampleModel _model = ExampleModel();
  bool _isLoading = false;
  
  // 2. Getter들
  bool get isLoading => _isLoading;
  
  // 3. Public 메서드들
  Future<void> publicMethod() async {
    // 구현
  }
  
  // 4. Private 메서드들
  void _privateMethod() {
    // 구현
  }
  
  // 5. dispose (필수)
  @override
  void dispose() {
    super.dispose();
  }
}
```

### 상태 관리 패턴
- **Controller**: ChangeNotifier 상속, UI 상태 관리
- **Model**: 비즈니스 로직, Firebase 연동
- **View**: Consumer<Controller> 사용

### 에러 처리
```dart
try {
  // 비즈니스 로직
} catch (e) {
  debugPrint('❌ Error: $e');
  // 사용자 친화적 메시지
}
```

### 로깅 컨벤션
- `debugPrint('📱 정보')` - 일반 정보
- `debugPrint('🎯 성공')` - 성공 로그
- `debugPrint('❌ 에러')` - 에러 로그
- `debugPrint('⚠️ 경고')` - 경고 로그

### 주석 스타일
- 클래스: `/// 클래스 설명`
- 메서드: `// 메서드 설명`
- 복잡한 로직: 인라인 주석 추가