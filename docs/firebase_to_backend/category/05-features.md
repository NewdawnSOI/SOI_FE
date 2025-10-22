# 카테고리 기능별 상세 명세

이 문서는 **카테고리 시스템의 각 기능**을 입력/출력/처리 과정으로 상세히 정리합니다.

---

## 📋 목차

1. [카테고리 생성](#1-카테고리-생성)
2. [카테고리 조회](#2-카테고리-조회)
3. [카테고리 수정/삭제](#3-카테고리-수정삭제)
4. [멤버 추가](#4-멤버-추가)
5. [멤버 제거](#5-멤버-제거)
6. [초대 수락/거절](#6-초대-수락거절)
7. [사진 업로드](#7-사진-업로드)
8. [사진 삭제](#8-사진-삭제)
9. [표지사진 관리](#9-표지사진-관리)
10. [고정/커스텀 이름](#10-고정커스텀-이름)

---

## 1. 카테고리 생성

### 입력 (Input)

```json
{
  "name": "가족 여행",
  "memberIds": ["user_a", "user_b", "user_c"]
}
```

### 처리 과정 (Process)

#### 1단계: 입력 검증

```java
// 카테고리 이름 검증
if (name.isBlank() || name.length() > 20) {
    throw new ValidationException("카테고리 이름은 1-20자여야 합니다.");
}

// 멤버 존재 확인
if (memberIds.isEmpty()) {
    throw new ValidationException("최소 1명의 멤버가 필요합니다.");
}

// 생성자가 memberIds에 포함되어 있는지 확인
if (!memberIds.contains(currentUserId)) {
    memberIds.add(currentUserId);
}
```

#### 2단계: 친구 관계 배치 확인

```java
// 생성자와 각 멤버 간 양방향 친구 관계 확인
Map<String, Boolean> friendships = friendService.areBatchMutualFriends(
    currentUserId,
    memberIds
);

List<String> pendingMemberIds = new ArrayList<>();
for (String memberId : memberIds) {
    if (!friendships.get(memberId)) {
        pendingMemberIds.add(memberId);
    }
}
```

#### 3단계: 카테고리 생성 (트랜잭션)

```java
@Transactional
public CategoryDTO createCategory(CreateCategoryRequest request, String currentUserId) {
    // 1. 카테고리 엔티티 생성
    Category category = new Category();
    category.setName(request.getName());
    categoryRepository.save(category);

    // 2. 생성자를 멤버로 추가
    CategoryMember creatorMember = new CategoryMember();
    creatorMember.setCategory(category);
    creatorMember.setUser(userRepository.findById(currentUserId));
    categoryMemberRepository.save(creatorMember);

    // 3. 친구인 멤버들 즉시 추가
    for (String memberId : memberIds) {
        if (friendships.get(memberId)) {
            CategoryMember member = new CategoryMember();
            member.setCategory(category);
            member.setUser(userRepository.findById(memberId));
            categoryMemberRepository.save(member);
        }
    }

    // 4. 친구가 아닌 멤버들에게 초대 생성
    if (!pendingMemberIds.isEmpty()) {
        for (String memberId : pendingMemberIds) {
            CategoryInvite invite = new CategoryInvite();
            invite.setCategory(category);
            invite.setInviter(userRepository.findById(currentUserId));
            invite.setInvitee(userRepository.findById(memberId));
            invite.setPendingMemberIds(pendingMemberIds);
            categoryInviteRepository.save(invite);

            // 초대 알림 전송
            notificationService.sendInviteNotification(memberId, category);
        }
    }

    return CategoryDTO.from(category, creatorMember);
}
```

### 출력 (Output)

```json
{
  "success": true,
  "data": {
    "categoryId": "cat_123",
    "name": "가족 여행",
    "members": [
      {
        "userId": "user_a",
        "userName": "홍길동",
        "profileImageUrl": "https://..."
      }
    ],
    "invites": [
      {
        "inviteId": "inv_456",
        "invitedUserId": "user_b",
        "requiresAcceptance": true,
        "pendingMemberIds": ["user_c"]
      }
    ]
  }
}
```

---

## 2. 카테고리 조회

### 입력 (Input)

```
GET /categories?page=0&size=20&sort=createdAt,desc
Authorization: Bearer <token>
```

### 처리 과정 (Process)

#### 1단계: 사용자 카테고리 조회

```java
@Transactional(readOnly = true)
public Page<CategoryDTO> getUserCategories(String userId, Pageable pageable) {
    // 1. 사용자가 속한 카테고리 조회 (JOIN FETCH로 N+1 방지)
    Page<CategoryMember> memberPage = categoryMemberRepository
        .findByUserIdWithCategoryAndMembers(userId, pageable);

    // 2. DTO 변환
    return memberPage.map(member ->
        CategoryDTO.from(member.getCategory(), member)
    );
}
```

#### 2단계: 차단 필터링

```java
// 1:1 카테고리에서 차단한 사용자 있으면 제외
List<CategoryDTO> filtered = categories.stream()
    .filter(category -> {
        if (category.getMembers().size() != 2) {
            return true; // 1:1이 아니면 포함
        }

        String otherUserId = category.getMembers().stream()
            .filter(m -> !m.getUserId().equals(userId))
            .findFirst()
            .map(MemberDTO::getUserId)
            .orElse(null);

        return !blockService.isBlocked(userId, otherUserId);
    })
    .collect(Collectors.toList());
```

#### 3단계: Pending 초대 필터링

```java
// Pending 초대가 있는 카테고리 제외
Set<String> pendingCategoryIds = categoryInviteRepository
    .findPendingInvitesByInvitee(userId)
    .stream()
    .map(invite -> invite.getCategory().getId())
    .collect(Collectors.toSet());

filtered = filtered.stream()
    .filter(category -> !pendingCategoryIds.contains(category.getId()))
    .collect(Collectors.toList());
```

#### 4단계: 정렬

```java
// 고정된 카테고리를 상단에 표시
filtered.sort((c1, c2) -> {
    if (c1.getIsPinned() != c2.getIsPinned()) {
        return c1.getIsPinned() ? -1 : 1;
    }
    return c2.getCreatedAt().compareTo(c1.getCreatedAt());
});
```

### 출력 (Output)

```json
{
  "success": true,
  "data": {
    "categories": [
      {
        "id": "cat_123",
        "name": "가족 여행",
        "members": [...],
        "coverPhotoUrl": "https://...",
        "customName": "우리 가족",
        "isPinned": true,
        "hasNewPhoto": true,
        "photoCount": 42,
        "lastPhotoUploadedBy": "user_b",
        "lastPhotoUploadedAt": "2025-01-10T15:30:00Z",
        "createdAt": "2025-01-01T10:00:00Z"
      }
    ],
    "totalElements": 10,
    "totalPages": 1
  }
}
```

---

## 3. 카테고리 수정/삭제

### 수정 입력

```json
{
  "name": "새로운 이름"
}
```

### 수정 처리

```java
@Transactional
public CategoryDTO updateCategory(String categoryId, UpdateCategoryRequest request, String userId) {
    Category category = categoryRepository.findById(categoryId)
        .orElseThrow(() -> new NotFoundException("카테고리를 찾을 수 없습니다."));

    // 멤버 권한 확인
    if (!category.hasMember(userId)) {
        throw new ForbiddenException("카테고리 멤버가 아닙니다.");
    }

    // 이름 검증
    if (request.getName().length() > 20) {
        throw new ValidationException("이름이 너무 깁니다.");
    }

    category.setName(request.getName());
    categoryRepository.save(category);

    CategoryMember member = categoryMemberRepository.findByCategoryIdAndUserId(categoryId, userId);
    return CategoryDTO.from(category, member);
}
```

### 삭제 처리

```java
@Transactional
public void deleteCategory(String categoryId, String userId) {
    Category category = categoryRepository.findById(categoryId)
        .orElseThrow(() -> new NotFoundException("카테고리를 찾을 수 없습니다."));

    if (!category.hasMember(userId)) {
        throw new ForbiddenException("카테고리 멤버가 아닙니다.");
    }

    // Cascade 삭제:
    // - category_members
    // - category_photos (+ Storage 파일)
    // - category_invites
    categoryRepository.delete(category);

    // Storage 파일 삭제
    storageService.deleteCategoryFiles(categoryId);
}
```

---

## 4. 멤버 추가

### 입력

```json
{
  "userId": "user_d"
}
```

또는

```json
{
  "nickname": "hong123"
}
```

### 처리 과정

#### 1단계: 사용자 조회

```java
User targetUser;
if (request.getUserId() != null) {
    targetUser = userRepository.findById(request.getUserId())
        .orElseThrow(() -> new NotFoundException("사용자를 찾을 수 없습니다."));
} else {
    targetUser = userRepository.findByNickname(request.getNickname())
        .orElseThrow(() -> new NotFoundException("사용자를 찾을 수 없습니다."));
}
```

#### 2단계: 권한 및 중복 확인

```java
// 요청자가 멤버인지 확인
if (!category.hasMember(currentUserId)) {
    throw new ForbiddenException("카테고리 멤버가 아닙니다.");
}

// 이미 멤버인지 확인
if (category.hasMember(targetUser.getId())) {
    throw new ConflictException("이미 카테고리 멤버입니다.");
}
```

#### 3단계: 친구 관계 확인

```java
// 요청자와 대상 사용자 간 친구 관계 확인
if (!friendService.areMutualFriends(currentUserId, targetUser.getId())) {
    throw new ForbiddenException("친구만 추가할 수 있습니다.");
}

// 기존 멤버들과의 친구 관계 배치 확인
List<String> memberIds = category.getMembers().stream()
    .map(m -> m.getUser().getId())
    .collect(Collectors.toList());

Map<String, Boolean> friendships = friendService.areBatchMutualFriends(
    targetUser.getId(),
    memberIds
);

List<String> pendingMemberIds = memberIds.stream()
    .filter(memberId -> !friendships.get(memberId))
    .collect(Collectors.toList());
```

#### 4단계: 멤버 추가 또는 초대 생성

```java
@Transactional
public AddMemberResponse addMember(String categoryId, AddMemberRequest request, String currentUserId) {
    // ... 위 1~3단계 ...

    if (pendingMemberIds.isEmpty()) {
        // 모든 멤버와 친구 → 즉시 추가
        CategoryMember newMember = new CategoryMember();
        newMember.setCategory(category);
        newMember.setUser(targetUser);
        categoryMemberRepository.save(newMember);

        return AddMemberResponse.builder()
            .requiresAcceptance(false)
            .member(MemberDTO.from(newMember))
            .build();
    } else {
        // 일부와 친구가 아님 → 초대 생성
        CategoryInvite invite = new CategoryInvite();
        invite.setCategory(category);
        invite.setInviter(userRepository.findById(currentUserId));
        invite.setInvitee(targetUser);
        invite.setPendingMemberIds(pendingMemberIds);
        categoryInviteRepository.save(invite);

        notificationService.sendInviteNotification(targetUser.getId(), category);

        return AddMemberResponse.builder()
            .requiresAcceptance(true)
            .inviteId(invite.getId())
            .pendingMemberIds(pendingMemberIds)
            .build();
    }
}
```

### 출력 (즉시 추가)

```json
{
  "success": true,
  "data": {
    "requiresAcceptance": false,
    "member": {
      "userId": "user_d",
      "userName": "김철수",
      "profileImageUrl": "https://..."
    }
  },
  "message": "카테고리에 추가되었습니다."
}
```

### 출력 (초대 생성)

```json
{
  "success": true,
  "data": {
    "requiresAcceptance": true,
    "inviteId": "inv_789",
    "pendingMemberIds": ["user_a", "user_c"]
  },
  "message": "초대를 보냈습니다. 상대방의 수락을 기다리고 있습니다."
}
```

---

## 5. 멤버 제거

### 입력

```
DELETE /categories/{categoryId}/members/{userId}
```

### 처리 과정

```java
@Transactional
public void removeMember(String categoryId, String targetUserId, String currentUserId) {
    Category category = categoryRepository.findById(categoryId)
        .orElseThrow(() -> new NotFoundException("카테고리를 찾을 수 없습니다."));

    // 본인만 나갈 수 있음
    if (!targetUserId.equals(currentUserId)) {
        throw new ForbiddenException("본인만 나갈 수 있습니다.");
    }

    // 멤버 삭제
    CategoryMember member = categoryMemberRepository.findByCategoryIdAndUserId(categoryId, targetUserId)
        .orElseThrow(() -> new NotFoundException("멤버를 찾을 수 없습니다."));

    categoryMemberRepository.delete(member);

    // 마지막 멤버였다면 카테고리 삭제
    long remainingMembers = categoryMemberRepository.countByCategoryId(categoryId);
    if (remainingMembers == 0) {
        categoryRepository.delete(category);
        storageService.deleteCategoryFiles(categoryId);
    }
}
```

### 출력

```json
{
  "success": true,
  "message": "카테고리에서 나갔습니다."
}
```

---

## 6. 초대 수락/거절

### 수락 처리

```java
@Transactional
public CategoryDTO acceptInvite(String inviteId, String currentUserId) {
    CategoryInvite invite = categoryInviteRepository.findById(inviteId)
        .orElseThrow(() -> new NotFoundException("초대를 찾을 수 없습니다."));

    // 본인의 초대인지 확인
    if (!invite.getInvitee().getId().equals(currentUserId)) {
        throw new ForbiddenException("본인의 초대가 아닙니다.");
    }

    // 상태 확인
    if (invite.getStatus() != InviteStatus.PENDING) {
        throw new BadRequestException("이미 처리된 초대입니다.");
    }

    // 만료 확인
    if (invite.getExpiresAt().isBefore(LocalDateTime.now())) {
        throw new BadRequestException("만료된 초대입니다.");
    }

    Category category = invite.getCategory();

    // 멤버 추가
    CategoryMember newMember = new CategoryMember();
    newMember.setCategory(category);
    newMember.setUser(invite.getInvitee());
    categoryMemberRepository.save(newMember);

    // 초대 삭제
    invite.setStatus(InviteStatus.ACCEPTED);
    categoryInviteRepository.delete(invite);

    return CategoryDTO.from(category, newMember);
}
```

### 거절 처리

```java
@Transactional
public void declineInvite(String inviteId, String currentUserId) {
    CategoryInvite invite = categoryInviteRepository.findById(inviteId)
        .orElseThrow(() -> new NotFoundException("초대를 찾을 수 없습니다."));

    if (!invite.getInvitee().getId().equals(currentUserId)) {
        throw new ForbiddenException("본인의 초대가 아닙니다.");
    }

    invite.setStatus(InviteStatus.DECLINED);
    categoryInviteRepository.delete(invite);
}
```

---

## 7. 사진 업로드

### 입력

```
POST /categories/{categoryId}/photos
Content-Type: multipart/form-data

imageFile: <binary>
audioFile: <binary> (optional)
caption: "즐거운 여행!" (optional)
```

### 처리 과정

```java
@Transactional
public PhotoDTO uploadPhoto(
    String categoryId,
    MultipartFile imageFile,
    MultipartFile audioFile,
    String caption,
    String currentUserId
) {
    // 1. 권한 확인
    Category category = categoryRepository.findById(categoryId)
        .orElseThrow(() -> new NotFoundException("카테고리를 찾을 수 없습니다."));

    if (!category.hasMember(currentUserId)) {
        throw new ForbiddenException("카테고리 멤버가 아닙니다.");
    }

    // 2. 파일 검증
    if (imageFile.getSize() > 10 * 1024 * 1024) { // 10MB
        throw new ValidationException("이미지 파일이 너무 큽니다.");
    }

    String contentType = imageFile.getContentType();
    if (!contentType.startsWith("image/")) {
        throw new ValidationException("이미지 파일만 업로드 가능합니다.");
    }

    // 3. 이미지 압축 및 Storage 업로드
    String imageUrl = storageService.uploadImage(imageFile, categoryId);

    String audioUrl = null;
    if (audioFile != null) {
        audioUrl = storageService.uploadAudio(audioFile, categoryId);
    }

    // 4. DB 저장
    CategoryPhoto photo = new CategoryPhoto();
    photo.setCategory(category);
    photo.setUploader(userRepository.findById(currentUserId));
    photo.setImageUrl(imageUrl);
    photo.setAudioUrl(audioUrl);
    photo.setCaption(caption);
    categoryPhotoRepository.save(photo);

    // 5. 카테고리 최신 사진 정보 업데이트
    category.setLastPhotoUploadedBy(userRepository.findById(currentUserId));
    category.setLastPhotoUploadedAt(LocalDateTime.now());

    // 6. 표지사진이 없으면 자동 설정
    if (category.getCoverPhotoUrl() == null) {
        category.setCoverPhotoUrl(imageUrl);
    }

    categoryRepository.save(category);

    // 7. 다른 멤버에게 알림 전송
    List<String> memberIds = category.getMembers().stream()
        .map(m -> m.getUser().getId())
        .filter(id -> !id.equals(currentUserId))
        .collect(Collectors.toList());

    notificationService.sendPhotoUploadNotification(memberIds, category, photo);

    return PhotoDTO.from(photo);
}
```

### 출력

```json
{
  "success": true,
  "data": {
    "photoId": "photo_123",
    "imageUrl": "https://...",
    "audioUrl": "https://...",
    "caption": "즐거운 여행!",
    "uploadedAt": "2025-01-10T15:30:00Z"
  },
  "message": "사진이 업로드되었습니다."
}
```

---

## 8. 사진 삭제

### 처리 과정

```java
@Transactional
public void deletePhoto(String categoryId, String photoId, String currentUserId) {
    CategoryPhoto photo = categoryPhotoRepository.findById(photoId)
        .orElseThrow(() -> new NotFoundException("사진을 찾을 수 없습니다."));

    Category category = photo.getCategory();

    // 권한 확인 (멤버 또는 업로더)
    boolean isMember = category.hasMember(currentUserId);
    boolean isUploader = photo.getUploader().getId().equals(currentUserId);

    if (!isMember && !isUploader) {
        throw new ForbiddenException("권한이 없습니다.");
    }

    String imageUrl = photo.getImageUrl();
    String audioUrl = photo.getAudioUrl();

    // DB 삭제
    categoryPhotoRepository.delete(photo);

    // Storage 파일 삭제
    storageService.deleteFile(imageUrl);
    if (audioUrl != null) {
        storageService.deleteFile(audioUrl);
    }

    // 표지사진이었으면 최신 사진으로 변경
    if (category.getCoverPhotoUrl() != null &&
        category.getCoverPhotoUrl().equals(imageUrl)) {
        updateCoverPhotoToLatest(category);
    }
}

private void updateCoverPhotoToLatest(Category category) {
    Optional<CategoryPhoto> latestPhoto = categoryPhotoRepository
        .findTopByCategoryIdOrderByUploadedAtDesc(category.getId());

    if (latestPhoto.isPresent()) {
        category.setCoverPhotoUrl(latestPhoto.get().getImageUrl());
        category.setLastPhotoUploadedBy(latestPhoto.get().getUploader());
        category.setLastPhotoUploadedAt(latestPhoto.get().getUploadedAt());
    } else {
        category.setCoverPhotoUrl(null);
        category.setLastPhotoUploadedBy(null);
        category.setLastPhotoUploadedAt(null);
    }

    categoryRepository.save(category);
}
```

---

## 9. 표지사진 관리

### 갤러리에서 업로드

```java
@Transactional
public CoverPhotoDTO uploadCoverPhoto(
    String categoryId,
    MultipartFile imageFile,
    String currentUserId
) {
    Category category = categoryRepository.findById(categoryId)
        .orElseThrow(() -> new NotFoundException("카테고리를 찾을 수 없습니다."));

    if (!category.hasMember(currentUserId)) {
        throw new ForbiddenException("카테고리 멤버가 아닙니다.");
    }

    // Storage 업로드
    String coverPhotoUrl = storageService.uploadCoverPhoto(imageFile, categoryId);

    // 기존 표지사진 삭제
    if (category.getCoverPhotoUrl() != null) {
        storageService.deleteFile(category.getCoverPhotoUrl());
    }

    category.setCoverPhotoUrl(coverPhotoUrl);
    categoryRepository.save(category);

    return new CoverPhotoDTO(coverPhotoUrl);
}
```

### 카테고리 내 사진으로 설정

```java
@Transactional
public CoverPhotoDTO setCoverPhoto(
    String categoryId,
    String photoUrl,
    String currentUserId
) {
    Category category = categoryRepository.findById(categoryId)
        .orElseThrow(() -> new NotFoundException("카테고리를 찾을 수 없습니다."));

    if (!category.hasMember(currentUserId)) {
        throw new ForbiddenException("카테고리 멤버가 아닙니다.");
    }

    // 해당 사진이 카테고리에 속하는지 확인
    boolean photoExists = categoryPhotoRepository
        .existsByCategoryIdAndImageUrl(categoryId, photoUrl);

    if (!photoExists) {
        throw new NotFoundException("카테고리에 해당 사진이 없습니다.");
    }

    category.setCoverPhotoUrl(photoUrl);
    categoryRepository.save(category);

    return new CoverPhotoDTO(photoUrl);
}
```

---

## 10. 고정/커스텀 이름

### 고정 설정

```java
@Transactional
public void updatePinStatus(String categoryId, boolean isPinned, String currentUserId) {
    CategoryMember member = categoryMemberRepository
        .findByCategoryIdAndUserId(categoryId, currentUserId)
        .orElseThrow(() -> new NotFoundException("카테고리 멤버가 아닙니다."));

    member.setIsPinned(isPinned);
    categoryMemberRepository.save(member);
}
```

### 커스텀 이름 설정

```java
@Transactional
public void updateCustomName(String categoryId, String customName, String currentUserId) {
    CategoryMember member = categoryMemberRepository
        .findByCategoryIdAndUserId(categoryId, currentUserId)
        .orElseThrow(() -> new NotFoundException("카테고리 멤버가 아닙니다."));

    // 검증
    if (customName != null && customName.length() > 20) {
        throw new ValidationException("이름이 너무 깁니다.");
    }

    member.setCustomName(customName);
    categoryMemberRepository.save(member);
}
```

---

## 요약

이 문서는 **카테고리 시스템의 모든 기능**을 다음과 같이 정리했습니다:

1. ✅ **입력 (Input)**: API 요청 형식
2. ✅ **처리 (Process)**: 단계별 비즈니스 로직 및 Java 코드
3. ✅ **출력 (Output)**: API 응답 형식

백엔드 개발자는 이 문서를 참고하여:

- REST API 엔드포인트 구현
- 비즈니스 로직 검증
- 트랜잭션 처리
- 에러 핸들링
- 알림 시스템 연동

을 진행할 수 있습니다.
