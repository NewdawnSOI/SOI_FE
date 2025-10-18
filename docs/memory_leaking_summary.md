# SOI 저장소 `lib` 폴더 메모리 누수 분석

## 개요

SOI 저장소의 `lib` 폴더에는 Flutter 애플리케이션의 핵심 비즈니스 로직을 담당하는 많은 컨트롤러와 서비스가 존재합니다.  
컨트롤러들은 사용자 인터페이스와 리포지토리 사이를 연결하며, 서비스는 여러 도메인의 비즈니스 규칙을 캡슐화합니다.  
본 문서는 메모리 누수, 특히 **싱글턴을 통한 순환 참조**로 인한 장기적인 메모리 점유 여부를 분석합니다.

---

## 컨트롤러 분석

대다수 컨트롤러들은 `ChangeNotifier`와 `StreamSubscription`을 활용하고 있으며, 리소스를 적절히 관리하고 있습니다.

- **PhotoController** – 사진 스트림 구독을 `_photosSubscription`에 저장하고 `dispose()`에서 구독을 취소하여 메모리 해제를 보장합니다.
- **FriendRequestController** – 모든 스트림 구독을 `dispose()`에서 해제.
- **AudioController** / **CommentRecordController** – 타이머, 오디오 플레이어, 캐시 리소스까지 모두 해제.

✅ 결론적으로 컨트롤러 계층에서는 **순환 참조나 리소스 누락으로 인한 메모리 누수는 발견되지 않았습니다.**

---

## 서비스 레이어 분석

서비스 레이어에서는 싱글턴(Singleton)과 지연 초기화(Lazy initialization)를 광범위하게 사용하면서,  
서로를 참조하는 구조가 복잡하게 얽혀 있습니다. 이로 인해 **GC(가비지 컬렉션)**이 참조 해제를 하지 못하고  
서비스 인스턴스가 앱 종료 시까지 메모리에 남는 위험이 존재합니다.

### 주요 순환 참조 구조

1. **`CategoryService`**

   - `CategoryPhotoService`, `CategoryInviteService`, `CategoryMemberService` 등을 lazy init으로 보유.
   - 서비스 인스턴스들이 서로 강한 참조를 유지하는 구조의 출발점.

2. **`CategoryPhotoService → NotificationService`**

   - 싱글턴 패턴으로 구현되어 있으며, 알림 업데이트를 위해 `NotificationService`를 참조.
   - `NotificationService`는 다시 `CategoryService`를 참조함 → 순환 구조 발생.

3. **`NotificationService → CategoryService & PhotoService`**

   - `CategoryService`와 `PhotoService`를 lazy init으로 참조.
   - 결과적으로 `CategoryService → CategoryPhotoService → NotificationService → CategoryService` 형태의 루프 형성.

4. **`PhotoService → CategoryService & NotificationService`**
   - 사진 업로드 후 카테고리 대표사진과 알림을 갱신하기 위해 두 서비스를 참조.
   - `NotificationService`가 다시 `CategoryService`를 참조하여 더 긴 순환 체인 발생.

---

## 메모리 누수 가능성

이 모든 서비스가 싱글턴으로 구현되어 있고 서로를 **강한 참조(strong reference)**로 보유하기 때문에,  
이들은 GC의 수집 대상이 되지 않습니다. 따라서 서비스 객체가 앱이 종료될 때까지 해제되지 않고  
메모리
