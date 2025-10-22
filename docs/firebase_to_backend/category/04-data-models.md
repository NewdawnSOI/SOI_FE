# 카테고리 데이터 모델 설계

이 문서는 카테고리 기능의 **데이터베이스 스키마**와 **DTO 구조**를 정의합니다.

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
┌─────────────────┐
│     users       │
├─────────────────┤
│ id (PK)         │
│ phone           │
│ nickname        │
│ name            │
│ profile_image   │
└─────────────────┘
        │
        │ 1:N
        ▼
┌─────────────────────────────┐
│     categories              │
├─────────────────────────────┤
│ id (PK)                     │
│ name                        │
│ cover_photo_url             │
│ last_photo_uploaded_by (FK) │
│ last_photo_uploaded_at      │
│ created_at                  │
│ updated_at                  │
└─────────────────────────────┘
        │
        │ 1:N
        ├───────────────────────┐
        ▼                       ▼
┌──────────────────────┐  ┌────────────────────┐
│ category_members     │  │ category_photos    │
├──────────────────────┤  ├────────────────────┤
│ id (PK)              │  │ id (PK)            │
│ category_id (FK)     │  │ category_id (FK)   │
│ user_id (FK)         │  │ uploader_id (FK)   │
│ is_pinned            │  │ image_url          │
│ custom_name          │  │ audio_url          │
│ last_viewed_at       │  │ caption            │
│ joined_at            │  │ uploaded_at        │
└──────────────────────┘  └────────────────────┘
        │
        │ 1:N
        ▼
┌──────────────────────┐
│ category_invites     │
├──────────────────────┤
│ id (PK)              │
│ category_id (FK)     │
│ inviter_id (FK)      │
│ invitee_id (FK)      │
│ status               │
│ pending_member_ids   │
│ blocked_mate_ids     │
│ created_at           │
│ expires_at           │
└──────────────────────┘
```

---

## Entity 클래스

### 1. Category Entity

```java
@Entity
@Table(name = "categories")
public class Category {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    @Column(nullable = false, length = 20)
    private String name;

