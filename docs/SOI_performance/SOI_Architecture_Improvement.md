# SOI 아키텍처 개선 제안서 (from Layered → MVVM-Lite)

## 1. 현재 구조 분석

SOI는 현재 다음과 같은 **5계층 구조**를 사용하고 있습니다:

```
lib/
 ┣ models/
 ┣ repositories/
 ┣ services/
 ┣ controllers/
 ┗ views/
```

이 구조는 전통적인 **계층형(Layered Architecture)** 패턴으로,  
`model → repository → service → controller → view` 흐름으로 데이터가 이동합니다.

### ✅ 장점
- 책임이 명확하게 분리되어 있음
- 중복 코드 방지, 유지보수 용이
- 서비스 단위로 기능 확장 가능

### ⚠️ 문제점 (현재 SOI의 실제 코드 기준)
1. **서비스 간 순환 참조**  
   `CategoryService ↔ NotificationService ↔ PhotoService` 등  
   모든 서비스가 싱글턴으로 서로를 참조하여 **GC 해제가 불가능한 구조** 형성.
2. **God-Class화된 서비스**  
   `CategoryService`가 40개 이상 메서드를 가지며, 도메인 로직이 분산되지 않고 집중됨.
3. **테스트 어려움**  
   Firebase와 같은 외부 의존성이 직접 코드에 들어 있어 단위 테스트 불가능.
4. **개발 속도 저하**  
   단일 화면(View) 변경 시 여러 계층 수정 필요 (Controller + Service + Repository)
5. **MVP 단계 복잡도 과도**  
   빠른 반복 실험이 필요한 시점에서 계층이 지나치게 세분화되어 있음.

---

## 2. 제안: MVVM-Lite 전환

복잡한 다층 구조를 **MVVM-Lite**로 단순화하여 다음과 같이 리팩터링을 제안합니다.

```
lib/
 ┣ data/
 ┃  ┣ repositories/
 ┃  ┃   ┣ i_photo_repository.dart
 ┃  ┃   ┣ photo_repository_firebase.dart
 ┃  ┃   ┣ i_category_repository.dart
 ┃  ┃   ┗ category_repository_firebase.dart
 ┃  ┗ datasources/
 ┃      ┗ notification_remote.dart
 ┣ domain/            # (선택) 복잡 시만
 ┃  ┗ usecases/
 ┃      ┣ add_photo.dart
 ┃      ┗ invite_member.dart
 ┣ models/
 ┗ presentation/
    ┣ feed/
    ┃  ┣ feed_view.dart
    ┃  ┗ feed_view_model.dart
    ┗ category_detail/
       ┣ category_detail_view.dart
       ┗ category_detail_view_model.dart
```

---

## 3. MVVM-Lite 구조 설명

| 계층 | 역할 | 비고 |
|------|------|------|
| **model** | 데이터 구조 정의, JSON 변환 | 순수 데이터만 유지 |
| **data** | Firebase 등 외부 데이터 접근, 인터페이스 정의 | 외부 의존성과의 경계 |
| **domain (선택)** | 복잡한 비즈니스 로직을 유스케이스로 분리 | 재사용 가능한 단위 로직 |
| **viewModel** | UI 상태 + 오케스트레이션 담당 | 기존 controller/service 대체 |
| **view** | UI 위젯 | 상태는 ViewModel이 관리 |

---

## 4. 인터페이스는 “경계”에만 사용

현재는 `service` 계층 전체가 서로를 싱글턴으로 참조하고 있습니다.  
MVVM-Lite에서는 인터페이스를 **data 경계에서만 사용**합니다.

### 예시

```dart
// data/repositories/i_photo_repository.dart
abstract class IPhotoRepository {
  Future<String> upload({required File image, required String categoryId, required String userId});
  Stream<List<Photo>> watchByCategory(String categoryId);
}

// data/repositories/photo_repository_firebase.dart
class PhotoRepositoryFirebase implements IPhotoRepository {
  @override
  Future<String> upload({required File image, required String categoryId, required String userId}) async {
    // Firebase Storage 업로드
  }

  @override
  Stream<List<Photo>> watchByCategory(String categoryId) {
    // Firestore snapshot 반환
  }
}
```

---

## 5. ViewModel 예시

```dart
// presentation/feed/feed_view_model.dart
class FeedViewModel extends ChangeNotifier {
  final IPhotoRepository photoRepo;
  final ICategoryRepository categoryRepo;

  FeedViewModel({required this.photoRepo, required this.categoryRepo});

  AsyncValue<List<Photo>> photos = const AsyncValue.loading();
  StreamSubscription? _sub;

  void start(String categoryId) {
    _sub?.cancel();
    _sub = photoRepo.watchByCategory(categoryId).listen((list) {
      photos = AsyncValue.data(list);
      notifyListeners();
    }, onError: (e) {
      photos = AsyncValue.error(e, StackTrace.current);
      notifyListeners();
    });
  }

  Future<void> addPhoto(File image, String categoryId, String userId) async {
    await photoRepo.upload(image: image, categoryId: categoryId, userId: userId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
```

---

## 6. 전환 전략 (단계적 리팩터링)

1. **Feed 화면부터 시작**  
   기존 `PhotoController`, `PhotoService` 로직을 `FeedViewModel`로 옮김.
2. **data 계층 인터페이스 정의**  
   `IPhotoRepository` → `PhotoRepositoryFirebase` 구현.
3. **DI 구성**  
   Riverpod 또는 GetIt으로 ViewModel에 repository 주입.
4. **Service 제거**  
   화면 단위로 옮길수록 기존 Service는 점차 사라짐.
5. **메모리 점검**  
   스트림, 타이머, 구독은 반드시 `dispose()`에서 해제.

---

## 7. 기대 효과

| 항목 | Before (Layered) | After (MVVM-Lite) |
|------|------------------|------------------|
| 구조 복잡도 | 높음 | 낮음 |
| 순환 참조 | 다수 발생 | 제거됨 |
| 테스트 | 어렵다 (실 Firebase 필요) | 가능 (Mock 주입) |
| 변경 용이성 | 낮음 | 높음 |
| 개발 속도 | 느림 | 빠름 |

---

## 8. 결론

SOI는 현재 **과도하게 계층화된 구조와 싱글턴 간 강한 결합**으로 인해  
유지보수성과 확장성이 떨어집니다.

따라서 MVP 이후에는 다음 방향으로 점진적 전환을 권장합니다:

> **Layered → MVVM-Lite (ViewModel 중심 구조)**  
> **인터페이스는 Data 경계에만**  
> **Service와 Controller는 ViewModel로 통합**

이로써 코드 복잡도를 낮추면서도,  
테스트 가능하고 유연한 구조로 발전시킬 수 있습니다.
