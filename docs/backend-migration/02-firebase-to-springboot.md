# Firebase → Spring Boot 마이그레이션 상세 가이드

Firebase 기반 비즈니스 로직을 Spring Boot REST API로 전환하는 방법을 단계별로 설명합니다.

## 📊 마이그레이션 전략

### 핵심 원칙

1. **점진적 전환**: 한 번에 모든 것을 바꾸지 않고 도메인별로 단계적 마이그레이션
2. **읽기 우선**: 조회 API부터 구현 (위험도 낮음)
3. **데이터 일관성**: 마이그레이션 중에도 데이터 무결성 유지
4. **테스트 우선**: 각 단계마다 충분한 테스트

### 마이그레이션 순서

```
Phase 1: Category (카테고리) ← 시작하기 좋음
    ↓
Phase 2: Photo (사진)
    ↓
Phase 3: Friend (친구)
    ↓
Phase 4: Notification (알림)
    ↓
Phase 5: Auth (인증) ← 가장 마지막
```

---

## 🏗️ Spring Boot 백엔드 구축

### 1. 프로젝트 생성

```bash
# Spring Initializr 사용
curl https://start.spring.io/starter.zip \
  -d dependencies=web,data-jpa,postgresql,validation,lombok,security \
  -d groupId=com.soi \
  -d artifactId=soi-backend \
  -d name=SOI-Backend \
  -d packageName=com.soi \
  -d javaVersion=17 \
  -o soi-backend.zip

unzip soi-backend.zip
cd soi-backend
```

### 2. 프로젝트 구조

```
src/main/java/com/soi/
├── SoiBackendApplication.java
├── config/
│   ├── SecurityConfig.java          # JWT, CORS 설정
│   ├── OpenApiConfig.java           # Swagger 설정
│   └── FirebaseConfig.java          # Firebase Admin SDK (FCM, Storage)
├── common/
│   ├── dto/ApiResponse.java         # 공통 응답 포맷
│   ├── exception/                   # 커스텀 예외들
│   └── util/                        # 유틸리티 클래스
├── domain/
│   ├── category/
│   │   ├── entity/Category.java
│   │   ├── dto/CategoryDTO.java
│   │   ├── repository/CategoryRepository.java (JPA)
│   │   ├── service/CategoryService.java
│   │   └── controller/CategoryController.java
│   ├── photo/
│   │   └── ... (동일한 구조)
│   ├── friend/
│   │   └── ...
│   └── auth/
│       └── ...
└── infrastructure/
    ├── firebase/                    # Firebase Admin SDK 래퍼
    └── storage/                     # 파일 저장소 추상화
```

### 3. build.gradle 설정

```gradle
plugins {
    id 'java'
    id 'org.springframework.boot' version '3.2.0'
    id 'io.spring.dependency-management' version '1.1.4'
}

group = 'com.soi'
version = '1.0.0'
sourceCompatibility = '17'

configurations {
    compileOnly {
        extendsFrom annotationProcessor
    }
}

repositories {
    mavenCentral()
}

dependencies {
    // Spring Boot
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
    implementation 'org.springframework.boot:spring-boot-starter-validation'
    implementation 'org.springframework.boot:spring-boot-starter-security'

    // Database
    runtimeOnly 'org.postgresql:postgresql'

    // OpenAPI/Swagger
    implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.3.0'

    // Firebase Admin SDK
    implementation 'com.google.firebase:firebase-admin:9.2.0'

    // Lombok
    compileOnly 'org.projectlombok:lombok'
    annotationProcessor 'org.projectlombok:lombok'

    // JWT
    implementation 'io.jsonwebtoken:jjwt-api:0.12.3'
    runtimeOnly 'io.jsonwebtoken:jjwt-impl:0.12.3'
    runtimeOnly 'io.jsonwebtoken:jjwt-jackson:0.12.3'

    // Test
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
    testImplementation 'org.springframework.security:spring-security-test'
}

tasks.named('test') {
    useJUnitPlatform()
}
```

---

## 📝 Category 도메인 구현 (예시)

### 1. Entity 정의