    @Column(name = "cover_photo_url")
    private String coverPhotoUrl;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "last_photo_uploaded_by")
    private User lastPhotoUploadedBy;

    @Column(name = "last_photo_uploaded_at")
    private LocalDateTime lastPhotoUploadedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // Relationships
    @OneToMany(mappedBy = "category", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<CategoryMember> members = new ArrayList<>();

    @OneToMany(mappedBy = "category", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<CategoryPhoto> photos = new ArrayList<>();

    @OneToMany(mappedBy = "category", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<CategoryInvite> invites = new ArrayList<>();

    // Lifecycle callbacks
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }

    // Business methods
    public boolean hasMember(String userId) {
        return members.stream()
            .anyMatch(m -> m.getUser().getId().equals(userId));
    }

    public int getMemberCount() {
        return members.size();
    }

    public int getPhotoCount() {
        return photos.size();
    }
}
```

### 인덱스 설정

```sql
CREATE INDEX idx_category_created_at ON categories(created_at DESC);
CREATE INDEX idx_category_last_photo ON categories(last_photo_uploaded_at DESC);
```

---

### 2. CategoryMember Entity

카테고리-사용자 중간 테이블 (Many-to-Many with extra fields)

```java
@Entity
@Table(name = "category_members",
       uniqueConstraints = @UniqueConstraint(columnNames = {"category_id", "user_id"}))
public class CategoryMember {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id", nullable = false)
    private Category category;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "is_pinned", nullable = false)
    private Boolean isPinned = false;

    @Column(name = "custom_name", length = 20)
    private String customName;

    @Column(name = "last_viewed_at")
    private LocalDateTime lastViewedAt;

    @Column(name = "joined_at", nullable = false, updatable = false)
    private LocalDateTime joinedAt;

    @PrePersist
    protected void onCreate() {
        joinedAt = LocalDateTime.now();
        lastViewedAt = LocalDateTime.now();
    }

    // Business method
    public boolean hasNewPhotos(LocalDateTime lastPhotoTime) {
        if (lastPhotoTime == null || lastViewedAt == null) {
            return false;
        }
        return lastPhotoTime.isAfter(lastViewedAt);
    }
}
```

### 인덱스 설정

```sql
CREATE INDEX idx_member_user_id ON category_members(user_id);
CREATE INDEX idx_member_category_id ON category_members(category_id);
CREATE INDEX idx_member_pinned ON category_members(user_id, is_pinned DESC);
```

---

### 3. CategoryPhoto Entity

```java
@Entity
@Table(name = "category_photos")
public class CategoryPhoto {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id", nullable = false)
    private Category category;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "uploader_id", nullable = false)
    private User uploader;

    @Column(name = "image_url", nullable = false)
    private String imageUrl;

    @Column(name = "audio_url")
    private String audioUrl;

    @Column(columnDefinition = "TEXT")
    private String caption;

    @Column(name = "uploaded_at", nullable = false, updatable = false)
    private LocalDateTime uploadedAt;

    @PrePersist
    protected void onCreate() {
        uploadedAt = LocalDateTime.now();
    }
}
```

### 인덱스 설정

```sql
CREATE INDEX idx_photo_category_id ON category_photos(category_id, uploaded_at DESC);
CREATE INDEX idx_photo_uploader_id ON category_photos(uploader_id);
```

---

### 4. CategoryInvite Entity

```java
@Entity
@Table(name = "category_invites")
public class CategoryInvite {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id", nullable = false)
    private Category category;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "inviter_id", nullable = false)
    private User inviter;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "invitee_id", nullable = false)
    private User invitee;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private InviteStatus status = InviteStatus.PENDING;

    @Column(name = "pending_member_ids", columnDefinition = "TEXT")
    @Convert(converter = StringListConverter.class)
    private List<String> pendingMemberIds = new ArrayList<>();

    @Column(name = "blocked_mate_ids", columnDefinition = "TEXT")
    @Convert(converter = StringListConverter.class)
    private List<String> blockedMateIds = new ArrayList<>();

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "expires_at")
    private LocalDateTime expiresAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        expiresAt = createdAt.plusDays(7);
    }

    public enum InviteStatus {
        PENDING,
        ACCEPTED,
        DECLINED,
        EXPIRED
    }

    // Helper converter for JSON array
    @Converter
    public static class StringListConverter implements AttributeConverter<List<String>, String> {
        private final ObjectMapper mapper = new ObjectMapper();

        @Override
        public String convertToDatabaseColumn(List<String> list) {
            try {
                return mapper.writeValueAsString(list);
            } catch (JsonProcessingException e) {
                throw new RuntimeException(e);
            }
        }

        @Override
        public List<String> convertToEntityAttribute(String json) {
            try {
                return mapper.readValue(json, new TypeReference<List<String>>(){});
            } catch (IOException e) {
                return new ArrayList<>();
            }
        }
    }
}
```

### 인덱스 설정

```sql
CREATE INDEX idx_invite_invitee ON category_invites(invitee_id, status);
CREATE INDEX idx_invite_category ON category_invites(category_id);
CREATE INDEX idx_invite_expires ON category_invites(expires_at);
```

---

## DTO 클래스

### 1. CategoryDTO

API 응답용 카테고리 정보

```java
public class CategoryDTO {
    private String id;
    private String name;
    private List<MemberDTO> members;
    private String coverPhotoUrl;
    private String customName;  // 사용자별 커스텀 이름
    private Boolean isPinned;    // 사용자별 고정 여부
    private Boolean hasNewPhoto; // 사용자별 새 사진 여부
    private Integer photoCount;
    private String lastPhotoUploadedBy;
    private LocalDateTime lastPhotoUploadedAt;
    private LocalDateTime userLastViewedAt; // 사용자별 마지막 확인 시간
    private LocalDateTime createdAt;

