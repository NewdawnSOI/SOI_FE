# 인증 시스템 데이터 모델 설계

이 문서는 인증 시스템의 **데이터베이스 스키마**와 **DTO 구조**를 정의합니다.

---

## 📋 목차

1. [데이터베이스 설계](#데이터베이스-설계)
2. [Entity 클래스](#entity-클래스)
3. [DTO 클래스](#dto-클래스)
4. [Firebase vs Spring Boot 비교](#firebase-vs-spring-boot-비교)

---

## 데이터베이스 설계

### ERD (Entity Relationship Diagram)

```
┌─────────────────────────┐
│        users            │
├─────────────────────────┤
│ id (PK)                 │
│ firebase_uid (UNIQUE)   │
│ nickname (UNIQUE)       │
│ name                    │
│ phone_number (UNIQUE)   │
│ birth_date              │
│ profile_image_url       │
│ is_deactivated          │
│ created_at              │
│ last_login              │
│ updated_at              │
└─────────────────────────┘
        │
        │ 1:N
        ├───────────────────────┐
        ▼                       ▼
┌──────────────────────┐  ┌────────────────────┐
│ category_members     │  │ friendships        │
├──────────────────────┤  ├────────────────────┤
│ user_id (FK)         │  │ user_id (FK)       │
│ category_id (FK)     │  │ friend_id (FK)     │
│ ...                  │  │ ...                │
└──────────────────────┘  └────────────────────┘
```

---

## Entity 클래스

### User Entity

```java
@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "firebase_uid", unique = true, nullable = false, length = 128)
    private String firebaseUid;

    @Column(unique = true, nullable = false, length = 50)
    private String nickname;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(name = "phone_number", unique = true, nullable = false, length = 20)
    private String phoneNumber;

    @Column(name = "birth_date")
    private LocalDate birthDate;

    @Column(name = "profile_image_url", length = 500)
    private String profileImageUrl;

    @Column(name = "is_deactivated", nullable = false)
    private Boolean isDeactivated = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "last_login")
    private LocalDateTime lastLogin;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // Lifecycle callbacks
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        lastLogin = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }

    // Business methods
    public boolean isActive() {
        return !isDeactivated;
    }

    public void deactivate() {
        this.isDeactivated = true;
    }

    public void activate() {
        this.isDeactivated = false;
    }

    public void updateLastLogin() {
        this.lastLogin = LocalDateTime.now();
    }
}
```

### 테이블 생성 SQL

```sql
CREATE TABLE users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    firebase_uid VARCHAR(128) UNIQUE NOT NULL,
    nickname VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    birth_date DATE,
    profile_image_url VARCHAR(500),
    is_deactivated BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_firebase_uid (firebase_uid),
    INDEX idx_nickname (nickname),
    INDEX idx_phone_number (phone_number),
    INDEX idx_is_deactivated (is_deactivated),
    FULLTEXT INDEX idx_nickname_ft (nickname)
);
```

### 인덱스 설명

| 인덱스        | 컬럼           | 용도                     |
| ------------- | -------------- | ------------------------ |
| `PRIMARY KEY` | id             | 기본 키                  |
| `UNIQUE`      | firebase_uid   | Firebase UID로 빠른 조회 |
| `UNIQUE`      | nickname       | 닉네임 중복 확인         |
| `UNIQUE`      | phone_number   | 전화번호 중복 확인       |
| `INDEX`       | is_deactivated | 활성 사용자 필터링       |
| `FULLTEXT`    | nickname       | 닉네임 검색 성능 향상    |

---

## DTO 클래스

### 1. UserDTO (기본 정보)

다른 사용자 조회 시 반환되는 공개 정보

```java
public class UserDTO {
    private Long id;
    private String nickname;
    private String name;
    private String profileImageUrl;

    public static UserDTO from(User user) {
        UserDTO dto = new UserDTO();
        dto.id = user.getId();
        dto.nickname = user.getNickname();
        dto.name = user.getName();
        dto.profileImageUrl = user.getProfileImageUrl();
        return dto;
    }
}
```

---

### 2. UserDetailDTO (상세 정보)

본인 정보 조회 시 반환되는 전체 정보

```java
public class UserDetailDTO extends UserDTO {
    private String phoneNumber;
    private LocalDate birthDate;
    private Boolean isDeactivated;
    private LocalDateTime createdAt;
    private LocalDateTime lastLogin;
    private LocalDateTime updatedAt;

    public static UserDetailDTO from(User user) {
        UserDetailDTO dto = new UserDetailDTO();
        // UserDTO 필드
        dto.setId(user.getId());
        dto.setNickname(user.getNickname());
        dto.setName(user.getName());
        dto.setProfileImageUrl(user.getProfileImageUrl());

        // 추가 필드 (본인만 조회 가능)
        dto.phoneNumber = user.getPhoneNumber();
        dto.birthDate = user.getBirthDate();
        dto.isDeactivated = user.getIsDeactivated();
        dto.createdAt = user.getCreatedAt();
        dto.lastLogin = user.getLastLogin();
        dto.updatedAt = user.getUpdatedAt();

        return dto;
    }
}
```

---

### 3. UserSearchDTO (검색 결과)

사용자 검색 시 반환되는 최소 정보

```java
public class UserSearchDTO {
    private Long id;
    private String nickname;
    private String name;
    private String profileImageUrl;

    public static UserSearchDTO from(User user) {
        UserSearchDTO dto = new UserSearchDTO();
        dto.id = user.getId();
        dto.nickname = user.getNickname();
        dto.name = user.getName();
        dto.profileImageUrl = user.getProfileImageUrl();
        return dto;
    }
}
```

---

### 4. Request DTOs

#### RegisterRequest (회원가입)

```java
public class RegisterRequest {

    @NotBlank(message = "Firebase UID는 필수입니다.")
    private String firebaseUid;

    @NotBlank(message = "ID Token은 필수입니다.")
    private String idToken;

    @NotBlank(message = "닉네임은 필수입니다.")
    @Size(min = 1, max = 50, message = "닉네임은 1-50자여야 합니다.")
    @Pattern(regexp = "^[a-zA-Z0-9_]+$",
             message = "닉네임은 영문, 숫자, 언더스코어만 가능합니다.")
    private String nickname;

    @NotBlank(message = "이름은 필수입니다.")
    @Size(min = 1, max = 100, message = "이름은 1-100자여야 합니다.")
    private String name;

    @NotBlank(message = "전화번호는 필수입니다.")
    @Pattern(regexp = "^01[0-9]{8,9}$",
             message = "올바른 전화번호 형식이 아닙니다.")
    private String phoneNumber;

    @Pattern(regexp = "^\\d{4}-\\d{2}-\\d{2}$",
             message = "생년월일 형식은 YYYY-MM-DD입니다.")
    private String birthDate;
}
```

---

#### LoginRequest (로그인)

```java
public class LoginRequest {

    @NotBlank(message = "Firebase UID는 필수입니다.")
    private String firebaseUid;

    @NotBlank(message = "ID Token은 필수입니다.")
    private String idToken;
}
```

---

#### UpdateUserRequest (사용자 정보 수정)

```java
public class UpdateUserRequest {

    @Size(min = 1, max = 100, message = "이름은 1-100자여야 합니다.")
    private String name;

    @Pattern(regexp = "^\\d{4}-\\d{2}-\\d{2}$",
             message = "생년월일 형식은 YYYY-MM-DD입니다.")
    private String birthDate;
}
```

---

#### CheckDuplicateRequest (중복 확인)

```java
public class CheckDuplicateRequest {

    @NotBlank(message = "닉네임은 필수입니다.")
    @Size(min = 1, max = 50, message = "닉네임은 1-50자여야 합니다.")
    private String nickname;
}
```

---

#### CheckDuplicateResponse (중복 확인 응답)

```java
public class CheckDuplicateResponse {
    private Boolean available;
    private String message;

    public static CheckDuplicateResponse available() {
        CheckDuplicateResponse response = new CheckDuplicateResponse();
        response.available = true;
        response.message = "사용 가능한 닉네임입니다.";
        return response;
    }

    public static CheckDuplicateResponse notAvailable() {
        CheckDuplicateResponse response = new CheckDuplicateResponse();
        response.available = false;
        response.message = "이미 사용 중인 닉네임입니다.";
        return response;
    }
}
```

---

### 5. Response DTOs

#### ProfileImageResponse (프로필 이미지 응답)

```java
public class ProfileImageResponse {
    private String profileImageUrl;

    public ProfileImageResponse(String profileImageUrl) {
        this.profileImageUrl = profileImageUrl;
    }
}
```

---

## Firebase vs Spring Boot 비교

### Firestore 구조 (현재)

```
users/{uid}
  ├─ uid: "abc123xyz..."
  ├─ id: "hong123"
  ├─ name: "홍길동"
  ├─ phone: "01012345678"
  ├─ birth_date: "1990-01-01"
  ├─ profile_image: "https://..."
  ├─ isDeactivated: false
  ├─ createdAt: Timestamp
  └─ lastLogin: Timestamp
```

**문제점**:

- 복잡한 쿼리 어려움 (WHERE, JOIN 불가)
- 인덱스 수동 생성 필요
- 트랜잭션 제한적
- 데이터 정합성 보장 어려움

---

### Spring Boot 구조 (목표)

```sql
-- users 테이블 (정규화)
SELECT * FROM users
WHERE firebase_uid = 'abc123xyz...'
  AND is_deactivated = FALSE;

-- 친구 관계 (JOIN)
SELECT u.* FROM users u
JOIN friendships f ON u.id = f.friend_id
WHERE f.user_id = 123
  AND u.is_deactivated = FALSE;

-- 닉네임 검색 (FULLTEXT)
SELECT * FROM users
WHERE MATCH(nickname) AGAINST('hong*' IN BOOLEAN MODE)
  AND is_deactivated = FALSE
LIMIT 50;
```

**장점**:

- ✅ 복잡한 쿼리 지원 (WHERE, JOIN, GROUP BY)
- ✅ 자동 인덱스 최적화
- ✅ 완전한 트랜잭션 (ACID)
- ✅ 외래 키 제약 조건
- ✅ 데이터 무결성 보장

---

## 주요 차이점

| 항목            | Firebase        | Spring Boot                   |
| --------------- | --------------- | ----------------------------- |
| **데이터 타입** | 동적 (Map)      | 강타입 (Entity)               |
| **식별자**      | String UID      | Long id + String firebase_uid |
| **타임스탬프**  | Timestamp       | LocalDateTime                 |
| **검색**        | 제한적          | Full-text 인덱스              |
| **관계**        | 수동 관리       | 외래 키 자동 관리             |
| **트랜잭션**    | 500개 문서 제한 | 무제한                        |
| **쿼리**        | 단순 필터       | 복잡한 JOIN                   |

---

## 마이그레이션 고려사항

### 1. Firebase UID → 백엔드 ID 매핑

```
Firebase:  uid = "abc123xyz..."
             ↓
Backend:   id = 123 (내부 ID)
           firebase_uid = "abc123xyz..." (Firebase 매핑)
```

**중요**:

- `firebase_uid`는 **변경 불가**
- `id`는 백엔드 내부에서만 사용
- 모든 관계는 `firebase_uid` 기반

---

### 2. Timestamp → LocalDateTime 변환

```java
// Firestore Timestamp → LocalDateTime
Timestamp firestoreTimestamp = docSnapshot.getTimestamp("createdAt");
LocalDateTime localDateTime = LocalDateTime.ofInstant(
    firestoreTimestamp.toDate().toInstant(),
    ZoneId.systemDefault()
);
```

---

### 3. 데이터 마이그레이션 스크립트

```java
@Service
public class UserMigrationService {

    @Autowired
    private Firestore firestore;

    @Autowired
    private UserRepository userRepository;

    @Transactional
    public void migrateAllUsers() {
        CollectionReference usersRef = firestore.collection("users");

        usersRef.get().get().forEach(docSnapshot -> {
            Map<String, Object> data = docSnapshot.getData();

            User user = new User();
            user.setFirebaseUid(docSnapshot.getId());
            user.setNickname((String) data.get("id"));
            user.setName((String) data.get("name"));
            user.setPhoneNumber((String) data.get("phone"));
            user.setBirthDate(LocalDate.parse((String) data.get("birth_date")));
            user.setProfileImageUrl((String) data.get("profile_image"));
            user.setIsDeactivated((Boolean) data.getOrDefault("isDeactivated", false));

            // Timestamp 변환
            Timestamp createdAt = (Timestamp) data.get("createdAt");
            user.setCreatedAt(convertToLocalDateTime(createdAt));

            Timestamp lastLogin = (Timestamp) data.get("lastLogin");
            user.setLastLogin(convertToLocalDateTime(lastLogin));

            userRepository.save(user);
        });
    }

    private LocalDateTime convertToLocalDateTime(Timestamp timestamp) {
        return LocalDateTime.ofInstant(
            timestamp.toDate().toInstant(),
            ZoneId.systemDefault()
        );
    }
}
```

---

## 다음 문서

👉 **[기능별 상세 명세](./05-features.md)** - 입력/처리/출력 프로세스