```java
// src/main/java/com/soi/domain/category/entity/Category.java
package com.soi.domain.category.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.util.*;

@Entity
@Table(name = "categories")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Category {

    @Id
    @Column(length = 50)
    private String id;

    @Column(nullable = false)
    private String name;

    @ElementCollection
    @CollectionTable(
        name = "category_mates",
        joinColumns = @JoinColumn(name = "category_id")
    )
    @Column(name = "mate_id")
    private List<String> mates = new ArrayList<>();

    @ElementCollection
    @CollectionTable(
        name = "category_custom_names",
        joinColumns = @JoinColumn(name = "category_id")
    )
    @MapKeyColumn(name = "user_id")
    @Column(name = "custom_name")
    private Map<String, String> customNames = new HashMap<>();

    @ElementCollection
    @CollectionTable(
        name = "category_pinned_status",
        joinColumns = @JoinColumn(name = "category_id")
    )
    @MapKeyColumn(name = "user_id")
    @Column(name = "is_pinned")
    private Map<String, Boolean> userPinnedStatus = new HashMap<>();

    @Column(name = "category_photo_url")
    private String categoryPhotoUrl;

    @Column(name = "last_photo_uploaded_by")
    private String lastPhotoUploadedBy;

    @Column(name = "last_photo_uploaded_at")
    private Instant lastPhotoUploadedAt;

    @ElementCollection
    @CollectionTable(
        name = "category_user_viewed_at",
        joinColumns = @JoinColumn(name = "category_id")
    )
    @MapKeyColumn(name = "user_id")
    @Column(name = "viewed_at")
    private Map<String, Instant> userLastViewedAt = new HashMap<>();

    @CreationTimestamp
    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    private Instant updatedAt;

    @Version
    private Long version;  // Optimistic locking

    // 비즈니스 로직 메서드들

    public boolean isMember(String userId) {
        return mates.contains(userId);
    }

    public void addMember(String userId) {
        if (!isMember(userId)) {
            mates.add(userId);
        }
    }

    public void removeMember(String userId) {
        mates.remove(userId);
    }

    public String getDisplayName(String userId) {
        return customNames.getOrDefault(userId, name);
    }

    public boolean isPinnedForUser(String userId) {
        return userPinnedStatus.getOrDefault(userId, false);
    }

    public void setPinnedForUser(String userId, boolean isPinned) {
        userPinnedStatus.put(userId, isPinned);
    }
}
```

### 2. DTO 정의

```java
// src/main/java/com/soi/domain/category/dto/CategoryDTO.java
package com.soi.domain.category.dto;

import com.soi.domain.category.entity.Category;
import lombok.*;

import java.time.Instant;
import java.util.*;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CategoryDTO {
    private String id;
    private String name;
    private List<String> mates;
    private Map<String, String> customNames;
    private Map<String, Boolean> userPinnedStatus;
    private String categoryPhotoUrl;
    private String lastPhotoUploadedBy;
    private Instant lastPhotoUploadedAt;
    private Map<String, Instant> userLastViewedAt;
    private Instant createdAt;
    private Instant updatedAt;

    // Entity → DTO 변환
    public static CategoryDTO from(Category category) {
        return CategoryDTO.builder()
            .id(category.getId())
            .name(category.getName())
            .mates(new ArrayList<>(category.getMates()))
            .customNames(new HashMap<>(category.getCustomNames()))
            .userPinnedStatus(new HashMap<>(category.getUserPinnedStatus()))
            .categoryPhotoUrl(category.getCategoryPhotoUrl())
            .lastPhotoUploadedBy(category.getLastPhotoUploadedBy())
            .lastPhotoUploadedAt(category.getLastPhotoUploadedAt())
            .userLastViewedAt(new HashMap<>(category.getUserLastViewedAt()))
            .createdAt(category.getCreatedAt())
            .updatedAt(category.getUpdatedAt())
            .build();
    }
}

// Request DTOs
@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreateCategoryRequest {
    @NotBlank(message = "카테고리 이름은 필수입니다")
    @Size(max = 50, message = "카테고리 이름은 50자 이하여야 합니다")
    private String name;

    @NotEmpty(message = "최소 1명 이상의 멤버가 필요합니다")
    private List<String> mates;
}

@Data
@NoArgsConstructor
@AllArgsConstructor
public class UpdateCategoryRequest {
    private String name;
    private Boolean isPinned;
    private String customName;
}

@Data
@NoArgsConstructor
@AllArgsConstructor
public class AddMemberRequest {
    @NotBlank(message = "사용자 ID는 필수입니다")
    private String targetUserId;
}

// Response DTOs
@Data
@Builder
public class AddMemberResponse {
    private boolean requiresAcceptance;
    private String inviteId;
    private List<String> pendingMemberIds;
    private String message;
}
```