    // Static factory method
    public static CategoryDTO from(Category category, CategoryMember member) {
        CategoryDTO dto = new CategoryDTO();
        dto.id = category.getId();
        dto.name = category.getName();
        dto.coverPhotoUrl = category.getCoverPhotoUrl();
        dto.photoCount = category.getPhotoCount();
        dto.lastPhotoUploadedBy = category.getLastPhotoUploadedBy()?.getId();
        dto.lastPhotoUploadedAt = category.getLastPhotoUploadedAt();
        dto.createdAt = category.getCreatedAt();

        // User-specific fields
        if (member != null) {
            dto.customName = member.getCustomName();
            dto.isPinned = member.getIsPinned();
            dto.userLastViewedAt = member.getLastViewedAt();
            dto.hasNewPhoto = member.hasNewPhotos(category.getLastPhotoUploadedAt());
        }

        return dto;
    }
}
```

---

### 2. MemberDTO

카테고리 멤버 정보

```java
public class MemberDTO {
    private String userId;
    private String userName;
    private String nickname;
    private String profileImageUrl;
    private LocalDateTime joinedAt;

    public static MemberDTO from(CategoryMember member) {
        MemberDTO dto = new MemberDTO();
        dto.userId = member.getUser().getId();
        dto.userName = member.getUser().getName();
        dto.nickname = member.getUser().getNickname();
        dto.profileImageUrl = member.getUser().getProfileImage();
        dto.joinedAt = member.getJoinedAt();
        return dto;
    }
}
```

---

### 3. PhotoDTO

사진 정보

```java
public class PhotoDTO {
    private String id;
    private String imageUrl;
    private String audioUrl;
    private String caption;
    private UploaderDTO uploader;
    private LocalDateTime uploadedAt;

    public static PhotoDTO from(CategoryPhoto photo) {
        PhotoDTO dto = new PhotoDTO();
        dto.id = photo.getId();
        dto.imageUrl = photo.getImageUrl();
        dto.audioUrl = photo.getAudioUrl();
        dto.caption = photo.getCaption();
        dto.uploadedAt = photo.getUploadedAt();

        dto.uploader = new UploaderDTO();
        dto.uploader.userId = photo.getUploader().getId();
        dto.uploader.userName = photo.getUploader().getName();
        dto.uploader.profileImageUrl = photo.getUploader().getProfileImage();

        return dto;
    }

    public static class UploaderDTO {
        private String userId;
        private String userName;
        private String profileImageUrl;
    }
}
```

---

### 4. InviteDTO

초대 정보

```java
public class InviteDTO {
    private String id;
    private CategorySummaryDTO category;
    private InviterDTO inviter;
    private List<PendingMemberDTO> pendingMembers;
    private LocalDateTime createdAt;
    private LocalDateTime expiresAt;

    public static InviteDTO from(CategoryInvite invite) {
        InviteDTO dto = new InviteDTO();
        dto.id = invite.getId();
        dto.createdAt = invite.getCreatedAt();
        dto.expiresAt = invite.getExpiresAt();

        // Category summary
        dto.category = new CategorySummaryDTO();
        dto.category.id = invite.getCategory().getId();
        dto.category.name = invite.getCategory().getName();
        dto.category.coverPhotoUrl = invite.getCategory().getCoverPhotoUrl();

        // Inviter info
        dto.inviter = new InviterDTO();
        dto.inviter.userId = invite.getInviter().getId();
        dto.inviter.userName = invite.getInviter().getName();
        dto.inviter.profileImageUrl = invite.getInviter().getProfileImage();

        return dto;
    }

    public static class CategorySummaryDTO {
        private String id;
        private String name;
        private String coverPhotoUrl;
    }

    public static class InviterDTO {
        private String userId;
        private String userName;
        private String profileImageUrl;
    }

    public static class PendingMemberDTO {
        private String userId;
        private String userName;
    }
}
```

---

### 5. Request DTOs

#### CreateCategoryRequest

```java
public class CreateCategoryRequest {
    @NotBlank
    @Size(min = 1, max = 20)
    private String name;

