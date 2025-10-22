# 인증 시스템 비즈니스 규칙

이 문서는 인증 시스템의 **모든 비즈니스 로직 규칙**을 정의합니다.

---

## 📋 목차

1. [회원가입 규칙](#회원가입-규칙)
2. [로그인 규칙](#로그인-규칙)
3. [프로필 관리 규칙](#프로필-관리-규칙)
4. [사용자 검색 규칙](#사용자-검색-규칙)
5. [계정 관리 규칙](#계정-관리-규칙)
6. [보안 규칙](#보안-규칙)
7. [데이터 무결성 규칙](#데이터-무결성-규칙)

---

## 회원가입 규칙

### 1. Firebase UID 검증

```java
// ✅ 필수 검증
if (firebaseUid == null || firebaseUid.isEmpty()) {
    throw new BadRequestException("Firebase UID가 필요합니다.");
}

// Firebase ID Token에서 추출한 UID와 일치 여부 확인
if (!decodedToken.getUid().equals(request.getFirebaseUid())) {
    throw new ForbiddenException("토큰과 UID가 일치하지 않습니다.");
}
```

**규칙**:

- Firebase UID는 필수 값
- ID Token에서 추출한 UID와 요청 body의 UID 일치 필수
- Firebase에서 발급한 유효한 UID인지 검증

---

### 2. 닉네임 검증

```java
// ✅ 닉네임 형식 검증
@NotBlank(message = "닉네임은 필수입니다.")
@Size(min = 1, max = 50, message = "닉네임은 1-50자여야 합니다.")
@Pattern(regexp = "^[a-zA-Z0-9_]+$",
         message = "닉네임은 영문, 숫자, 언더스코어만 가능합니다.")
private String nickname;

// ✅ 중복 확인
public void validateNickname(String nickname) {
    if (userRepository.existsByNickname(nickname)) {
        throw new ConflictException("이미 사용 중인 닉네임입니다.");
    }
}
```

**규칙**:

- 1-50자 길이
- 영문, 숫자, 언더스코어(\_)만 허용
- 대소문자 구분
- 중복 불가 (UNIQUE 제약)
- 공백 및 특수문자 불가

---

### 3. 이름 검증

```java
@NotBlank(message = "이름은 필수입니다.")
@Size(min = 1, max = 100, message = "이름은 1-100자여야 합니다.")
private String name;
```

**규칙**:

- 1-100자 길이
- 필수 입력
- 한글, 영문, 공백 허용
- Trim 처리 (앞뒤 공백 제거)

---

### 4. 전화번호 검증

```java
// ✅ 전화번호 형식 검증
@NotBlank(message = "전화번호는 필수입니다.")
@Pattern(regexp = "^01[0-9]{8,9}$",
         message = "올바른 전화번호 형식이 아닙니다.")
private String phoneNumber;

// ✅ 중복 확인
public void validatePhoneNumber(String phoneNumber) {
    Optional<User> existingUser = userRepository
        .findByPhoneNumber(phoneNumber);

    if (existingUser.isPresent()) {
        // 이미 가입된 경우 기존 계정으로 로그인 유도
        throw new ConflictException("이미 가입된 전화번호입니다.");
    }
}
```

**규칙**:

- Firebase Auth의 전화번호와 일치 필수
- 형식: `01012345678` (하이픈 없음)
- 010, 011, 016, 017, 018, 019로 시작
- 중복 불가 (UNIQUE 제약)
- 변경 불가 (전화번호 변경 시 새 계정 생성)

---

### 5. 생년월일 검증

```java
@Pattern(regexp = "^\\d{4}-\\d{2}-\\d{2}$",
         message = "생년월일 형식은 YYYY-MM-DD입니다.")
private String birthDate;

public void validateBirthDate(String birthDate) {
    LocalDate date = LocalDate.parse(birthDate);
    LocalDate now = LocalDate.now();

    // 미래 날짜 불가
    if (date.isAfter(now)) {
        throw new BadRequestException("생년월일은 미래 날짜일 수 없습니다.");
    }

    // 만 14세 이상
    if (Period.between(date, now).getYears() < 14) {
        throw new BadRequestException("만 14세 이상만 가입 가능합니다.");
    }

    // 100세 이상 불가 (실수 방지)
    if (Period.between(date, now).getYears() > 100) {
        throw new BadRequestException("올바른 생년월일을 입력해주세요.");
    }
}
```

**규칙**:

- 형식: `YYYY-MM-DD` (예: `1990-01-01`)
- 유효한 날짜인지 검증
- 미래 날짜 불가
- 만 14세 이상
- 100세 이하

---

### 6. 회원가입 트랜잭션

```java
@Transactional
public UserDTO register(RegisterRequest request, String firebaseUid) {
    // 1. 검증
    validateNickname(request.getNickname());
    validatePhoneNumber(request.getPhoneNumber());
    validateBirthDate(request.getBirthDate());

    // 2. 사용자 생성
    User user = new User();
    user.setFirebaseUid(firebaseUid);
    user.setNickname(request.getNickname());
    user.setName(request.getName());
    user.setPhoneNumber(request.getPhoneNumber());
    user.setBirthDate(LocalDate.parse(request.getBirthDate()));
    user.setIsDeactivated(false);

    // 3. DB 저장
    User savedUser = userRepository.save(user);

    // 4. DTO 변환
    return UserDTO.from(savedUser);
}
```

**규칙**:

- 모든 검증을 먼저 수행
- 트랜잭션으로 원자성 보장
- 실패 시 롤백
- 성공 시 UserDTO 반환

---

## 로그인 규칙

### 1. Firebase ID Token 검증

```java
public String verifyIdToken(String idToken) {
    try {
        FirebaseToken decodedToken = FirebaseAuth.getInstance()
            .verifyIdToken(idToken);

        // UID 추출
        return decodedToken.getUid();
    } catch (FirebaseAuthException e) {
        if (e.getErrorCode().equals("id-token-expired")) {
            throw new UnauthorizedException("토큰이 만료되었습니다.");
        } else if (e.getErrorCode().equals("id-token-revoked")) {
            throw new UnauthorizedException("토큰이 취소되었습니다.");
        } else {
            throw new UnauthorizedException("유효하지 않은 토큰입니다.");
        }
    }
}
```

**규칙**:

- 모든 API 요청에서 ID Token 검증 필수
- 만료된 토큰 거부 (1시간 유효기간)
- 변조된 토큰 자동 탐지
- 취소된 토큰 거부

---

### 2. 사용자 존재 확인

```java
public User getUserByFirebaseUid(String firebaseUid) {
    return userRepository.findByFirebaseUid(firebaseUid)
        .orElseThrow(() -> new NotFoundException(
            "가입되지 않은 사용자입니다. 회원가입을 먼저 진행해주세요."
        ));
}
```

**규칙**:

- Firebase UID로 사용자 조회
- 존재하지 않으면 404 에러
- 회원가입 필요 메시지 반환

---

### 3. 계정 활성화 상태 확인

```java
public void checkAccountStatus(User user) {
    if (user.getIsDeactivated()) {
        throw new ForbiddenException(
            "비활성화된 계정입니다. 고객센터에 문의해주세요."
        );
    }
}
```

**규칙**:

- 비활성화된 계정은 로그인 불가
- 403 Forbidden 응답
- 활성화 필요 안내

---

### 4. 마지막 로그인 시간 업데이트

```java
@Transactional
public UserDTO login(String firebaseUid) {
    User user = getUserByFirebaseUid(firebaseUid);
    checkAccountStatus(user);

    // 마지막 로그인 시간 업데이트
    user.setLastLogin(LocalDateTime.now());
    userRepository.save(user);

    return UserDTO.from(user);
}
```

**규칙**:

- 로그인 성공 시 `last_login` 자동 업데이트
- 현재 시간으로 기록
- 트랜잭션 보장

---

## 프로필 관리 규칙

### 1. 프로필 이미지 파일 검증

```java
public void validateProfileImage(MultipartFile file) {
    // 파일 크기 검증 (최대 10MB)
    if (file.getSize() > 10 * 1024 * 1024) {
        throw new BadRequestException("파일 크기는 10MB 이하여야 합니다.");
    }

    // 파일 형식 검증
    String contentType = file.getContentType();
    List<String> allowedTypes = Arrays.asList(
        "image/jpeg", "image/png", "image/webp"
    );

    if (!allowedTypes.contains(contentType)) {
        throw new BadRequestException(
            "JPG, PNG, WEBP 형식만 업로드 가능합니다."
        );
    }

    // 파일 존재 확인
    if (file.isEmpty()) {
        throw new BadRequestException("파일이 비어있습니다.");
    }
}
```

**규칙**:

- 최대 파일 크기: 10MB
- 허용 형식: JPG, PNG, WEBP
- 파일 비어있으면 거부
- 악성 파일 검사 (선택)

---

### 2. 이미지 리사이징

```java
public BufferedImage resizeImage(BufferedImage original) {
    int targetWidth = 1024;
    int targetHeight = 1024;

    Image scaledImage = original.getScaledInstance(
        targetWidth, targetHeight, Image.SCALE_SMOOTH
    );

    BufferedImage resized = new BufferedImage(
        targetWidth, targetHeight, BufferedImage.TYPE_INT_RGB
    );

    Graphics2D g = resized.createGraphics();
    g.drawImage(scaledImage, 0, 0, null);
    g.dispose();

    return resized;
}
```

**규칙**:

- 모든 이미지를 1024x1024px로 리사이징
- 비율 유지하며 크롭
- JPEG 품질: 85%
- 백엔드에서 자동 처리

---

### 3. 기존 이미지 삭제

```java
@Transactional
public String updateProfileImage(String userId, MultipartFile file) {
    User user = userRepository.findById(userId)
        .orElseThrow(() -> new NotFoundException("사용자를 찾을 수 없습니다."));

    // 1. 새 이미지 업로드
    String newImageUrl = s3Service.upload(file, "profiles/" + userId);

    // 2. 기존 이미지 삭제 (있는 경우)
    if (user.getProfileImageUrl() != null &&
        !user.getProfileImageUrl().isEmpty()) {
        s3Service.delete(user.getProfileImageUrl());
    }

    // 3. DB 업데이트
    user.setProfileImageUrl(newImageUrl);
    userRepository.save(user);

    return newImageUrl;
}
```

**규칙**:

- 새 이미지 업로드 먼저 수행
- 업로드 성공 시 기존 이미지 삭제
- Storage와 DB 동기화
- 트랜잭션 보장

---

### 4. 사용자 정보 수정 권한

```java
public void checkUpdatePermission(String requestUserId, String targetUserId) {
    if (!requestUserId.equals(targetUserId)) {
        throw new ForbiddenException("본인의 정보만 수정할 수 있습니다.");
    }
}
```

**규칙**:

- 본인 정보만 수정 가능
- 다른 사용자 정보 수정 시 403 에러
- 관리자 권한 별도 처리 (선택)

---

### 5. 수정 가능한 필드

```java
public User updateUserInfo(String userId, UpdateUserRequest request) {
    User user = userRepository.findById(userId)
        .orElseThrow(() -> new NotFoundException("사용자를 찾을 수 없습니다."));

    // ✅ 수정 가능한 필드
    if (request.getName() != null) {
        user.setName(request.getName());
    }

    if (request.getBirthDate() != null) {
        user.setBirthDate(LocalDate.parse(request.getBirthDate()));
    }

    // ❌ 수정 불가능한 필드
    // - firebaseUid (변경 불가)
    // - nickname (변경 불가, 또는 별도 API)
    // - phoneNumber (변경 불가)
    // - createdAt (변경 불가)

    return userRepository.save(user);
}
```

**수정 가능**:

- name (이름)
- birthDate (생년월일)
- profileImageUrl (프로필 이미지)

**수정 불가**:

- firebaseUid (영구 식별자)
- nickname (고유 ID, 변경 시 별도 API)
- phoneNumber (Firebase Auth 종속)
- createdAt (생성 시간)

---

## 사용자 검색 규칙

### 1. 검색 쿼리 검증

```java
@Min(value = 1, message = "검색어는 최소 1자 이상이어야 합니다.")
@Max(value = 50, message = "검색어는 최대 50자 이하여야 합니다.")
private String query;

public void validateSearchQuery(String query) {
    if (query == null || query.trim().isEmpty()) {
        throw new BadRequestException("검색어를 입력해주세요.");
    }

    if (query.length() > 50) {
        throw new BadRequestException("검색어는 50자 이하여야 합니다.");
    }
}
```

**규칙**:

- 최소 1자 이상
- 최대 50자 이하
- Trim 처리 (공백 제거)
- SQL Injection 방지

---

### 2. 검색 필터링

```java
public List<UserSearchDTO> searchUsers(String query, String currentUserId) {
    return userRepository.searchByNickname(query).stream()
        .filter(user -> !user.getId().equals(currentUserId)) // 본인 제외
        .filter(user -> !user.getIsDeactivated()) // 비활성화 계정 제외
        .limit(50) // 최대 50개
        .map(UserSearchDTO::from)
        .collect(Collectors.toList());
}
```

**규칙**:

- 본인 제외
- 비활성화 계정 제외
- 최대 50개 결과 반환
- 닉네임 부분 일치 검색 (LIKE '%query%')

---

### 3. 검색 성능 최적화

```sql
-- 인덱스 생성
CREATE INDEX idx_users_nickname ON users(nickname);

-- Full-text 인덱스 (MySQL)
CREATE FULLTEXT INDEX idx_users_nickname_ft ON users(nickname);

-- 쿼리 예시
SELECT * FROM users
WHERE nickname LIKE CONCAT('%', ?, '%')
  AND is_deactivated = FALSE
  AND id != ?
LIMIT 50;
```

**규칙**:

- nickname 컬럼에 인덱스 생성
- Full-text 검색 활용 (MySQL 5.7+)
- LIMIT으로 결과 제한
- 커버링 인덱스 활용

---

## 계정 관리 규칙

### 1. 계정 비활성화

```java
@Transactional
public void deactivateAccount(String userId) {
    User user = userRepository.findById(userId)
        .orElseThrow(() -> new NotFoundException("사용자를 찾을 수 없습니다."));

    // 비활성화 상태로 변경
    user.setIsDeactivated(true);
    userRepository.save(user);

    // 업로드한 사진/오디오 비활성화
    photoService.deactivateUserPhotos(userId);
    audioService.deactivateUserAudios(userId);

    // 알림 비활성화
    notificationService.disableNotifications(userId);
}
```

**규칙**:

- `is_deactivated` 플래그를 `true`로 변경
- 사용자 데이터는 유지
- 업로드한 콘텐츠 숨김 처리
- 로그인 불가
- 재활성화 가능

---

### 2. 계정 활성화

```java
@Transactional
public void activateAccount(String userId) {
    User user = userRepository.findById(userId)
        .orElseThrow(() -> new NotFoundException("사용자를 찾을 수 없습니다."));

    // 활성화 상태로 변경
    user.setIsDeactivated(false);
    userRepository.save(user);

    // 업로드한 사진/오디오 재활성화
    photoService.activateUserPhotos(userId);
    audioService.activateUserAudios(userId);

    // 알림 재활성화
    notificationService.enableNotifications(userId);
}
```

**규칙**:

- `is_deactivated` 플래그를 `false`로 변경
- 모든 콘텐츠 복원
- 로그인 가능
- 친구 관계 유지

---

### 3. 회원 탈퇴 (데이터 완전 삭제)

```java
@Transactional
public void deleteAccount(String userId) {
    User user = userRepository.findById(userId)
        .orElseThrow(() -> new NotFoundException("사용자를 찾을 수 없습니다."));

    // 1. 카테고리 멤버 관계 삭제
    categoryMemberService.removeUserFromAllCategories(userId);

    // 2. 친구 관계 삭제
    friendService.deleteAllFriendships(userId);

    // 3. 업로드한 사진/오디오 삭제
    photoService.deleteUserPhotos(userId);
    audioService.deleteUserAudios(userId);

    // 4. Storage 파일 삭제
    s3Service.deleteUserFiles(userId);

    // 5. 알림 삭제
    notificationService.deleteUserNotifications(userId);

    // 6. 사용자 정보 삭제
    userRepository.delete(user);

    // 7. Firebase Auth 유지 (재가입 방지)
    // Firebase Admin SDK로 사용자 비활성화 (선택)
}
```

**규칙**:

- 모든 관계 데이터 삭제 (CASCADE)
- Storage 파일 물리 삭제
- 트랜잭션으로 원자성 보장
- 실패 시 전체 롤백
- Firebase Auth는 유지 (재가입 방지)

---

### 4. 탈퇴 제한 조건

```java
public void checkDeleteRestrictions(String userId) {
    // 진행 중인 카테고리 확인
    List<Category> activeCategories = categoryService
        .getActiveCategoriesByUser(userId);

    if (!activeCategories.isEmpty()) {
        throw new ConflictException(
            "카테고리에서 나간 후 탈퇴할 수 있습니다."
        );
    }

    // 미처리 알림 확인 (선택)
    long pendingNotifications = notificationService
        .countPendingNotifications(userId);

    if (pendingNotifications > 0) {
        // 경고 메시지만 표시
        log.warn("사용자 {}에게 {}개의 미처리 알림이 있습니다.",
                 userId, pendingNotifications);
    }
}
```

**규칙**:

- 카테고리 멤버인 경우 탈퇴 불가 (먼저 나가기 필요)
- 미처리 알림은 경고만 표시 (차단 안함)
- 진행 중인 거래 확인 (선택)

---

## 보안 규칙

### 1. Rate Limiting

```java
@RateLimit(maxRequests = 60, timeWindow = "1m")
public class AuthController {

    @PostMapping("/register")
    @RateLimit(maxRequests = 5, timeWindow = "1h") // 회원가입은 더 엄격
    public ResponseEntity<?> register(...) {
        // ...
    }

    @PostMapping("/me/profile-image")
    @RateLimit(maxRequests = 10, timeWindow = "1h") // 이미지 업로드 제한
    public ResponseEntity<?> uploadProfileImage(...) {
        // ...
    }
}
```

**규칙**:

- 일반 API: 분당 60회
- 회원가입: 시간당 5회
- 이미지 업로드: 시간당 10회
- 검색 API: 분당 30회

---

### 2. 데이터 접근 제어

```java
@PreAuthorize("@securityService.isOwner(#userId)")
public UserDTO getUserInfo(String userId) {
    // 본인 정보만 조회 가능
}

@PreAuthorize("@securityService.isOwnerOrAdmin(#userId)")
public void updateUser(String userId, UpdateUserRequest request) {
    // 본인 또는 관리자만 수정 가능
}
```

**규칙**:

- 본인 정보만 조회/수정 가능
- 관리자는 모든 정보 접근 가능
- 다른 사용자 정보 접근 시 403 에러

---

### 3. 민감 정보 보호

```java
public class UserDTO {
    private Long id;
    private String nickname;
    private String name;
    private String profileImageUrl;

    // ❌ 클라이언트에 노출하지 않는 정보
    // private String firebaseUid;
    // private String phoneNumber;
    // private LocalDate birthDate;
    // private boolean isDeactivated;
}

// 본인 정보 조회 시에만 전체 정보 반환
public class UserDetailDTO extends UserDTO {
    private String phoneNumber; // 본인만 조회 가능
    private LocalDate birthDate; // 본인만 조회 가능
    private LocalDateTime createdAt;
    private LocalDateTime lastLogin;
}
```

**규칙**:

- firebaseUid는 클라이언트에 노출 금지
- phoneNumber는 본인만 조회 가능
- birthDate는 본인만 조회 가능
- 검색 결과에는 최소 정보만 반환

---

## 데이터 무결성 규칙

### 1. UNIQUE 제약

```sql
CREATE TABLE users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    firebase_uid VARCHAR(128) UNIQUE NOT NULL,
    nickname VARCHAR(50) UNIQUE NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    ...
);
```

**규칙**:

- firebase_uid: UNIQUE (한 명당 하나의 계정)
- nickname: UNIQUE (중복 불가)
- phone_number: UNIQUE (하나의 번호로 하나의 계정)

---

### 2. NOT NULL 제약

```sql
firebase_uid VARCHAR(128) NOT NULL,
nickname VARCHAR(50) NOT NULL,
name VARCHAR(100) NOT NULL,
phone_number VARCHAR(20) NOT NULL,
is_deactivated BOOLEAN NOT NULL DEFAULT FALSE,
created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
```

**규칙**:

- 필수 필드는 모두 NOT NULL
- DEFAULT 값 지정
- 애플리케이션 레벨에서도 검증

---

### 3. CASCADE 삭제

```sql
-- 카테고리 멤버 관계
ALTER TABLE category_members
ADD CONSTRAINT fk_member_user
FOREIGN KEY (user_id) REFERENCES users(id)
ON DELETE CASCADE;

-- 친구 관계
ALTER TABLE friendships
ADD CONSTRAINT fk_friendship_user
FOREIGN KEY (user_id) REFERENCES users(id)
ON DELETE CASCADE;
```

**규칙**:

- 사용자 삭제 시 모든 관계 자동 삭제
- CASCADE로 데이터 정합성 보장
- 애플리케이션 레벨에서도 명시적 삭제

---

### 4. 트랜잭션 격리 수준

```java
@Transactional(isolation = Isolation.READ_COMMITTED)
public UserDTO register(RegisterRequest request) {
    // 회원가입 로직
}

@Transactional(isolation = Isolation.REPEATABLE_READ)
public void deleteAccount(String userId) {
    // 회원 탈퇴 로직 (더 높은 격리 수준)
}
```

**규칙**:

- 기본: READ_COMMITTED (성능 우선)
- 삭제/수정: REPEATABLE_READ (정합성 우선)
- Dead Lock 방지

---

## 다음 문서

👉 **[API 엔드포인트](./03-api-endpoints.md)** - REST API 명세