### 3. Repository

```java
// src/main/java/com/soi/domain/category/repository/CategoryRepository.java
package com.soi.domain.category.repository;

import com.soi.domain.category.entity.Category;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CategoryRepository extends JpaRepository<Category, String> {

    // 사용자의 카테고리 목록 조회
    @Query("SELECT c FROM Category c WHERE :userId MEMBER OF c.mates")
    List<Category> findByUserId(@Param("userId") String userId);

    // 카테고리 이름으로 검색
    @Query("SELECT c FROM Category c WHERE :userId MEMBER OF c.mates " +
           "AND LOWER(c.name) LIKE LOWER(CONCAT('%', :query, '%'))")
    List<Category> searchByNameForUser(
        @Param("userId") String userId,
        @Param("query") String query
    );

    // 사용자가 멤버인지 확인
    @Query("SELECT CASE WHEN COUNT(c) > 0 THEN true ELSE false END " +
           "FROM Category c WHERE c.id = :categoryId AND :userId MEMBER OF c.mates")
    boolean isMember(
        @Param("categoryId") String categoryId,
        @Param("userId") String userId
    );
}
```

### 4. Service (비즈니스 로직)

```java
// src/main/java/com/soi/domain/category/service/CategoryService.java
package com.soi.domain.category.service;

import com.soi.common.exception.ForbiddenException;
import com.soi.common.exception.NotFoundException;
import com.soi.domain.category.dto.*;
import com.soi.domain.category.entity.Category;
import com.soi.domain.category.repository.CategoryRepository;
import com.soi.domain.friend.service.FriendService;
import com.soi.domain.invite.service.InviteService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class CategoryService {

    private final CategoryRepository categoryRepository;
    private final FriendService friendService;
    private final InviteService inviteService;

    /**
     * 사용자의 카테고리 목록 조회
     */
    @Transactional(readOnly = true)
    public List<CategoryDTO> getUserCategories(String userId) {
        log.info("📋 Fetching categories for user: {}", userId);

        List<Category> categories = categoryRepository.findByUserId(userId);

        // 차단된 사용자 필터링 (백엔드에서 처리!)
        Set<String> blockedUsers = friendService.getBlockedUsers(userId);

        return categories.stream()
            .filter(category -> {
                // 카테고리 멤버 중 차단된 사용자가 있는지 확인
                return category.getMates().stream()
                    .noneMatch(blockedUsers::contains);
            })
            .map(CategoryDTO::from)
            .collect(Collectors.toList());
    }

    /**
     * 카테고리 생성
     */
    @Transactional
    public CategoryDTO createCategory(
        String currentUserId,
        CreateCategoryRequest request
    ) {
        log.info("➕ Creating category '{}' by user: {}",
            request.getName(), currentUserId);

        // 카테고리 생성자를 자동으로 멤버에 추가
        List<String> mates = new ArrayList<>(request.getMates());
        if (!mates.contains(currentUserId)) {
            mates.add(currentUserId);
        }

        // 모든 멤버가 서로 친구인지 확인
        validateAllMembersFriends(mates);

        Category category = Category.builder()
            .id(UUID.randomUUID().toString())
            .name(request.getName())
            .mates(mates)
            .customNames(new HashMap<>())
            .userPinnedStatus(new HashMap<>())
            .userLastViewedAt(new HashMap<>())
            .build();

        category = categoryRepository.save(category);

        log.info("✅ Category created: {}", category.getId());
        return CategoryDTO.from(category);
    }

    /**
     * 카테고리에 멤버 추가
     *
     * 🔥 핵심 비즈니스 로직: 친구 확인, 초대 생성 등
     */
    @Transactional
    public AddMemberResponse addMember(
        String categoryId,
        String currentUserId,
        AddMemberRequest request
    ) {
        log.info("👥 Adding member {} to category {} by user {}",
            request.getTargetUserId(), categoryId, currentUserId);

        // 1. 권한 확인
        Category category = findCategoryById(categoryId);
        if (!category.isMember(currentUserId)) {
            throw new ForbiddenException("카테고리에 멤버를 추가할 권한이 없습니다.");
        }

        // 2. 자기 자신 체크
        if (currentUserId.equals(request.getTargetUserId())) {
            throw new IllegalArgumentException("자기 자신을 추가할 수 없습니다.");
        }

        // 3. 중복 체크
        if (category.isMember(request.getTargetUserId())) {
            throw new IllegalArgumentException("이미 카테고리 멤버입니다.");
        }

        // 4. 친구 관계 확인 (배치 처리로 최적화)
        List<String> existingMembers = category.getMates().stream()
            .filter(id -> !id.equals(request.getTargetUserId()))
            .collect(Collectors.toList());

        Map<String, Boolean> friendships = friendService.areBatchMutualFriends(
            request.getTargetUserId(),
            existingMembers
        );

        List<String> nonFriendIds = friendships.entrySet().stream()
            .filter(entry -> !entry.getValue())
            .map(Map.Entry::getKey)
            .collect(Collectors.toList());

        // 5. 초대 필요 여부 판단
        if (!nonFriendIds.isEmpty()) {
            log.info("⏳ Invite required. Non-friend members: {}", nonFriendIds);

            // 초대 생성
            String inviteId = inviteService.createOrUpdateInvite(
                categoryId,
                request.getTargetUserId(),
                currentUserId,
                nonFriendIds
            );

            // FCM 알림 전송
            // TODO: Notification service 호출

            return AddMemberResponse.builder()
                .requiresAcceptance(true)
                .inviteId(inviteId)
                .pendingMemberIds(nonFriendIds)
                .message("초대를 보냈습니다. 상대방의 수락을 기다리고 있습니다.")
                .build();
        }

        // 6. 즉시 추가
        category.addMember(request.getTargetUserId());
        categoryRepository.save(category);

        log.info("✅ Member added immediately: {}", request.getTargetUserId());

        return AddMemberResponse.builder()
            .requiresAcceptance(false)
            .message("카테고리에 추가되었습니다.")
            .build();
    }

    /**
     * 카테고리 고정/해제
     */
    @Transactional
    public void togglePin(
        String categoryId,
        String userId,
        boolean isPinned
    ) {
        log.info("📌 Toggle pin: category={}, user={}, pinned={}",
            categoryId, userId, isPinned);

        Category category = findCategoryById(categoryId);

        if (!category.isMember(userId)) {
            throw new ForbiddenException("권한이 없습니다.");
        }

        category.setPinnedForUser(userId, isPinned);
        categoryRepository.save(category);
    }

    /**
     * 카테고리 삭제
     */
    @Transactional
    public void deleteCategory(String categoryId, String userId) {
        log.info("🗑️ Deleting category: {} by user: {}", categoryId, userId);

        Category category = findCategoryById(categoryId);

        if (!category.isMember(userId)) {
            throw new ForbiddenException("권한이 없습니다.");
        }

        // 멤버 제거
        category.removeMember(userId);

        // 마지막 멤버면 카테고리 삭제
        if (category.getMates().isEmpty()) {
            categoryRepository.delete(category);
            log.info("✅ Category deleted (last member left)");
        } else {
            categoryRepository.save(category);
            log.info("✅ User removed from category");
        }
    }

    // Private helper methods

    private Category findCategoryById(String categoryId) {
        return categoryRepository.findById(categoryId)
            .orElseThrow(() -> new NotFoundException("카테고리를 찾을 수 없습니다."));
    }

    private void validateAllMembersFriends(List<String> memberIds) {
        // TODO: 구현
    }
}
```

