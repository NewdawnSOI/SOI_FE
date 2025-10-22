# 카테고리 비즈니스 규칙

이 문서는 카테고리 기능의 **모든 검증 규칙과 비즈니스 로직**을 정의합니다. 백엔드에서 반드시 구현해야 할 규칙들입니다.

---

## 📋 목차

1. [카테고리 생성 규칙](#카테고리-생성-규칙)
2. [카테고리 수정 규칙](#카테고리-수정-규칙)
3. [카테고리 삭제 규칙](#카테고리-삭제-규칙)
4. [멤버 관리 규칙](#멤버-관리-규칙)
5. [초대 시스템 규칙](#초대-시스템-규칙)
6. [사진 관리 규칙](#사진-관리-규칙)
7. [권한 및 보안 규칙](#권한-및-보안-규칙)
8. [필터링 규칙](#필터링-규칙)

---

## 카테고리 생성 규칙

### 입력 검증

#### 카테고리 이름

```java
// 규칙 1: 필수 입력
if (name == null || name.trim().isEmpty()) {
    throw new ValidationException("카테고리 이름을 입력해주세요.");
}

// 규칙 2: 길이 제한
if (name.trim().length() > 20) {
    throw new ValidationException("카테고리 이름은 20글자 이하여야 합니다.");
}

// 규칙 3: 정규화
String normalizedName = name.trim();
```

#### 멤버 목록

```java
// 규칙 1: 최소 인원
if (mates == null || mates.isEmpty()) {
    throw new ValidationException("최소 1명의 멤버가 필요합니다.");
}

// 규칙 2: 생성자 포함 확인
if (!mates.contains(currentUserId)) {
    throw new ValidationException("카테고리 생성자가 멤버에 포함되어야 합니다.");
}

// 규칙 3: 중복 제거
List<String> uniqueMates = mates.stream()
    .distinct()
    .collect(Collectors.toList());
```

### 친구 관계 검증

#### 생성자와 멤버 간 친구 관계

```java
// 규칙: 생성자는 모든 멤버와 양방향 친구여야 함
List<String> otherMates = mates.stream()
    .filter(m -> !m.equals(currentUserId))
    .collect(Collectors.toList());

if (!otherMates.isEmpty()) {
    Map<String, Boolean> friendshipResults =
        friendService.areBatchMutualFriends(currentUserId, otherMates);

    List<String> nonFriends = friendshipResults.entrySet().stream()
        .filter(e -> !e.getValue())
        .map(Map.Entry::getKey)
        .collect(Collectors.toList());

    if (!nonFriends.isEmpty()) {
        throw new FriendshipException(
            "카테고리는 친구들과만 만들 수 있습니다. 먼저 친구를 추가해주세요."
        );
    }
}
```

### 초대 처리 로직

#### 멤버 간 친구 관계 확인 및 초대 생성

```java
// 각 멤버별로 다른 멤버들과의 친구 관계 확인
for (String mateId : otherMates) {
    List<String> pendingMateIds = inviteService.getPendingMateIdsForUser(
        allMates: mates,
        targetUserId: mateId
    );

    if (!pendingMateIds.isEmpty()) {
        // 친구가 아닌 멤버가 있으면 초대 생성
        String inviteId = inviteService.createOrUpdateInvite(
            category: category,
            invitedUserId: mateId,
            inviterUserId: currentUserId,
            blockedMateIds: pendingMateIds
        );

        // 초대 알림 전송
        notificationService.createCategoryInviteNotification(
            categoryId: categoryId,
            actorUserId: currentUserId,
            recipientUserIds: [mateId],
            requiresAcceptance: true,
            categoryInviteId: inviteId,
            pendingMemberIds: pendingMateIds
        );
    } else {
        // 모두 친구이면 일반 알림
        notificationService.createCategoryInviteNotification(
            categoryId: categoryId,
            actorUserId: currentUserId,
            recipientUserIds: [mateId],
            requiresAcceptance: false
        );
    }
}
```

---

## 카테고리 수정 규칙

### 카테고리 이름 수정

```java
// 규칙 1: 동일한 검증 적용 (생성 시와 동일)
if (newName != null) {
    if (newName.trim().isEmpty()) {
        throw new ValidationException("카테고리 이름을 입력해주세요.");
    }
    if (newName.trim().length() > 20) {
        throw new ValidationException("카테고리 이름은 20글자 이하여야 합니다.");
    }
}

// 규칙 2: 멤버만 수정 가능 (권한 확인)
Category category = categoryRepository.findById(categoryId)
    .orElseThrow(() -> new NotFoundException("카테고리를 찾을 수 없습니다."));

if (!category.getMates().contains(currentUserId)) {
    throw new ForbiddenException("카테고리 멤버만 수정할 수 있습니다.");
}
```

### 커스텀 이름 설정

```java
// 규칙 1: 사용자별로 다른 이름 설정 가능
// 규칙 2: 동일한 이름 검증 적용
// 규칙 3: 본인의 커스텀 이름만 수정 가능

if (customName.trim().length() > 20) {
    throw new ValidationException("카테고리 이름은 20글자 이하여야 합니다.");
}

// DB 저장
categoryRepository.updateCustomName(categoryId, userId, customName.trim());
```

### 멤버 목록 수정

```java
// 규칙 1: 최소 1명 유지
if (newMates == null || newMates.isEmpty()) {
    throw new ValidationException("최소 1명의 멤버가 필요합니다.");
}

// 규칙 2: 멤버 추가 시 친구 관계 확인 (멤버 추가 규칙 참조)
// 규칙 3: 멤버 제거는 별도 API 사용 권장
```

---

## 카테고리 삭제 규칙

### 삭제 조건

```java
// 규칙 1: 카테고리 존재 확인
Category category = categoryRepository.findById(categoryId)
    .orElseThrow(() -> new NotFoundException("카테고리를 찾을 수 없습니다."));

// 규칙 2: 권한 확인 불필요 (모든 멤버가 삭제 가능)
// 하지만 멤버인지는 확인

// 규칙 3: 연관 데이터 삭제 (Cascade)
```

### 연관 데이터 처리

```java
@Transactional
public void deleteCategory(String categoryId) {
    // 1. 사진 삭제 (Cascade)
    photoRepository.deleteByCategoryId(categoryId);

    // 2. 초대 삭제
    inviteRepository.deleteByCategoryId(categoryId);

    // 3. 커스텀 이름 삭제
    customNameRepository.deleteByCategoryId(categoryId);

    // 4. 고정 상태 삭제
    pinStatusRepository.deleteByCategoryId(categoryId);

    // 5. 카테고리 삭제
    categoryRepository.deleteById(categoryId);
}
```

---

## 멤버 관리 규칙

### 멤버 추가 규칙

#### 기본 검증

```java
// 규칙 1: 로그인 확인
if (currentUserId == null || currentUserId.isEmpty()) {
    throw new UnauthorizedException("로그인이 필요합니다.");
}

// 규칙 2: 자기 자신 추가 불가
if (currentUserId.equals(targetUserId)) {
    throw new ValidationException("자기 자신은 이미 카테고리 멤버입니다.");
}

// 규칙 3: 카테고리 존재 확인
Category category = categoryRepository.findById(categoryId)
    .orElseThrow(() -> new NotFoundException("카테고리를 찾을 수 없습니다."));

// 규칙 4: 중복 확인
if (category.getMates().contains(targetUserId)) {
    throw new ValidationException("이미 카테고리 멤버입니다.");
}
```

#### 친구 관계 확인 및 초대 처리

```java
// 규칙 1: 요청자와 대상의 친구 관계 확인
if (!friendService.areMutualFriends(currentUserId, targetUserId)) {
    throw new FriendshipException("친구만 카테고리에 추가할 수 있습니다.");
}

// 규칙 2: 대상과 기존 멤버 간 친구 관계 확인
List<String> nonFriendMateIds = inviteService.getPendingMateIds(
    category: category,
    invitedUserId: targetUserId
);

if (!nonFriendMateIds.isEmpty()) {
    // 초대 생성
    String inviteId = inviteService.createOrUpdateInvite(
        category: category,
        invitedUserId: targetUserId,
        inviterUserId: currentUserId,
        blockedMateIds: nonFriendMateIds
    );

    // 알림 전송
    notificationService.createCategoryInviteNotification(
        categoryId: categoryId,
        actorUserId: currentUserId,
        recipientUserIds: [targetUserId],
        requiresAcceptance: true,
        categoryInviteId: inviteId,
        pendingMemberIds: nonFriendMateIds
    );

    return "초대를 보냈습니다. 상대방의 수락을 기다리고 있습니다.";
}

// 규칙 3: 모두 친구이면 바로 추가
categoryRepository.addMember(categoryId, targetUserId);

// 알림 전송
notificationService.createCategoryInviteNotification(
    categoryId: categoryId,
    actorUserId: currentUserId,
    recipientUserIds: [targetUserId],
    requiresAcceptance: false
);

return "카테고리에 추가되었습니다.";
```

### 멤버 제거 규칙

#### 기본 검증

```java
// 규칙 1: 카테고리 존재 확인
Category category = categoryRepository.findById(categoryId)
    .orElseThrow(() -> new NotFoundException("카테고리를 찾을 수 없습니다."));

// 규칙 2: 멤버 확인
if (!category.getMates().contains(targetUserId)) {
    throw new ValidationException("해당 사용자는 이 카테고리의 멤버가 아닙니다.");
}
```

#### 마지막 멤버 처리

```java
// 규칙: 마지막 멤버가 나가면 카테고리 삭제
if (category.getMates().size() == 1) {
    categoryRepository.deleteById(categoryId);
    return "카테고리에서 나갔습니다. 마지막 멤버였으므로 카테고리가 삭제되었습니다.";
}

// 일반 제거
categoryRepository.removeMember(categoryId, targetUserId);
return "카테고리에서 나갔습니다.";
```

---

## 초대 시스템 규칙

### 초대 생성 규칙

#### Pending 멤버 확인 로직

```java
// 규칙: 초대 대상자와 각 기존 멤버 간 양방향 친구인지 확인
public List<String> getPendingMateIds(
    Category category,
    String invitedUserId
) {
    List<String> existingMates = category.getMates().stream()
        .filter(m -> !m.equals(invitedUserId))
        .collect(Collectors.toList());

    if (existingMates.isEmpty()) {
        return Collections.emptyList();
    }

    // 배치로 친구 관계 확인
    Map<String, Boolean> friendshipResults =
        friendService.areBatchMutualFriends(invitedUserId, existingMates);

    return friendshipResults.entrySet().stream()
        .filter(e -> !e.getValue())  // 친구가 아닌 경우
        .map(Map.Entry::getKey)
        .collect(Collectors.toList());
}
```

#### 초대 생성/업데이트

```java
// 규칙 1: 기존 Pending 초대 확인
CategoryInvite existingInvite = inviteRepository
    .findPendingInviteForCategory(categoryId, invitedUserId);

if (existingInvite != null) {
    // 기존 초대 업데이트 (blockedMateIds 병합)
    Set<String> updatedBlockedMates = new HashSet<>(existingInvite.getBlockedMateIds());
    updatedBlockedMates.addAll(blockedMateIds);

    existingInvite.setBlockedMateIds(new ArrayList<>(updatedBlockedMates));
    existingInvite.setStatus(InviteStatus.PENDING);
    existingInvite.setUpdatedAt(LocalDateTime.now());

    return inviteRepository.save(existingInvite).getId();
}

// 규칙 2: 새 초대 생성
CategoryInvite invite = CategoryInvite.builder()
    .categoryId(categoryId)
    .invitedUserId(invitedUserId)
    .inviterUserId(inviterUserId)
    .status(InviteStatus.PENDING)
    .blockedMateIds(blockedMateIds)
    .createdAt(LocalDateTime.now())
    .build();

return inviteRepository.save(invite).getId();
```

### 초대 수락 규칙

#### 검증

```java
// 규칙 1: 초대 존재 확인
CategoryInvite invite = inviteRepository.findById(inviteId)
    .orElseThrow(() -> new NotFoundException("초대를 찾을 수 없습니다."));

// 규칙 2: 수신자 확인
if (!invite.getInvitedUserId().equals(currentUserId)) {
    throw new ForbiddenException("이 초대를 수락할 수 없습니다.");
}

// 규칙 3: 상태 확인
if (invite.getStatus() == InviteStatus.ACCEPTED) {
    return categoryId;  // 이미 수락됨
}

if (invite.getStatus() == InviteStatus.DECLINED || invite.isExpired()) {
    throw new ValidationException("만료되었거나 거절된 초대입니다.");
}

// 규칙 4: 카테고리 존재 확인
Category category = categoryRepository.findById(invite.getCategoryId())
    .orElseThrow(() -> new NotFoundException("카테고리를 찾을 수 없습니다."));
```

#### 처리

```java
@Transactional
public String acceptInvite(String inviteId, String userId) {
    // 검증...

    // 규칙 1: 멤버에 없으면 추가
    if (!category.getMates().contains(userId)) {
        categoryRepository.addMember(category.getId(), userId);
    }

    // 규칙 2: 초대 상태 업데이트
    invite.setStatus(InviteStatus.ACCEPTED);
    invite.setRespondedAt(LocalDateTime.now());
    inviteRepository.save(invite);

    // 규칙 3: 초대 삭제 (선택적, 또는 상태만 변경)
    inviteRepository.delete(invite);

    return category.getId();
}
```

### 초대 거절 규칙

```java
@Transactional
public void declineInvite(String inviteId, String userId) {
    // 검증 (수락과 동일)...

    // 규칙 1: 멤버에서 제거
    categoryRepository.removeMember(invite.getCategoryId(), userId);

    // 규칙 2: 초대 상태 업데이트
    invite.setStatus(InviteStatus.DECLINED);
    invite.setRespondedAt(LocalDateTime.now());
    inviteRepository.save(invite);

    // 규칙 3: 초대 삭제
    inviteRepository.delete(invite);
}
```

---

## 사진 관리 규칙

### 사진 추가 규칙

```java
// 규칙 1: 카테고리 유효성 확인
if (categoryId == null || categoryId.isEmpty()) {
    throw new ValidationException("유효하지 않은 카테고리입니다.");
}

// 규칙 2: 멤버 권한 확인
Category category = categoryRepository.findById(categoryId)
    .orElseThrow(() -> new NotFoundException("카테고리를 찾을 수 없습니다."));

if (!category.getMates().contains(currentUserId)) {
    throw new ForbiddenException("카테고리 멤버만 사진을 추가할 수 있습니다.");
}

// 규칙 3: 파일 검증 (백엔드에서 처리)
if (imageFile.getSize() > MAX_FILE_SIZE) {
    throw new ValidationException("파일 크기는 10MB 이하여야 합니다.");
}

String[] allowedTypes = {"image/jpeg", "image/png", "image/heic"};
if (!Arrays.asList(allowedTypes).contains(imageFile.getContentType())) {
    throw new ValidationException("지원하지 않는 파일 형식입니다.");
}
```

### 사진 삭제 규칙

```java
// 규칙 1: 사진 존재 확인
Photo photo = photoRepository.findById(photoId)
    .orElseThrow(() -> new NotFoundException("사진을 찾을 수 없습니다."));

// 규칙 2: 권한 확인 (멤버만 가능, 또는 업로더만)
Category category = categoryRepository.findById(photo.getCategoryId())
    .orElseThrow(() -> new NotFoundException("카테고리를 찾을 수 없습니다."));

if (!category.getMates().contains(currentUserId)) {
    throw new ForbiddenException("카테고리 멤버만 사진을 삭제할 수 있습니다.");
}

// 또는 업로더만 삭제 가능
if (!photo.getUploaderId().equals(currentUserId)) {
    throw new ForbiddenException("본인이 업로드한 사진만 삭제할 수 있습니다.");
}
```

### 표지사진 관리 규칙

```java
// 규칙 1: 멤버만 변경 가능
// 규칙 2: 카테고리 내 사진 또는 갤러리에서 선택
// 규칙 3: 표지사진 삭제 시 최신 사진으로 자동 설정

public void updateCoverPhotoToLatest(String categoryId) {
    List<Photo> photos = photoRepository.findByCategoryIdOrderByCreatedAtDesc(categoryId);

    if (!photos.isEmpty()) {
        categoryRepository.updateCoverPhoto(categoryId, photos.get(0).getImageUrl());
    } else {
        categoryRepository.updateCoverPhoto(categoryId, null);
    }
}
```

---

## 권한 및 보안 규칙

### 인증

```java
// 규칙: 모든 카테고리 API는 인증 필요
@PreAuthorize("isAuthenticated()")
public class CategoryController {
    // ...
}
```

### 멤버 권한 확인

```java
// 규칙: 카테고리 조회, 수정, 삭제 시 멤버 확인
public void checkMemberPermission(String categoryId, String userId) {
    Category category = categoryRepository.findById(categoryId)
        .orElseThrow(() -> new NotFoundException("카테고리를 찾을 수 없습니다."));

    if (!category.getMates().contains(userId)) {
        throw new ForbiddenException("카테고리 멤버만 접근할 수 있습니다.");
    }
}
```

### 친구 관계 확인 최적화

```java
// 규칙: 여러 사용자의 친구 관계를 한 번에 확인 (N+1 방지)
public Map<String, Boolean> areBatchMutualFriends(
    String userId,
    List<String> targetUserIds
) {
    // SQL JOIN을 사용한 배치 확인
    List<Friendship> friendships = friendshipRepository
        .findMutualFriendships(userId, targetUserIds);

    Map<String, Boolean> results = new HashMap<>();
    for (String targetId : targetUserIds) {
        boolean isFriend = friendships.stream()
            .anyMatch(f ->
                (f.getUserId1().equals(userId) && f.getUserId2().equals(targetId)) ||
                (f.getUserId1().equals(targetId) && f.getUserId2().equals(userId))
            );
        results.put(targetId, isFriend);
    }

    return results;
}
```

---

## 필터링 규칙

### 차단 사용자 필터링

#### 1:1 카테고리 필터링

```java
// 규칙: 1:1 카테고리에서 상대방을 차단한 경우 목록에서 숨김
public List<Category> getUserCategories(String userId) {
    List<Category> categories = categoryRepository.findByMatesContaining(userId);
    List<String> blockedUsers = blockRepository.findBlockedUserIds(userId);

    if (blockedUsers.isEmpty()) {
        return categories;
    }

    return categories.stream()
        .filter(category -> {
            // 1:1 카테고리 확인
            if (category.getMates().size() != 2) {
                return true;
            }

            // 상대방 확인
            String otherUser = category.getMates().stream()
                .filter(m -> !m.equals(userId))
                .findFirst()
                .orElse(null);

            // 차단한 사용자면 필터링
            return otherUser == null || !blockedUsers.contains(otherUser);
        })
        .collect(Collectors.toList());
}
```

#### 사진 필터링

```java
// 규칙: 차단한 사용자의 사진은 표시하지 않음
public List<Photo> getCategoryPhotos(String categoryId, String userId) {
    List<Photo> allPhotos = photoRepository.findByCategoryId(categoryId);
    List<String> blockedUsers = blockRepository.findBlockedUserIds(userId);

    if (blockedUsers.isEmpty()) {
        return allPhotos;
    }

    return allPhotos.stream()
        .filter(photo -> !blockedUsers.contains(photo.getUploaderId()))
        .collect(Collectors.toList());
}
```

### Pending 초대 필터링

```java
// 규칙: Pending 상태인 초대가 있는 카테고리는 목록에서 제외
public List<Category> getActiveCategoriesOnly(String userId) {
    List<Category> allCategories = categoryRepository.findByMatesContaining(userId);
    List<String> pendingCategoryIds = inviteRepository
        .findPendingInviteCategoryIds(userId);

    return allCategories.stream()
        .filter(category -> !pendingCategoryIds.contains(category.getId()))
        .collect(Collectors.toList());
}
```

---

## 데이터 정합성 규칙

### 트랜잭션 보장

```java
// 규칙: 관련 작업은 하나의 트랜잭션으로 처리
@Transactional
public String createCategoryWithInvites(CreateCategoryRequest request) {
    // 1. 카테고리 생성
    Category category = categoryRepository.save(newCategory);

    // 2. 초대 생성 (실패 시 전체 롤백)
    for (String mateId : pendingMates) {
        inviteRepository.save(createInvite(category, mateId));
    }

    return category.getId();
}
```

### Cascade 삭제

```java
// 규칙: 카테고리 삭제 시 관련 데이터 모두 삭제
@Entity
@Table(name = "categories")
public class Category {
    @OneToMany(mappedBy = "category", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Photo> photos;

    @OneToMany(mappedBy = "category", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<CategoryInvite> invites;
}
```

---

## 다음 문서

👉 **[API 엔드포인트](./03-api-endpoints.md)** - 전체 REST API 명세