    @NotEmpty
    private List<String> memberIds;
}
```

#### AddMemberRequest

```java
public class AddMemberRequest {
    private String userId;    // userId 또는 nickname 중 하나 필수
    private String nickname;

    @AssertTrue(message = "userId 또는 nickname이 필요합니다")
    private boolean isValid() {
        return userId != null || nickname != null;
    }
}
```

#### UpdateCategoryRequest

```java
public class UpdateCategoryRequest {
    @Size(min = 1, max = 20)
    private String name;
}
```

#### UpdatePinRequest

```java
public class UpdatePinRequest {
    @NotNull
    private Boolean isPinned;
}
```

#### UpdateCustomNameRequest

```java
public class UpdateCustomNameRequest {
    @Size(min = 1, max = 20)
    private String customName;
}
```

---

## Firebase vs Spring Boot 비교

### Firestore 구조 (현재)

```
categories/{categoryId}
  ├─ name: "가족 여행"
  ├─ memberUids: ["user_a", "user_b"]
  ├─ coverPhotoUrl: "https://..."
  ├─ lastPhotoUploadedBy: "user_a"
  ├─ lastPhotoUploadedAt: Timestamp
  ├─ userPinnedStatus: {
  │     "user_a": true,
  │     "user_b": false
  │  }
  ├─ customNames: {
  │     "user_a": "우리 가족",
  │     "user_b": null
  │  }
  └─ userLastViewTime: {
        "user_a": Timestamp,
        "user_b": Timestamp
     }

category_invites/{inviteId}
  ├─ categoryId: "cat_123"
  ├─ inviteeUid: "user_c"
  ├─ pendingMateUids: ["user_b"]
  └─ blockedMateUids: []

photos/{photoId}
  ├─ categoryId: "cat_123"
  ├─ uploaderUid: "user_a"
  ├─ imageUrl: "https://..."
  ├─ audioUrl: "https://..."
  └─ uploadedAt: Timestamp
```

### Spring Boot 구조 (목표)

**정규화된 관계형 DB 설계**

```sql
-- 카테고리 기본 정보
categories
  id, name, cover_photo_url, last_photo_uploaded_by,
  last_photo_uploaded_at, created_at, updated_at

-- 멤버 관계 (중간 테이블)
category_members
  id, category_id, user_id, is_pinned, custom_name,
  last_viewed_at, joined_at

-- 초대
category_invites
  id, category_id, inviter_id, invitee_id, status,
  pending_member_ids, blocked_mate_ids, created_at, expires_at

-- 사진
category_photos
  id, category_id, uploader_id, image_url, audio_url,
  caption, uploaded_at
```

### 주요 차이점

| 항목              | Firebase                    | Spring Boot             |
| ----------------- | --------------------------- | ----------------------- |
| **데이터 구조**   | 비정규화 (Map 필드)         | 정규화 (관계 테이블)    |
| **사용자별 상태** | userPinnedStatus Map        | category_members 테이블 |
| **관계 표현**     | memberUids 배열             | category_members (M:N)  |
| **트랜잭션**      | 제한적                      | 완전한 ACID 보장        |
| **쿼리**          | 제한적 (index 필수)         | 복잡한 JOIN 가능        |
| **타입 안정성**   | 낮음 (Map<String, dynamic>) | 높음 (강타입 Entity)    |

---

### 마이그레이션 고려사항

#### 1. Map → 관계 테이블 변환

```
Firebase: userPinnedStatus: {"user_a": true, "user_b": false}
      ↓
Spring: category_members 테이블의 각 row에 is_pinned 컬럼
```

#### 2. 배열 → 외래키 관계

```
Firebase: memberUids: ["user_a", "user_b"]
      ↓
Spring: category_members 테이블 (category_id + user_id)
```

#### 3. Timestamp → LocalDateTime

```
Firebase: Timestamp (Firestore 타입)
      ↓
Spring: LocalDateTime (Java 8+ 타입)
```

---

## 다음 문서

👉 **[개발 워크플로우](../../backend-migration/07-development-workflow.md)** - OpenAPI 자동화 및 개발 프로세스