### 5. Controller (REST API)

```java
// src/main/java/com/soi/domain/category/controller/CategoryController.java
package com.soi.domain.category.controller;

import com.soi.common.dto.ApiResponse;
import com.soi.domain.category.dto.*;
import com.soi.domain.category.service.CategoryService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Slf4j
@RestController
@RequestMapping("/api/v1/categories")
@RequiredArgsConstructor
@Tag(name = "Category", description = "카테고리 관리 API")
public class CategoryController {

    private final CategoryService categoryService;

    /**
     * 카테고리 목록 조회
     */
    @Operation(summary = "카테고리 목록 조회", description = "사용자의 모든 카테고리를 반환합니다")
    @GetMapping
    public ResponseEntity<ApiResponse<List<CategoryDTO>>> getCategories(
        @Parameter(description = "사용자 ID", required = true)
        @RequestParam String userId
    ) {
        log.info("GET /api/v1/categories?userId={}", userId);

        List<CategoryDTO> categories = categoryService.getUserCategories(userId);

        return ResponseEntity.ok(
            ApiResponse.success(categories)
        );
    }

    /**
     * 카테고리 생성
     */
    @Operation(summary = "카테고리 생성")
    @PostMapping
    public ResponseEntity<ApiResponse<CategoryDTO>> createCategory(
        @AuthenticationPrincipal String currentUserId,
        @Valid @RequestBody CreateCategoryRequest request
    ) {
        log.info("POST /api/v1/categories - user: {}", currentUserId);

        CategoryDTO category = categoryService.createCategory(
            currentUserId,
            request
        );

        return ResponseEntity.ok(
            ApiResponse.success(category)
        );
    }

    /**
     * 멤버 추가
     */
    @Operation(summary = "멤버 추가", description = "카테고리에 새로운 멤버를 추가합니다. 친구 관계에 따라 즉시 추가되거나 초대가 생성됩니다.")
    @PostMapping("/{id}/members")
    public ResponseEntity<ApiResponse<AddMemberResponse>> addMember(
        @PathVariable String id,
        @AuthenticationPrincipal String currentUserId,
        @Valid @RequestBody AddMemberRequest request
    ) {
        log.info("POST /api/v1/categories/{}/members - user: {}", id, currentUserId);

        AddMemberResponse response = categoryService.addMember(
            id,
            currentUserId,
            request
        );

        return ResponseEntity.ok(
            ApiResponse.success(response)
        );
    }

    /**
     * 카테고리 고정/해제
     */
    @Operation(summary = "카테고리 고정/해제")
    @PutMapping("/{id}/pin")
    public ResponseEntity<ApiResponse<Void>> togglePin(
        @PathVariable String id,
        @RequestParam String userId,
        @RequestParam boolean isPinned
    ) {
        log.info("PUT /api/v1/categories/{}/pin - user: {}, pinned: {}",
            id, userId, isPinned);

        categoryService.togglePin(id, userId, isPinned);

        return ResponseEntity.ok(
            ApiResponse.success()
        );
    }

    /**
     * 카테고리 삭제/나가기
     */
    @Operation(summary = "카테고리 삭제/나가기")
    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteCategory(
        @PathVariable String id,
        @RequestParam String userId
    ) {
        log.info("DELETE /api/v1/categories/{} - user: {}", id, userId);

        categoryService.deleteCategory(id, userId);

        return ResponseEntity.ok(
            ApiResponse.success()
        );
    }
}
```

---

## 🔄 데이터 마이그레이션

### Firestore → PostgreSQL 마이그레이션 스크립트

```java
// src/main/java/com/soi/migration/FirestoreMigrationService.java
@Service
@RequiredArgsConstructor
public class FirestoreMigrationService {

    private final Firestore firestore;
    private final CategoryRepository categoryRepository;

    @Transactional
    public void migrateCategories() throws Exception {
        log.info("Starting Firestore → PostgreSQL migration...");

        // Firestore에서 모든 카테고리 읽기
        ApiFuture<QuerySnapshot> future = firestore.collection("categories").get();
        QuerySnapshot snapshot = future.get();

        int count = 0;
        for (DocumentSnapshot doc : snapshot.getDocuments()) {
            Map<String, Object> data = doc.getData();

            Category category = Category.builder()
                .id(doc.getId())
                .name((String) data.get("name"))
                .mates((List<String>) data.get("mates"))
                // ... 나머지 필드 매핑
                .build();

            categoryRepository.save(category);
            count++;
        }

        log.info("✅ Migrated {} categories", count);
    }
}
```

---

## 📝 다음 단계

백엔드 구축을 완료했다면:

👉 **[3. 아키텍처 비교로 이동](./03-architecture-comparison.md)**
