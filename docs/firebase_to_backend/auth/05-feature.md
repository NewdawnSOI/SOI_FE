# 인증 시스템 기능별 상세 명세

이 문서는 **인증 시스템의 각 기능**을 입력/출력/처리 과정으로 상세히 정리합니다.

---

## 📋 목차

1. [회원가입](#1-회원가입)
2. [로그인](#2-로그인)
3. [내 정보 조회](#3-내-정보-조회)
4. [프로필 이미지 업로드](#4-프로필-이미지-업로드)
5. [사용자 정보 수정](#5-사용자-정보-수정)
6. [닉네임 검색](#6-닉네임-검색)
7. [닉네임 중복 확인](#7-닉네임-중복-확인)
8. [회원 탈퇴](#8-회원-탈퇴)

---

## 1. 회원가입

### 입력 (Input)

```json
{
  "firebaseUid": "abc123xyz...",
  "idToken": "eyJhbGciOiJSUzI1NiI...",
  "nickname": "hong123",
  "name": "홍길동",
  "phoneNumber": "01012345678",
  "birthDate": "1990-01-01"
}
```

### 처리 과정 (Process)

#### 1단계: Firebase ID Token 검증

```java
public String verifyIdToken(String idToken) throws FirebaseAuthException {
    // Firebase Admin SDK로 토큰 검증
    FirebaseToken decodedToken = FirebaseAuth.getInstance()
        .verifyIdToken(idToken);

    // UID 추출
    String firebaseUid = decodedToken.getUid();

    // 토큰 만료 확인
    if (decodedToken.isExpired()) {
        throw new UnauthorizedException("토큰이 만료되었습니다.");
    }

    return firebaseUid;
}
```

#### 2단계: UID 일치 확인

```java
public void validateUidMatch(String tokenUid, String requestUid) {
    if (!tokenUid.equals(requestUid)) {
        throw new ForbiddenException(
            "토큰의 UID와 요청의 UID가 일치하지 않습니다."
        );
    }
}
```

#### 3단계: 닉네임 중복 확인

```java
public void validateNickname(String nickname) {
    // 형식 검증
    if (!nickname.matches("^[a-zA-Z0-9_]+$")) {
        throw new BadRequestException(
            "닉네임은 영문, 숫자, 언더스코어만 사용 가능합니다."
        );
    }

    if (nickname.length() < 1 || nickname.length() > 50) {
        throw new BadRequestException("닉네임은 1-50자여야 합니다.");
    }

    // 중복 확인
    if (userRepository.existsByNickname(nickname)) {
        throw new ConflictException("이미 사용 중인 닉네임입니다.");
    }
}
```

#### 4단계: 전화번호 중복 확인

```java
public void validatePhoneNumber(String phoneNumber) {
    // 형식 검증
    if (!phoneNumber.matches("^01[0-9]{8,9}$")) {
        throw new BadRequestException("올바른 전화번호 형식이 아닙니다.");
    }

    // 중복 확인
    Optional<User> existingUser = userRepository
        .findByPhoneNumber(phoneNumber);

    if (existingUser.isPresent()) {
        throw new ConflictException(
            "이미 가입된 전화번호입니다. 로그인을 진행해주세요."
        );
    }
}
```

#### 5단계: 생년월일 검증

```java
public void validateBirthDate(String birthDateStr) {
    LocalDate birthDate = LocalDate.parse(birthDateStr);
    LocalDate now = LocalDate.now();

    // 미래 날짜 불가
    if (birthDate.isAfter(now)) {
        throw new BadRequestException("생년월일은 미래 날짜일 수 없습니다.");
    }

    // 만 14세 이상
    int age = Period.between(birthDate, now).getYears();
    if (age < 14) {
        throw new BadRequestException("만 14세 이상만 가입 가능합니다.");
    }

    // 100세 이하
    if (age > 100) {
        throw new BadRequestException("올바른 생년월일을 입력해주세요.");
    }
}
```

#### 6단계: 사용자 생성 및 저장

```java
@Transactional
public UserDetailDTO register(RegisterRequest request) {
    // 1. 토큰 검증
    String firebaseUid = verifyIdToken(request.getIdToken());
    validateUidMatch(firebaseUid, request.getFirebaseUid());

    // 2. 입력 검증
    validateNickname(request.getNickname());
    validatePhoneNumber(request.getPhoneNumber());
    if (request.getBirthDate() != null) {
        validateBirthDate(request.getBirthDate());
    }

    // 3. User 엔티티 생성
    User user = new User();
    user.setFirebaseUid(firebaseUid);
    user.setNickname(request.getNickname());
    user.setName(request.getName().trim());
    user.setPhoneNumber(request.getPhoneNumber());

    if (request.getBirthDate() != null) {
        user.setBirthDate(LocalDate.parse(request.getBirthDate()));
    }

    user.setIsDeactivated(false);

    // 4. DB 저장
    User savedUser = userRepository.save(user);

    // 5. 환영 알림 전송 (선택)
    notificationService.sendWelcomeNotification(savedUser.getId());

    // 6. DTO 변환 및 반환
    return UserDetailDTO.from(savedUser);
}
```

### 출력 (Output)

```json
{
  "success": true,
  "data": {
    "id": 123,
    "firebaseUid": "abc123xyz...",
    "nickname": "hong123",
    "name": "홍길동",
    "phoneNumber": "01012345678",
    "birthDate": "1990-01-01",
    "profileImageUrl": null,
    "isDeactivated": false,
    "createdAt": "2025-01-15T10:00:00Z",
    "lastLogin": "2025-01-15T10:00:00Z"
  },
  "message": "회원가입이 완료되었습니다."
}
```

---

## 2. 로그인

### 입력 (Input)

```json
{
  "firebaseUid": "abc123xyz...",
  "idToken": "eyJhbGciOiJSUzI1NiI..."
}
```

### 처리 과정 (Process)

#### 1단계: Firebase ID Token 검증

```java
String firebaseUid = verifyIdToken(request.getIdToken());
validateUidMatch(firebaseUid, request.getFirebaseUid());
```

#### 2단계: 사용자 조회

```java
public User getUserByFirebaseUid(String firebaseUid) {
    return userRepository.findByFirebaseUid(firebaseUid)
        .orElseThrow(() -> new NotFoundException(
            "가입되지 않은 사용자입니다. 회원가입을 먼저 진행해주세요."
        ));
}
```

#### 3단계: 계정 활성화 상태 확인

```java
public void checkAccountStatus(User user) {
    if (user.getIsDeactivated()) {
        throw new ForbiddenException(
            "비활성화된 계정입니다. 고객센터에 문의해주세요."
        );
    }
}
```

#### 4단계: 마지막 로그인 시간 업데이트

```java
@Transactional
public UserDetailDTO login(LoginRequest request) {
    // 1. 토큰 검증
    String firebaseUid = verifyIdToken(request.getIdToken());
    validateUidMatch(firebaseUid, request.getFirebaseUid());

    // 2. 사용자 조회
    User user = getUserByFirebaseUid(firebaseUid);

    // 3. 계정 상태 확인
    checkAccountStatus(user);

    // 4. 마지막 로그인 시간 업데이트
    user.setLastLogin(LocalDateTime.now());
    userRepository.save(user);

    // 5. DTO 반환
    return UserDetailDTO.from(user);
}
```

### 출력 (Output)

```json
{
  "success": true,
  "data": {
    "id": 123,
    "nickname": "hong123",
    "name": "홍길동",
    "phoneNumber": "01012345678",
    "profileImageUrl": "https://...",
    "lastLogin": "2025-01-15T10:00:00Z"
  },
  "message": "로그인 성공"
}
```

---

## 3. 내 정보 조회

### 입력 (Input)

```
GET /users/me
Authorization: Bearer eyJhbGciOiJSUzI1NiI...
```

### 처리 과정 (Process)

```java
@GetMapping("/me")
public ResponseEntity<UserDetailDTO> getMyInfo(
    @RequestHeader("Authorization") String authHeader
) {
    // 1. Bearer 토큰 추출
    String idToken = authHeader.substring(7); // "Bearer " 제거

    // 2. 토큰 검증 및 UID 추출
    String firebaseUid = verifyIdToken(idToken);

    // 3. 사용자 조회
    User user = getUserByFirebaseUid(firebaseUid);

    // 4. 상세 정보 반환 (본인 정보이므로 전체 공개)
    return ResponseEntity.ok(UserDetailDTO.from(user));
}
```

### 출력 (Output)

```json
{
  "success": true,
  "data": {
    "id": 123,
    "nickname": "hong123",
    "name": "홍길동",
    "phoneNumber": "01012345678",
    "birthDate": "1990-01-01",
    "profileImageUrl": "https://...",
    "isDeactivated": false,
    "createdAt": "2025-01-01T10:00:00Z",
    "lastLogin": "2025-01-15T10:00:00Z",
    "updatedAt": "2025-01-15T10:00:00Z"
  }
}
```

---

## 4. 프로필 이미지 업로드

### 입력 (Input)

```
POST /users/me/profile-image
Authorization: Bearer eyJhbGciOiJSUzI1NiI...
Content-Type: multipart/form-data

imageFile: <binary>
```

### 처리 과정 (Process)

#### 1단계: 파일 검증

```java
public void validateImageFile(MultipartFile file) {
    // 파일 존재 확인
    if (file.isEmpty()) {
        throw new BadRequestException("파일이 비어있습니다.");
    }

    // 파일 크기 확인 (최대 10MB)
    if (file.getSize() > 10 * 1024 * 1024) {
        throw new BadRequestException("파일 크기는 10MB 이하여야 합니다.");
    }

    // 파일 형식 확인
    String contentType = file.getContentType();
    List<String> allowedTypes = Arrays.asList(
        "image/jpeg", "image/png", "image/webp"
    );

    if (!allowedTypes.contains(contentType)) {
        throw new BadRequestException(
            "JPG, PNG, WEBP 형식만 업로드 가능합니다."
        );
    }
}
```

#### 2단계: 이미지 리사이징

```java
public BufferedImage resizeImage(MultipartFile file) throws IOException {
    BufferedImage original = ImageIO.read(file.getInputStream());

    int targetWidth = 1024;
    int targetHeight = 1024;

    Image scaledImage = original.getScaledInstance(
        targetWidth, targetHeight, Image.SCALE_SMOOTH
    );

    BufferedImage resized = new BufferedImage(
        targetWidth, targetHeight, BufferedImage.TYPE_INT_RGB
    );

    Graphics2D g = resized.createGraphics();
    g.setRenderingHint(
        RenderingHints.KEY_INTERPOLATION,
        RenderingHints.VALUE_INTERPOLATION_BILINEAR
    );
    g.drawImage(scaledImage, 0, 0, null);
    g.dispose();

    return resized;
}
```

#### 3단계: S3 업로드 및 기존 이미지 삭제

```java
@Transactional
public ProfileImageResponse uploadProfileImage(
    String firebaseUid,
    MultipartFile file
) {
    // 1. 사용자 조회
    User user = getUserByFirebaseUid(firebaseUid);

    // 2. 파일 검증
    validateImageFile(file);

    // 3. 이미지 리사이징
    BufferedImage resized = resizeImage(file);

    // 4. S3 업로드
    String fileName = String.format(
        "profiles/%s/profile_%d.jpg",
        user.getId(),
        System.currentTimeMillis()
    );

    ByteArrayOutputStream os = new ByteArrayOutputStream();
    ImageIO.write(resized, "jpg", os);
    InputStream is = new ByteArrayInputStream(os.toByteArray());

    String newImageUrl = s3Service.upload(is, fileName, "image/jpeg");

    // 5. 기존 이미지 삭제 (있는 경우)
    if (user.getProfileImageUrl() != null &&
        !user.getProfileImageUrl().isEmpty()) {
        try {
            s3Service.delete(user.getProfileImageUrl());
        } catch (Exception e) {
            log.warn("기존 프로필 이미지 삭제 실패: {}", e.getMessage());
        }
    }

    // 6. DB 업데이트
    user.setProfileImageUrl(newImageUrl);
    userRepository.save(user);

    // 7. 응답
    return new ProfileImageResponse(newImageUrl);
}
```

### 출력 (Output)

```json
{
  "success": true,
  "data": {
    "profileImageUrl": "https://s3.amazonaws.com/.../profiles/123/profile_1234567890.jpg"
  },
  "message": "프로필 이미지가 변경되었습니다."
}
```

---

## 5. 사용자 정보 수정

### 입력 (Input)

```json
{
  "name": "홍길순",
  "birthDate": "1990-01-02"
}
```

### 처리 과정 (Process)

```java
@Transactional
public UserDetailDTO updateUserInfo(
    String firebaseUid,
    UpdateUserRequest request
) {
    // 1. 사용자 조회
    User user = getUserByFirebaseUid(firebaseUid);

    // 2. 수정 가능한 필드 업데이트
    if (request.getName() != null && !request.getName().trim().isEmpty()) {
        if (request.getName().length() > 100) {
            throw new BadRequestException("이름은 100자 이하여야 합니다.");
        }
        user.setName(request.getName().trim());
    }

    if (request.getBirthDate() != null) {
        validateBirthDate(request.getBirthDate());
        user.setBirthDate(LocalDate.parse(request.getBirthDate()));
    }

    // 3. DB 저장
    userRepository.save(user);

    // 4. DTO 반환
    return UserDetailDTO.from(user);
}
```

### 출력 (Output)

```json
{
  "success": true,
  "data": {
    "id": 123,
    "nickname": "hong123",
    "name": "홍길순",
    "birthDate": "1990-01-02",
    "updatedAt": "2025-01-15T11:00:00Z"
  },
  "message": "정보가 수정되었습니다."
}
```

---

## 6. 닉네임 검색

### 입력 (Input)

```
GET /users/search?nickname=hong&page=0&size=20
Authorization: Bearer eyJhbGciOiJSUzI1NiI...
```

### 처리 과정 (Process)

```java
@GetMapping("/search")
public ResponseEntity<Page<UserSearchDTO>> searchUsers(
    @RequestParam String nickname,
    @RequestParam(defaultValue = "0") int page,
    @RequestParam(defaultValue = "20") int size,
    @RequestHeader("Authorization") String authHeader
) {
    // 1. 토큰 검증 및 현재 사용자 확인
    String idToken = authHeader.substring(7);
    String firebaseUid = verifyIdToken(idToken);
    User currentUser = getUserByFirebaseUid(firebaseUid);

    // 2. 검색어 검증
    if (nickname == null || nickname.trim().isEmpty()) {
        throw new BadRequestException("검색어를 입력해주세요.");
    }

    if (nickname.length() > 50) {
        throw new BadRequestException("검색어는 50자 이하여야 합니다.");
    }

    // 3. 페이지네이션 설정
    Pageable pageable = PageRequest.of(page, Math.min(size, 50));

    // 4. DB 검색 (LIKE 쿼리)
    Page<User> users = userRepository.searchByNicknameContaining(
        nickname.trim(),
        currentUser.getId(),
        pageable
    );

    // 5. DTO 변환
    Page<UserSearchDTO> dtos = users.map(UserSearchDTO::from);

    return ResponseEntity.ok(dtos);
}
```

#### Repository 쿼리

```java
@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    @Query("SELECT u FROM User u " +
           "WHERE u.nickname LIKE %:nickname% " +
           "AND u.id != :currentUserId " +
           "AND u.isDeactivated = FALSE " +
           "ORDER BY u.nickname ASC")
    Page<User> searchByNicknameContaining(
        @Param("nickname") String nickname,
        @Param("currentUserId") Long currentUserId,
        Pageable pageable
    );
}
```

### 출력 (Output)

```json
{
  "success": true,
  "data": {
    "users": [
      {
        "id": 123,
        "nickname": "hong123",
        "name": "홍길동",
        "profileImageUrl": "https://..."
      },
      {
        "id": 456,
        "nickname": "hong456",
        "name": "홍길순",
        "profileImageUrl": "https://..."
      }
    ],
    "totalElements": 2,
    "totalPages": 1,
    "currentPage": 0,
    "size": 20
  }
}
```

---

## 7. 닉네임 중복 확인

### 입력 (Input)

```json
{
  "nickname": "hong123"
}
```

### 처리 과정 (Process)

```java
@PostMapping("/check-duplicate")
public ResponseEntity<CheckDuplicateResponse> checkDuplicate(
    @Valid @RequestBody CheckDuplicateRequest request
) {
    // 1. 닉네임 검증
    String nickname = request.getNickname().trim();

    // 2. 중복 확인
    boolean exists = userRepository.existsByNickname(nickname);

    // 3. 응답 생성
    CheckDuplicateResponse response;
    if (exists) {
        response = CheckDuplicateResponse.notAvailable();
    } else {
        response = CheckDuplicateResponse.available();
    }

    return ResponseEntity.ok(response);
}
```

### 출력 (Output)

#### 중복인 경우

```json
{
  "success": true,
  "data": {
    "available": false,
    "message": "이미 사용 중인 닉네임입니다."
  }
}
```

#### 사용 가능한 경우

```json
{
  "success": true,
  "data": {
    "available": true,
    "message": "사용 가능한 닉네임입니다."
  }
}
```

---

## 8. 회원 탈퇴

### 입력 (Input)

```
DELETE /users/me
Authorization: Bearer eyJhbGciOiJSUzI1NiI...
```

### 처리 과정 (Process)

```java
@Transactional
public void deleteAccount(String firebaseUid) {
    // 1. 사용자 조회
    User user = getUserByFirebaseUid(firebaseUid);

    log.info("회원 탈퇴 시작: userId={}, firebaseUid={}", user.getId(), firebaseUid);

    // 2. 카테고리 멤버 관계 삭제 (모든 카테고리에서 강제 탈퇴)
    int deletedCategoryMembers = categoryMemberRepository.deleteByUserId(user.getId());
    log.info("카테고리 멤버 관계 삭제: {} 개", deletedCategoryMembers);

    // 3. 친구 관계 삭제 (양방향 모두)
    int deletedFriendships1 = friendshipRepository.deleteByUserId(user.getId());
    int deletedFriendships2 = friendshipRepository.deleteByFriendId(user.getId());
    log.info("친구 관계 삭제: {} + {} 개", deletedFriendships1, deletedFriendships2);

    // 4. 업로드한 사진 삭제 (Storage + DB)
    List<Photo> photos = photoRepository.findByUploaderId(user.getId());
    log.info("삭제할 사진 개수: {}", photos.size());

    for (Photo photo : photos) {
        // Storage 파일 삭제
        if (photo.getImageUrl() != null) {
            try {
                s3Service.delete(photo.getImageUrl());
            } catch (Exception e) {
                log.warn("이미지 파일 삭제 실패: {}", photo.getImageUrl(), e);
            }
        }
        if (photo.getAudioUrl() != null) {
            try {
                s3Service.delete(photo.getAudioUrl());
            } catch (Exception e) {
                log.warn("음성 파일 삭제 실패: {}", photo.getAudioUrl(), e);
            }
        }
        // DB 레코드 삭제
        photoRepository.delete(photo);
    }

    // 5. 프로필 이미지 삭제
    if (user.getProfileImageUrl() != null && !user.getProfileImageUrl().isEmpty()) {
        try {
            s3Service.delete(user.getProfileImageUrl());
            log.info("프로필 이미지 삭제 완료: {}", user.getProfileImageUrl());
        } catch (Exception e) {
            log.warn("프로필 이미지 삭제 실패: {}", user.getProfileImageUrl(), e);
        }
    }

    // 6. 알림 삭제
    int deletedNotifications = notificationRepository.deleteByUserId(user.getId());
    log.info("알림 삭제: {} 개", deletedNotifications);

    // 7. 사용자 정보 삭제 (DB)
    userRepository.delete(user);
    log.info("사용자 DB 레코드 삭제 완료: userId={}", user.getId());

    // 8. Firebase Auth 계정 삭제 (중요!)
    try {
        FirebaseAuth.getInstance().deleteUser(firebaseUid);
        log.info("Firebase Auth 계정 삭제 완료: {}", firebaseUid);
    } catch (FirebaseAuthException e) {
        // 실패해도 DB는 이미 삭제됐으므로 로그만 남김
        log.error("❌ Firebase Auth 삭제 실패 (UID: {}): {}",
            firebaseUid, e.getMessage());

        // 실패한 UID를 별도 테이블에 저장하여 배치로 재시도
        orphanedAuthRepository.save(new OrphanedAuth(firebaseUid));
    }

    log.info("회원 탈퇴 완료: firebaseUid={}", firebaseUid);
}
```

### 출력 (Output)

```json
{
  "success": true,
  "message": "회원 탈퇴가 완료되었습니다."
}
```

---

## 9. Firebase Auth 삭제 전략

### 문제 상황

회원 탈퇴 시 **백엔드 DB는 삭제했지만 Firebase Auth는 남아있는 경우**:

- 같은 전화번호로 재가입 시도 → 기존 UID로 Firebase 로그인
- `POST /auth/login` 호출 → 404 에러 (DB에 사용자 없음)
- 사용자 혼란 발생

### 해결 방법

#### 방법 1: 백엔드에서 Firebase Admin SDK로 삭제 (권장 ⭐)

```java
// Spring Boot - AuthService.java
@Transactional
public void deleteAccount(String firebaseUid) {
    // 1. DB 데이터 삭제
    User user = getUserByFirebaseUid(firebaseUid);
    deleteUserData(user);

    // 2. Firebase Auth 계정 삭제
    try {
        FirebaseAuth.getInstance().deleteUser(firebaseUid);
        log.info("Firebase Auth 계정 삭제 완료: {}", firebaseUid);
    } catch (FirebaseAuthException e) {
        log.error("Firebase Auth 삭제 실패: {}", e.getMessage());
        // 실패해도 예외를 던지지 않음 (DB는 이미 삭제됨)
    }
}
```

**장점**:

- 백엔드에서 트랜잭션으로 관리
- DB 삭제 성공 후에만 Firebase Auth 삭제
- 일관성 보장

**단점**:

- Firebase Admin SDK 설정 필요
- 네트워크 오류 시 Firebase Auth가 남을 수 있음

#### 방법 2: Flutter 앱에서도 추가 삭제 시도 (하이브리드)

```dart
// lib/services/auth_service.dart
Future<void> deleteAccount() async {
  try {
    // 1. 백엔드 API 호출 (DB + Firebase Auth 삭제)
    await authRepository.deleteAccountFromBackend();

    // 2. 클라이언트에서도 삭제 시도 (백업)
    try {
      await FirebaseAuth.instance.currentUser?.delete();
      debugPrint('✅ Firebase Auth 클라이언트 삭제 성공');
    } catch (e) {
      // 이미 백엔드에서 삭제됐을 수 있으므로 에러 무시
      debugPrint('⚠️ Firebase Auth 클라이언트 삭제 실패: $e');
    }

    // 3. 로그아웃
    await FirebaseAuth.instance.signOut();

  } catch (e) {
    throw Exception('회원 탈퇴 실패: $e');
  }
}
```

**장점**:

- 양쪽에서 모두 삭제 시도 → 성공률 높음
- 백엔드 실패 시 클라이언트에서 보완 가능

**단점**:

- 네트워크 오류 시 여전히 불일치 가능

#### 방법 3: 재가입 시 자동 처리 (최종 방어선)

Firebase Auth가 남아있어도 재가입 가능하도록 처리:

```dart
// lib/controllers/auth_controller.dart
Future<void> handlePhoneAuthComplete() async {
  final firebaseUid = FirebaseAuth.instance.currentUser!.uid;
  final idToken = await FirebaseAuth.instance.currentUser!.getIdToken();

  try {
    // 로그인 시도
    final user = await _authService.login(firebaseUid, idToken);
    _navigateToHome();

  } on NotFoundException {
    // 404 에러 → DB에 사용자 없음 → 회원가입 필요
    debugPrint('📝 DB에 사용자 없음, 회원가입 페이지로 이동');
    _navigateToSignUpPage();

  } catch (e) {
    _showError('로그인 실패: $e');
  }
}
```

**백엔드에서 동일 UID 재등록 허용**:

```java
@PostMapping("/register")
public ResponseEntity<UserDetailDTO> register(
    @Valid @RequestBody RegisterRequest request
) {
    // UID 중복 체크하지 않음 (재가입 허용)
    // 대신 phone_number UNIQUE 제약으로 중복 방지

    User user = new User();
    user.setFirebaseUid(request.getFirebaseUid());
    user.setNickname(request.getNickname());
    user.setPhoneNumber(request.getPhoneNumber());
    // ...

    User savedUser = userRepository.save(user);
    return ResponseEntity.ok(UserDetailDTO.from(savedUser));
}
```

### 권장 구현

**백엔드 (주 로직)** + **Flutter (백업)** + **재가입 처리 (방어선)**

```java
// 백엔드: Firebase Admin SDK로 삭제 시도
@Transactional
public void deleteAccount(String firebaseUid) {
    deleteUserData(firebaseUid);

    try {
        FirebaseAuth.getInstance().deleteUser(firebaseUid);
    } catch (FirebaseAuthException e) {
        log.error("Firebase Auth 삭제 실패: {}", e.getMessage());
        orphanedAuthRepository.save(new OrphanedAuth(firebaseUid));
    }
}
```

```dart
// Flutter: 클라이언트에서도 삭제
await authRepository.deleteAccountFromBackend();
await FirebaseAuth.instance.currentUser?.delete().catchError((_) {});
await FirebaseAuth.instance.signOut();
```

```dart
// 재가입 시: 404 감지하여 회원가입 페이지로
try {
  await authService.login(firebaseUid, idToken);
} on NotFoundException {
  _navigateToSignUpPage(); // 동일 UID로 재등록
}
```

이렇게 **3중 방어선**을 구축하면 어떤 상황에서도 안전합니다! ✅

---

## 요약

이 문서는 **인증 시스템의 모든 기능**을 다음과 같이 정리했습니다:

1. ✅ **입력 (Input)**: API 요청 형식
2. ✅ **처리 (Process)**: 단계별 비즈니스 로직 및 Java 코드
3. ✅ **출력 (Output)**: API 응답 형식

백엔드 개발자는 이 문서를 참고하여:

- REST API 엔드포인트 구현
- Firebase ID Token 검증 로직
- 비즈니스 로직 검증
- 트랜잭션 처리
- 에러 핸들링
- Storage 연동

을 진행할 수 있습니다.
