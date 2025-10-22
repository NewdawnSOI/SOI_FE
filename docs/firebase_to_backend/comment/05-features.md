# 음성/텍스트 댓글 시스템 - 기능별 구현 명세

이 문서는 **음성/텍스트 댓글 시스템의 각 기능**을 Spring Boot 코드로 상세히 정리합니다.

---

## 📋 목차

1. [음성 댓글 생성](#1-음성-댓글-생성)
2. [텍스트 댓글 생성](#2-텍스트-댓글-생성)
3. [사진별 댓글 조회](#3-사진별-댓글-조회)
4. [사용자별 댓글 조회](#4-사용자별-댓글-조회)
5. [댓글 위치 수정](#5-댓글-위치-수정)
6. [프로필 이미지 일괄 업데이트](#6-프로필-이미지-일괄-업데이트)
7. [댓글 삭제](#7-댓글-삭제)
8. [실시간 스트림](#8-실시간-스트림)

---

## 1. 음성 댓글 생성

### 입력 (Input)

```http
POST /api/photos/{photoId}/comments/audio
Content-Type: multipart/form-data

audioFile: <binary>
waveformData: [0.5, 0.8, 0.3, ...]
duration: 5000
relativeX: 0.5
relativeY: 0.3
```

### Controller

```java
@RestController
@RequestMapping("/api/photos/{photoId}/comments")
@RequiredArgsConstructor
public class CommentController {

    private final CommentService commentService;
    private final FirebaseAuthService firebaseAuthService;

    @PostMapping("/audio")
    public ResponseEntity<ApiResponse<CommentDTO>> createAudioComment(
            @PathVariable String photoId,
            @RequestParam("audioFile") MultipartFile audioFile,
            @RequestParam("waveformData") String waveformDataJson,
            @RequestParam("duration") Integer duration,
            @RequestParam("relativeX") BigDecimal relativeX,
            @RequestParam("relativeY") BigDecimal relativeY,
            @RequestHeader("Authorization") String authHeader
    ) {
        // 1. Firebase ID Token 검증
        String idToken = authHeader.replace("Bearer ", "");
        FirebaseToken decodedToken = firebaseAuthService.verifyIdToken(idToken);
        String userId = decodedToken.getUid();

        // 2. waveformData JSON 파싱
        List<Double> waveformData = parseWaveformData(waveformDataJson);

        // 3. 요청 DTO 생성
        CreateAudioCommentRequest request = CreateAudioCommentRequest.builder()
                .audioFile(audioFile)
                .waveformData(waveformData)
                .duration(duration)
                .relativeX(relativeX)
                .relativeY(relativeY)
                .build();

        // 4. 서비스 호출
        CommentDTO commentDTO = commentService.createAudioComment(photoId, request, userId);

        // 5. 응답
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(commentDTO, "음성 댓글이 생성되었습니다."));
    }

    private List<Double> parseWaveformData(String json) {
        try {
            ObjectMapper mapper = new ObjectMapper();
            return mapper.readValue(json, new TypeReference<List<Double>>() {});
        } catch (Exception e) {
            throw new ValidationException("파형 데이터 형식이 잘못되었습니다.");
        }
    }
}
```

### Service

```java
@Service
@RequiredArgsConstructor
@Slf4j
public class CommentService {

    private final CommentRepository commentRepository;
    private final WaveformDataRepository waveformDataRepository;
    private final PhotoRepository photoRepository;
    private final UserRepository userRepository;
    private final S3Service s3Service;
    private final NotificationService notificationService;
    private final RateLimitService rateLimitService;

    @Transactional
    public CommentDTO createAudioComment(
            String photoId,
            CreateAudioCommentRequest request,
            String currentUserId
    ) {
        log.info("음성 댓글 생성 시작 - photoId: {}, userId: {}", photoId, currentUserId);

        // 1. 인증 및 권한 확인
        User currentUser = userRepository.findByFirebaseUid(currentUserId)
                .orElseThrow(() -> new NotFoundException("사용자를 찾을 수 없습니다."));

        if (currentUser.isDeactivated()) {
            throw new ForbiddenException("탈퇴한 사용자입니다.");
        }

        // 2. 사진 존재 확인
        Photo photo = photoRepository.findById(photoId)
                .orElseThrow(() -> new NotFoundException("사진을 찾을 수 없습니다."));

        // 3. 입력 검증
        validateAudioCommentInput(request);

        // 4. Rate Limiting 확인
        String rateLimitKey = "comment_rate_limit:" + currentUser.getId();
        if (!rateLimitService.allowRequest(rateLimitKey, 10, 60)) {
            throw new RateLimitExceededException("분당 댓글 생성 횟수를 초과했습니다. (최대 10회)");
        }

        // 5. S3에 음성 파일 업로드
        String audioUrl = uploadAudioToS3(request.getAudioFile(), photoId, currentUser.getId());
        log.info("S3 업로드 완료 - audioUrl: {}", audioUrl);

        // 6. 댓글 엔티티 생성 및 저장
        Comment comment = Comment.builder()
                .photo(photo)
                .recorderUser(currentUser)
                .type(CommentType.AUDIO)
                .audioUrl(audioUrl)
                .duration(request.getDuration())
                .profileImageUrl(currentUser.getProfileImageUrl())
                .relativeX(request.getRelativeX())
                .relativeY(request.getRelativeY())
                .isDeleted(false)
                .build();

        comment = commentRepository.save(comment);
        log.info("댓글 저장 완료 - commentId: {}", comment.getId());

        // 7. 파형 데이터 저장 (별도 테이블)
        WaveformData waveformData = WaveformData.builder()
                .comment(comment)
                .data(request.getWaveformData())
                .build();

        waveformDataRepository.save(waveformData);
        log.info("파형 데이터 저장 완료");

        // 8. 알림 전송 (비동기, 본인이 아닌 경우만)
        if (!photo.getUploader().getId().equals(currentUser.getId())) {
            try {
                notificationService.createCommentNotification(
                        photo.getUploader().getId(),
                        currentUser.getId(),
                        photoId,
                        comment.getId(),
                        NotificationType.AUDIO_COMMENT
                );
                log.info("알림 전송 완료");
            } catch (Exception e) {
                log.error("알림 전송 실패 (댓글은 저장됨): {}", e.getMessage());
                // 알림 실패해도 댓글은 저장됨
            }
        }

        // 9. DTO 변환 및 반환
        return CommentDTO.from(comment, waveformData);
    }

    private void validateAudioCommentInput(CreateAudioCommentRequest request) {
        // 파일 존재 확인
        if (request.getAudioFile() == null || request.getAudioFile().isEmpty()) {
            throw new ValidationException("음성 파일이 필요합니다.");
        }

        // 파일 크기 확인 (10MB)
        long maxSize = 10 * 1024 * 1024;
        if (request.getAudioFile().getSize() > maxSize) {
            throw new ValidationException("음성 파일 크기는 10MB 이하여야 합니다.");
        }

        // 파일 형식 확인
        String contentType = request.getAudioFile().getContentType();
        if (contentType == null || !isValidAudioFormat(contentType)) {
            throw new ValidationException("지원하지 않는 음성 파일 형식입니다. (aac, m4a, mp3, wav만 가능)");
        }

        // 녹음 시간 확인 (1초 ~ 5분)
        if (request.getDuration() == null || request.getDuration() < 1000 || request.getDuration() > 300000) {
            throw new ValidationException("녹음 시간은 1초 이상 5분 이하여야 합니다.");
        }

        // 파형 데이터 확인
        if (request.getWaveformData() == null || request.getWaveformData().isEmpty()) {
            throw new ValidationException("파형 데이터가 필요합니다.");
        }

        // 파형 데이터 정규화 확인 (0.0 ~ 1.0)
        for (Double value : request.getWaveformData()) {
            if (value < 0.0 || value > 1.0) {
                throw new ValidationException("파형 데이터는 0.0 ~ 1.0 사이의 값이어야 합니다.");
            }
        }

        // 상대 좌표 확인 (0.0 ~ 1.0)
        if (request.getRelativeX() == null ||
            request.getRelativeX().compareTo(BigDecimal.ZERO) < 0 ||
            request.getRelativeX().compareTo(BigDecimal.ONE) > 0) {
            throw new ValidationException("X 좌표는 0.0 ~ 1.0 사이여야 합니다.");
        }

        if (request.getRelativeY() == null ||
            request.getRelativeY().compareTo(BigDecimal.ZERO) < 0 ||
            request.getRelativeY().compareTo(BigDecimal.ONE) > 0) {
            throw new ValidationException("Y 좌표는 0.0 ~ 1.0 사이여야 합니다.");
        }
    }

    private boolean isValidAudioFormat(String contentType) {
        return contentType.equals("audio/aac") ||
               contentType.equals("audio/x-m4a") ||
               contentType.equals("audio/mpeg") ||
               contentType.equals("audio/mp3") ||
               contentType.equals("audio/wav");
    }

    private String uploadAudioToS3(MultipartFile audioFile, String photoId, Long userId) {
        try {
            // 파일명 생성 (충돌 방지)
            String timestamp = String.valueOf(System.currentTimeMillis());
            String randomId = UUID.randomUUID().toString().substring(0, 8);
            String extension = getFileExtension(audioFile.getOriginalFilename());
            String fileName = String.format("%s_%s_%s.%s", photoId, userId, timestamp, extension);

            // S3 경로
            String s3Key = "comments/audio/" + photoId + "/" + fileName;

            // 메타데이터 설정
            Map<String, String> metadata = new HashMap<>();
            metadata.put("photo-id", photoId);
            metadata.put("user-id", userId.toString());
            metadata.put("uploaded-at", LocalDateTime.now().toString());

            // S3 업로드
            return s3Service.uploadFile(
                    audioFile.getInputStream(),
                    s3Key,
                    audioFile.getContentType(),
                    metadata
            );
        } catch (IOException e) {
            log.error("S3 업로드 실패: {}", e.getMessage(), e);
            throw new S3UploadException("음성 파일 업로드에 실패했습니다.");
        }
    }

    private String getFileExtension(String fileName) {
        if (fileName == null || !fileName.contains(".")) {
            return "aac"; // 기본값
        }
        return fileName.substring(fileName.lastIndexOf(".") + 1);
    }
}
```

### 출력 (Output)

```json
{
  "success": true,
  "data": {
    "id": 123,
    "photoId": "photo123",
    "recorderUserId": 456,
    "recorderNickname": "hong123",
    "recorderName": "홍길동",
    "type": "audio",
    "audioUrl": "https://s3.amazonaws.com/soi-app/comments/audio/photo123/photo123_456_1704967800_a7b3c2d1.aac",
    "text": null,
    "duration": 5000,
    "waveformData": [0.5, 0.8, 0.3, 0.9, 0.4, 0.7, 0.2, 0.6],
    "profileImageUrl": "https://...",
    "relativeX": 0.5,
    "relativeY": 0.3,
    "createdAt": "2025-01-10T15:30:00Z"
  },
  "message": "음성 댓글이 생성되었습니다."
}
```

---

## 2. 텍스트 댓글 생성

### 입력 (Input)

```json
{
  "text": "좋은 사진이네요!",
  "relativeX": 0.7,
  "relativeY": 0.5
}
```

### Controller

```java
@PostMapping("/text")
public ResponseEntity<ApiResponse<CommentDTO>> createTextComment(
        @PathVariable String photoId,
        @RequestBody @Valid CreateTextCommentRequest request,
        @RequestHeader("Authorization") String authHeader
) {
    // Firebase ID Token 검증
    String idToken = authHeader.replace("Bearer ", "");
    FirebaseToken decodedToken = firebaseAuthService.verifyIdToken(idToken);
    String userId = decodedToken.getUid();

    // 서비스 호출
    CommentDTO commentDTO = commentService.createTextComment(photoId, request, userId);

    // 응답
    return ResponseEntity.status(HttpStatus.CREATED)
            .body(ApiResponse.success(commentDTO, "텍스트 댓글이 생성되었습니다."));
}
```

### Service

```java
@Transactional
public CommentDTO createTextComment(
        String photoId,
        CreateTextCommentRequest request,
        String currentUserId
) {
    log.info("텍스트 댓글 생성 시작 - photoId: {}, userId: {}", photoId, currentUserId);

    // 1. 인증 및 권한 확인
    User currentUser = userRepository.findByFirebaseUid(currentUserId)
            .orElseThrow(() -> new NotFoundException("사용자를 찾을 수 없습니다."));

    if (currentUser.isDeactivated()) {
        throw new ForbiddenException("탈퇴한 사용자입니다.");
    }

    // 2. 사진 존재 확인
    Photo photo = photoRepository.findById(photoId)
            .orElseThrow(() -> new NotFoundException("사진을 찾을 수 없습니다."));

    // 3. 입력 검증
    validateTextCommentInput(request);

    // 4. Rate Limiting 확인
    String rateLimitKey = "comment_rate_limit:" + currentUser.getId();
    if (!rateLimitService.allowRequest(rateLimitKey, 10, 60)) {
        throw new RateLimitExceededException("분당 댓글 생성 횟수를 초과했습니다. (최대 10회)");
    }

    // 5. 댓글 엔티티 생성 및 저장
    Comment comment = Comment.builder()
            .photo(photo)
            .recorderUser(currentUser)
            .type(CommentType.TEXT)
            .text(request.getText().trim())
            .profileImageUrl(currentUser.getProfileImageUrl())
            .relativeX(request.getRelativeX())
            .relativeY(request.getRelativeY())
            .isDeleted(false)
            .build();

    comment = commentRepository.save(comment);
    log.info("텍스트 댓글 저장 완료 - commentId: {}", comment.getId());

    // 6. 알림 전송 (비동기, 본인이 아닌 경우만)
    if (!photo.getUploader().getId().equals(currentUser.getId())) {
        try {
            notificationService.createCommentNotification(
                    photo.getUploader().getId(),
                    currentUser.getId(),
                    photoId,
                    comment.getId(),
                    NotificationType.TEXT_COMMENT
            );
            log.info("알림 전송 완료");
        } catch (Exception e) {
            log.error("알림 전송 실패 (댓글은 저장됨): {}", e.getMessage());
        }
    }

    // 7. DTO 변환 및 반환 (텍스트 댓글은 waveformData 없음)
    return CommentDTO.from(comment, null);
}

private void validateTextCommentInput(CreateTextCommentRequest request) {
    // 텍스트 확인
    if (request.getText() == null || request.getText().trim().isEmpty()) {
        throw new ValidationException("댓글 내용이 필요합니다.");
    }

    // 텍스트 길이 확인 (최대 1000자)
    if (request.getText().trim().length() > 1000) {
        throw new ValidationException("댓글은 최대 1000자까지 입력 가능합니다.");
    }

    // 금지어 필터링 (선택적)
    if (containsForbiddenWords(request.getText())) {
        throw new ValidationException("사용할 수 없는 단어가 포함되어 있습니다.");
    }

    // 상대 좌표 확인
    if (request.getRelativeX() == null ||
        request.getRelativeX().compareTo(BigDecimal.ZERO) < 0 ||
        request.getRelativeX().compareTo(BigDecimal.ONE) > 0) {
        throw new ValidationException("X 좌표는 0.0 ~ 1.0 사이여야 합니다.");
    }

    if (request.getRelativeY() == null ||
        request.getRelativeY().compareTo(BigDecimal.ZERO) < 0 ||
        request.getRelativeY().compareTo(BigDecimal.ONE) > 0) {
        throw new ValidationException("Y 좌표는 0.0 ~ 1.0 사이여야 합니다.");
    }
}

private boolean containsForbiddenWords(String text) {
    // 금지어 목록 (실제로는 DB나 설정 파일에서 가져옴)
    List<String> forbiddenWords = Arrays.asList("욕설1", "욕설2", "금지어");

    String lowerText = text.toLowerCase();
    return forbiddenWords.stream()
            .anyMatch(word -> lowerText.contains(word.toLowerCase()));
}
```

### 출력 (Output)

```json
{
  "success": true,
  "data": {
    "id": 124,
    "photoId": "photo123",
    "recorderUserId": 456,
    "recorderNickname": "hong123",
    "recorderName": "홍길동",
    "type": "text",
    "audioUrl": null,
    "text": "좋은 사진이네요!",
    "duration": null,
    "waveformData": null,
    "profileImageUrl": "https://...",
    "relativeX": 0.7,
    "relativeY": 0.5,
    "createdAt": "2025-01-10T15:35:00Z"
  },
  "message": "텍스트 댓글이 생성되었습니다."
}
```

---

## 3. 사진별 댓글 조회

### 입력 (Input)

```http
GET /api/photos/{photoId}/comments?page=0&size=20
Authorization: Bearer {idToken}
```

### Controller

```java
@GetMapping
public ResponseEntity<ApiResponse<PagedCommentsResponse>> getCommentsByPhoto(
        @PathVariable String photoId,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size,
        @RequestHeader("Authorization") String authHeader
) {
    // Firebase ID Token 검증
    String idToken = authHeader.replace("Bearer ", "");
    FirebaseToken decodedToken = firebaseAuthService.verifyIdToken(idToken);
    String userId = decodedToken.getUid();

    // 페이지네이션 검증
    if (size > 100) {
        size = 100; // 최대 100개로 제한
    }

    Pageable pageable = PageRequest.of(page, size, Sort.by("createdAt").ascending());

    // 서비스 호출
    Page<CommentDTO> comments = commentService.getCommentsByPhotoId(photoId, pageable, userId);

    // 응답
    PagedCommentsResponse response = PagedCommentsResponse.builder()
            .comments(comments.getContent())
            .currentPage(comments.getNumber())
            .pageSize(comments.getSize())
            .totalElements(comments.getTotalElements())
            .totalPages(comments.getTotalPages())
            .hasNext(comments.hasNext())
            .hasPrevious(comments.hasPrevious())
            .build();

    return ResponseEntity.ok(ApiResponse.success(response));
}
```

### Service

```java
@Transactional(readOnly = true)
public Page<CommentDTO> getCommentsByPhotoId(String photoId, Pageable pageable, String currentUserId) {
    log.info("사진별 댓글 조회 - photoId: {}, page: {}", photoId, pageable.getPageNumber());

    // 1. 사진 존재 확인
    Photo photo = photoRepository.findById(photoId)
            .orElseThrow(() -> new NotFoundException("사진을 찾을 수 없습니다."));

    // 2. 댓글 조회 (JOIN FETCH로 N+1 방지)
    Page<Comment> comments = commentRepository.findByPhotoIdAndIsDeletedFalse(
            photoId,
            pageable
    );

    // 3. DTO 변환
    return comments.map(comment -> {
        // 파형 데이터 조회 (음성 댓글인 경우만)
        WaveformData waveformData = null;
        if (comment.getType() == CommentType.AUDIO) {
            waveformData = waveformDataRepository.findByCommentId(comment.getId())
                    .orElse(null);
        }

        return CommentDTO.from(comment, waveformData);
    });
}
```

### Repository

```java
public interface CommentRepository extends JpaRepository<Comment, Long> {

    @Query("""
        SELECT c FROM Comment c
        LEFT JOIN FETCH c.recorderUser u
        WHERE c.photo.id = :photoId
          AND c.isDeleted = false
        ORDER BY c.createdAt ASC
    """)
    Page<Comment> findByPhotoIdAndIsDeletedFalse(@Param("photoId") String photoId, Pageable pageable);

    @Query("SELECT COUNT(c) FROM Comment c WHERE c.photo.id = :photoId AND c.isDeleted = false")
    long countByPhotoIdAndIsDeletedFalse(@Param("photoId") String photoId);
}
```

### 출력 (Output)

```json
{
  "success": true,
  "data": {
    "comments": [
      {
        "id": 123,
        "photoId": "photo123",
        "recorderUserId": 456,
        "recorderNickname": "hong123",
        "recorderName": "홍길동",
        "type": "audio",
        "audioUrl": "https://s3.amazonaws.com/...",
        "text": null,
        "duration": 5000,
        "waveformData": [0.5, 0.8, 0.3],
        "profileImageUrl": "https://...",
        "relativeX": 0.5,
        "relativeY": 0.3,
        "createdAt": "2025-01-10T15:30:00Z"
      },
      {
        "id": 124,
        "photoId": "photo123",
        "recorderUserId": 789,
        "recorderNickname": "kim456",
        "recorderName": "김철수",
        "type": "text",
        "audioUrl": null,
        "text": "좋은 사진이네요!",
        "duration": null,
        "waveformData": null,
        "profileImageUrl": "https://...",
        "relativeX": 0.7,
        "relativeY": 0.5,
        "createdAt": "2025-01-10T15:35:00Z"
      }
    ],
    "currentPage": 0,
    "pageSize": 20,
    "totalElements": 25,
    "totalPages": 2,
    "hasNext": true,
    "hasPrevious": false
  }
}
```

---

## 4. 사용자별 댓글 조회

### 입력 (Input)

```http
GET /api/users/{userId}/comments?page=0&size=20
Authorization: Bearer {idToken}
```

### Controller

```java
@GetMapping("/users/{userId}/comments")
public ResponseEntity<ApiResponse<PagedCommentsResponse>> getCommentsByUser(
        @PathVariable Long userId,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size,
        @RequestHeader("Authorization") String authHeader
) {
    // Firebase ID Token 검증
    String idToken = authHeader.replace("Bearer ", "");
    FirebaseToken decodedToken = firebaseAuthService.verifyIdToken(idToken);

    // 페이지네이션 검증
    if (size > 100) {
        size = 100;
    }

    Pageable pageable = PageRequest.of(page, size, Sort.by("createdAt").descending());

    // 서비스 호출
    Page<CommentDTO> comments = commentService.getCommentsByUserId(userId, pageable);

    // 응답
    PagedCommentsResponse response = PagedCommentsResponse.builder()
            .comments(comments.getContent())
            .currentPage(comments.getNumber())
            .pageSize(comments.getSize())
            .totalElements(comments.getTotalElements())
            .totalPages(comments.getTotalPages())
            .hasNext(comments.hasNext())
            .hasPrevious(comments.hasPrevious())
            .build();

    return ResponseEntity.ok(ApiResponse.success(response));
}
```

### Service

```java
@Transactional(readOnly = true)
public Page<CommentDTO> getCommentsByUserId(Long userId, Pageable pageable) {
    log.info("사용자별 댓글 조회 - userId: {}, page: {}", userId, pageable.getPageNumber());

    // 1. 사용자 존재 확인
    User user = userRepository.findById(userId)
            .orElseThrow(() -> new NotFoundException("사용자를 찾을 수 없습니다."));

    // 2. 댓글 조회 (사진 정보 포함)
    Page<Comment> comments = commentRepository.findByRecorderUserIdAndIsDeletedFalse(
            userId,
            pageable
    );

    // 3. DTO 변환
    return comments.map(comment -> {
        WaveformData waveformData = null;
        if (comment.getType() == CommentType.AUDIO) {
            waveformData = waveformDataRepository.findByCommentId(comment.getId())
                    .orElse(null);
        }

        CommentDTO dto = CommentDTO.from(comment, waveformData);

        // 사진 정보 추가
        Photo photo = comment.getPhoto();
        dto.setPhotoThumbnailUrl(photo.getThumbnailUrl());
        dto.setPhotoUploadedAt(photo.getUploadedAt());

        return dto;
    });
}
```

### Repository

```java
@Query("""
    SELECT c FROM Comment c
    LEFT JOIN FETCH c.recorderUser u
    LEFT JOIN FETCH c.photo p
    WHERE c.recorderUser.id = :userId
      AND c.isDeleted = false
    ORDER BY c.createdAt DESC
""")
Page<Comment> findByRecorderUserIdAndIsDeletedFalse(@Param("userId") Long userId, Pageable pageable);
```

---

## 5. 댓글 위치 수정

### 입력 (Input)

```json
{
  "relativeX": 0.6,
  "relativeY": 0.4
}
```

### Controller

```java
@PutMapping("/{commentId}/position")
public ResponseEntity<ApiResponse<CommentDTO>> updateCommentPosition(
        @PathVariable String photoId,
        @PathVariable Long commentId,
        @RequestBody @Valid UpdateCommentPositionRequest request,
        @RequestHeader("Authorization") String authHeader
) {
    // Firebase ID Token 검증
    String idToken = authHeader.replace("Bearer ", "");
    FirebaseToken decodedToken = firebaseAuthService.verifyIdToken(idToken);
    String userId = decodedToken.getUid();

    // 서비스 호출
    CommentDTO commentDTO = commentService.updateCommentPosition(
            photoId,
            commentId,
            request,
            userId
    );

    // 응답
    return ResponseEntity.ok(ApiResponse.success(commentDTO, "댓글 위치가 수정되었습니다."));
}
```

### Service

```java
@Transactional
public CommentDTO updateCommentPosition(
        String photoId,
        Long commentId,
        UpdateCommentPositionRequest request,
        String currentUserId
) {
    log.info("댓글 위치 수정 - commentId: {}, userId: {}", commentId, currentUserId);

    // 1. 사용자 확인
    User currentUser = userRepository.findByFirebaseUid(currentUserId)
            .orElseThrow(() -> new NotFoundException("사용자를 찾을 수 없습니다."));

    // 2. 댓글 조회
    Comment comment = commentRepository.findById(commentId)
            .orElseThrow(() -> new NotFoundException("댓글을 찾을 수 없습니다."));

    // 3. 사진 일치 확인
    if (!comment.getPhoto().getId().equals(photoId)) {
        throw new ValidationException("해당 사진의 댓글이 아닙니다.");
    }

    // 4. 권한 확인 (본인만 수정 가능)
    if (!comment.getRecorderUser().getId().equals(currentUser.getId())) {
        throw new ForbiddenException("본인의 댓글만 수정할 수 있습니다.");
    }

    // 5. 좌표 검증
    validateCoordinates(request.getRelativeX(), request.getRelativeY());

    // 6. 위치 업데이트
    comment.setRelativeX(request.getRelativeX());
    comment.setRelativeY(request.getRelativeY());

    comment = commentRepository.save(comment);

    // 7. DTO 변환 및 반환
    WaveformData waveformData = null;
    if (comment.getType() == CommentType.AUDIO) {
        waveformData = waveformDataRepository.findByCommentId(comment.getId())
                .orElse(null);
    }

    return CommentDTO.from(comment, waveformData);
}

private void validateCoordinates(BigDecimal x, BigDecimal y) {
    if (x == null || x.compareTo(BigDecimal.ZERO) < 0 || x.compareTo(BigDecimal.ONE) > 0) {
        throw new ValidationException("X 좌표는 0.0 ~ 1.0 사이여야 합니다.");
    }
    if (y == null || y.compareTo(BigDecimal.ZERO) < 0 || y.compareTo(BigDecimal.ONE) > 0) {
        throw new ValidationException("Y 좌표는 0.0 ~ 1.0 사이여야 합니다.");
    }
}
```

---

## 6. 프로필 이미지 일괄 업데이트

### 입력 (Input)

```json
{
  "newProfileImageUrl": "https://storage.googleapis.com/soi-app/profile_images/user_456_new.jpg"
}
```

### Controller

```java
@PatchMapping("/users/{userId}/comments/profile-image")
public ResponseEntity<ApiResponse<UpdateProfileImageResponse>> updateUserProfileImageInComments(
        @PathVariable Long userId,
        @RequestBody @Valid UpdateUserProfileImageRequest request,
        @RequestHeader("Authorization") String authHeader
) {
    // Firebase ID Token 검증
    String idToken = authHeader.replace("Bearer ", "");
    FirebaseToken decodedToken = firebaseAuthService.verifyIdToken(idToken);
    String currentUserId = decodedToken.getUid();

    // 서비스 호출
    int updatedCount = commentService.updateUserProfileImageInComments(
            userId,
            request.getNewProfileImageUrl(),
            currentUserId
    );

    // 응답
    UpdateProfileImageResponse response = UpdateProfileImageResponse.builder()
            .updatedCommentsCount(updatedCount)
            .newProfileImageUrl(request.getNewProfileImageUrl())
            .build();

    return ResponseEntity.ok(ApiResponse.success(
            response,
            updatedCount + "개의 댓글 프로필 이미지가 업데이트되었습니다."
    ));
}
```

### Service

```java
@Transactional
public int updateUserProfileImageInComments(
        Long userId,
        String newProfileImageUrl,
        String currentUserId
) {
    log.info("댓글 프로필 이미지 일괄 업데이트 - userId: {}", userId);

    // 1. 권한 확인 (본인만 가능)
    User currentUser = userRepository.findByFirebaseUid(currentUserId)
            .orElseThrow(() -> new NotFoundException("사용자를 찾을 수 없습니다."));

    if (!currentUser.getId().equals(userId)) {
        throw new ForbiddenException("본인의 프로필 이미지만 수정할 수 있습니다.");
    }

    // 2. URL 검증
    if (newProfileImageUrl == null || newProfileImageUrl.trim().isEmpty()) {
        throw new ValidationException("프로필 이미지 URL이 필요합니다.");
    }

    if (!isValidImageUrl(newProfileImageUrl)) {
        throw new ValidationException("유효하지 않은 이미지 URL입니다.");
    }

    // 3. 일괄 업데이트
    int updatedCount = commentRepository.updateProfileImageUrlByRecorderUserId(
            userId,
            newProfileImageUrl
    );

    log.info("프로필 이미지 업데이트 완료 - updatedCount: {}", updatedCount);

    return updatedCount;
}

private boolean isValidImageUrl(String url) {
    // URL 형식 검증
    try {
        new URL(url);
        return url.startsWith("http://") || url.startsWith("https://");
    } catch (Exception e) {
        return false;
    }
}
```

### Repository

```java
@Modifying
@Query("""
    UPDATE Comment c
    SET c.profileImageUrl = :newProfileImageUrl
    WHERE c.recorderUser.id = :userId
      AND c.isDeleted = false
""")
int updateProfileImageUrlByRecorderUserId(
        @Param("userId") Long userId,
        @Param("newProfileImageUrl") String newProfileImageUrl
);
```

---

## 7. 댓글 삭제

### 입력 (Input)

```http
DELETE /api/photos/{photoId}/comments/{commentId}
Authorization: Bearer {idToken}
```

### Controller

```java
@DeleteMapping("/{commentId}")
public ResponseEntity<ApiResponse<Void>> deleteComment(
        @PathVariable String photoId,
        @PathVariable Long commentId,
        @RequestHeader("Authorization") String authHeader
) {
    // Firebase ID Token 검증
    String idToken = authHeader.replace("Bearer ", "");
    FirebaseToken decodedToken = firebaseAuthService.verifyIdToken(idToken);
    String userId = decodedToken.getUid();

    // 서비스 호출
    commentService.deleteComment(photoId, commentId, userId);

    // 응답
    return ResponseEntity.ok(ApiResponse.success(null, "댓글이 삭제되었습니다."));
}
```

### Service

```java
@Transactional
public void deleteComment(String photoId, Long commentId, String currentUserId) {
    log.info("댓글 삭제 - commentId: {}, userId: {}", commentId, currentUserId);

    // 1. 사용자 확인
    User currentUser = userRepository.findByFirebaseUid(currentUserId)
            .orElseThrow(() -> new NotFoundException("사용자를 찾을 수 없습니다."));

    // 2. 댓글 조회
    Comment comment = commentRepository.findById(commentId)
            .orElseThrow(() -> new NotFoundException("댓글을 찾을 수 없습니다."));

    // 3. 사진 일치 확인
    if (!comment.getPhoto().getId().equals(photoId)) {
        throw new ValidationException("해당 사진의 댓글이 아닙니다.");
    }

    // 4. 권한 확인 (본인만 삭제 가능)
    if (!comment.getRecorderUser().getId().equals(currentUser.getId())) {
        throw new ForbiddenException("자신의 댓글만 삭제할 수 있습니다.");
    }

    // 5. Soft Delete 처리
    comment.setIsDeleted(true);
    commentRepository.save(comment);

    log.info("댓글 소프트 삭제 완료 - commentId: {}", commentId);

    // 6. S3 파일 삭제 (비동기, 음성 댓글인 경우만)
    if (comment.getType() == CommentType.AUDIO && comment.getAudioUrl() != null) {
        CompletableFuture.runAsync(() -> {
            try {
                s3Service.deleteFile(comment.getAudioUrl());
                log.info("S3 파일 삭제 완료 - audioUrl: {}", comment.getAudioUrl());
            } catch (Exception e) {
                log.error("S3 파일 삭제 실패 (DB는 삭제됨): {}", e.getMessage());
            }
        });
    }
}
```

---

## 8. 실시간 스트림

### WebSocket 방식 (권장)

#### WebSocket Configuration

```java
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        config.enableSimpleBroker("/topic");
        config.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws")
                .setAllowedOrigins("*")
                .withSockJS();
    }
}
```

#### WebSocket Controller

```java
@Controller
@RequiredArgsConstructor
@Slf4j
public class CommentWebSocketController {

    private final SimpMessagingTemplate messagingTemplate;

    /**
     * 댓글이 생성될 때 호출되어 실시간으로 전송
     */
    public void sendCommentCreated(String photoId, CommentDTO commentDTO) {
        String destination = "/topic/photos/" + photoId + "/comments";

        CommentEvent event = CommentEvent.builder()
                .type(CommentEventType.CREATED)
                .comment(commentDTO)
                .timestamp(LocalDateTime.now())
                .build();

        messagingTemplate.convertAndSend(destination, event);

        log.info("WebSocket 메시지 전송 - photoId: {}, commentId: {}",
                photoId, commentDTO.getId());
    }

    /**
     * 댓글이 삭제될 때 호출되어 실시간으로 전송
     */
    public void sendCommentDeleted(String photoId, Long commentId) {
        String destination = "/topic/photos/" + photoId + "/comments";

        CommentEvent event = CommentEvent.builder()
                .type(CommentEventType.DELETED)
                .commentId(commentId)
                .timestamp(LocalDateTime.now())
                .build();

        messagingTemplate.convertAndSend(destination, event);

        log.info("WebSocket 삭제 메시지 전송 - photoId: {}, commentId: {}",
                photoId, commentId);
    }

    /**
     * 댓글 위치가 수정될 때 호출되어 실시간으로 전송
     */
    public void sendCommentUpdated(String photoId, CommentDTO commentDTO) {
        String destination = "/topic/photos/" + photoId + "/comments";

        CommentEvent event = CommentEvent.builder()
                .type(CommentEventType.UPDATED)
                .comment(commentDTO)
                .timestamp(LocalDateTime.now())
                .build();

        messagingTemplate.convertAndSend(destination, event);

        log.info("WebSocket 업데이트 메시지 전송 - photoId: {}, commentId: {}",
                photoId, commentDTO.getId());
    }
}
```

#### Service에서 WebSocket 호출

```java
@Service
@RequiredArgsConstructor
public class CommentService {

    private final CommentWebSocketController webSocketController;

    @Transactional
    public CommentDTO createAudioComment(...) {
        // ... 댓글 생성 로직 ...

        CommentDTO commentDTO = CommentDTO.from(comment, waveformData);

        // WebSocket으로 실시간 전송
        webSocketController.sendCommentCreated(photoId, commentDTO);

        return commentDTO;
    }

    @Transactional
    public void deleteComment(...) {
        // ... 삭제 로직 ...

        // WebSocket으로 삭제 이벤트 전송
        webSocketController.sendCommentDeleted(photoId, commentId);
    }
}
```

### Flutter에서 WebSocket 연결

```dart
import 'package:stomp_dart_client/stomp_dart_client.dart';

class CommentWebSocketService {
  StompClient? _stompClient;

  void connect(String photoId, Function(CommentEvent) onCommentEvent) {
    _stompClient = StompClient(
      config: StompConfig(
        url: 'ws://api.soi-app.com/ws',
        onConnect: (StompFrame frame) {
          // 특정 사진의 댓글 구독
          _stompClient!.subscribe(
            destination: '/topic/photos/$photoId/comments',
            callback: (StompFrame frame) {
              if (frame.body != null) {
                final event = CommentEvent.fromJson(jsonDecode(frame.body!));
                onCommentEvent(event);
              }
            },
          );
        },
        onWebSocketError: (dynamic error) {
          print('WebSocket 에러: $error');
        },
      ),
    );

    _stompClient!.activate();
  }

  void disconnect() {
    _stompClient?.deactivate();
  }
}
```

---

## 부록: 주요 엔티티 및 DTO

### Comment Entity

```java
@Entity
@Table(name = "comments", indexes = {
    @Index(name = "idx_comments_photo_created", columnList = "photo_id, created_at"),
    @Index(name = "idx_comments_user", columnList = "recorder_user_id, created_at"),
    @Index(name = "idx_comments_is_deleted", columnList = "is_deleted")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Comment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "photo_id", nullable = false)
    private Photo photo;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "recorder_user_id", nullable = false)
    private User recorderUser;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private CommentType type; // AUDIO, TEXT, EMOJI

    @Column(name = "audio_url", length = 500)
    private String audioUrl;

    @Column(columnDefinition = "TEXT")
    private String text;

    @Column
    private Integer duration; // milliseconds

    @Column(name = "profile_image_url", nullable = false, length = 500)
    private String profileImageUrl;

    @Column(name = "relative_x", precision = 5, scale = 4)
    private BigDecimal relativeX;

    @Column(name = "relative_y", precision = 5, scale = 4)
    private BigDecimal relativeY;

    @Column(name = "is_deleted", nullable = false)
    private Boolean isDeleted = false;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @OneToOne(mappedBy = "comment", cascade = CascadeType.ALL, orphanRemoval = true)
    private WaveformData waveformData;
}
```

### WaveformData Entity

```java
@Entity
@Table(name = "waveform_data")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WaveformData {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "comment_id", nullable = false, unique = true)
    private Comment comment;

    @Type(JsonBinaryType.class)
    @Column(columnDefinition = "jsonb", nullable = false)
    private List<Double> data;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
}
```

### CommentDTO

```java
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CommentDTO {

    private Long id;
    private String photoId;
    private Long recorderUserId;
    private String recorderNickname;
    private String recorderName;
    private CommentType type;
    private String audioUrl;
    private String text;
    private Integer duration;
    private List<Double> waveformData;
    private String profileImageUrl;
    private BigDecimal relativeX;
    private BigDecimal relativeY;
    private LocalDateTime createdAt;

    // 사용자별 댓글 조회 시 추가 정보
    private String photoThumbnailUrl;
    private LocalDateTime photoUploadedAt;

    public static CommentDTO from(Comment comment, WaveformData waveformData) {
        return CommentDTO.builder()
                .id(comment.getId())
                .photoId(comment.getPhoto().getId())
                .recorderUserId(comment.getRecorderUser().getId())
                .recorderNickname(comment.getRecorderUser().getNickname())
                .recorderName(comment.getRecorderUser().getName())
                .type(comment.getType())
                .audioUrl(comment.getAudioUrl())
                .text(comment.getText())
                .duration(comment.getDuration())
                .waveformData(waveformData != null ? waveformData.getData() : null)
                .profileImageUrl(comment.getProfileImageUrl())
                .relativeX(comment.getRelativeX())
                .relativeY(comment.getRelativeY())
                .createdAt(comment.getCreatedAt())
                .build();
    }
}
```

### Request DTOs

```java
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateAudioCommentRequest {

    @NotNull(message = "음성 파일이 필요합니다")
    private MultipartFile audioFile;

    @NotNull(message = "파형 데이터가 필요합니다")
    @Size(min = 1, message = "파형 데이터는 비어있을 수 없습니다")
    private List<Double> waveformData;

    @NotNull(message = "녹음 시간이 필요합니다")
    @Min(value = 1000, message = "녹음 시간은 최소 1초여야 합니다")
    @Max(value = 300000, message = "녹음 시간은 최대 5분까지입니다")
    private Integer duration;

    @NotNull(message = "X 좌표가 필요합니다")
    @DecimalMin(value = "0.0", message = "X 좌표는 0.0 이상이어야 합니다")
    @DecimalMax(value = "1.0", message = "X 좌표는 1.0 이하여야 합니다")
    private BigDecimal relativeX;

    @NotNull(message = "Y 좌표가 필요합니다")
    @DecimalMin(value = "0.0", message = "Y 좌표는 0.0 이상이어야 합니다")
    @DecimalMax(value = "1.0", message = "Y 좌표는 1.0 이하여야 합니다")
    private BigDecimal relativeY;
}

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateTextCommentRequest {

    @NotBlank(message = "댓글 내용이 필요합니다")
    @Size(max = 1000, message = "댓글은 최대 1000자까지 입력 가능합니다")
    private String text;

    @NotNull(message = "X 좌표가 필요합니다")
    @DecimalMin(value = "0.0")
    @DecimalMax(value = "1.0")
    private BigDecimal relativeX;

    @NotNull(message = "Y 좌표가 필요합니다")
    @DecimalMin(value = "0.0")
    @DecimalMax(value = "1.0")
    private BigDecimal relativeY;
}

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UpdateCommentPositionRequest {

    @NotNull(message = "X 좌표가 필요합니다")
    @DecimalMin(value = "0.0")
    @DecimalMax(value = "1.0")
    private BigDecimal relativeX;

    @NotNull(message = "Y 좌표가 필요합니다")
    @DecimalMin(value = "0.0")
    @DecimalMax(value = "1.0")
    private BigDecimal relativeY;
}

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UpdateUserProfileImageRequest {

    @NotBlank(message = "프로필 이미지 URL이 필요합니다")
    @Pattern(regexp = "^https?://.*", message = "유효한 URL 형식이어야 합니다")
    private String newProfileImageUrl;
}
```

---

## 요약

이 문서는 **음성/텍스트 댓글 시스템의 모든 기능**을 Spring Boot 코드로 상세히 정리했습니다:

### 구현된 기능

1. ✅ **음성 댓글 생성**: 파일 업로드 → S3 저장 → DB 저장 → 알림 전송
2. ✅ **텍스트 댓글 생성**: 입력 검증 → DB 저장 → 알림 전송
3. ✅ **댓글 조회**: 페이지네이션, JOIN FETCH로 N+1 방지
4. ✅ **댓글 위치 수정**: 권한 확인 후 상대 좌표 업데이트
5. ✅ **프로필 이미지 일괄 업데이트**: 사용자의 모든 댓글 프로필 이미지 변경
6. ✅ **댓글 삭제**: Soft Delete + S3 파일 비동기 삭제
7. ✅ **실시간 스트림**: WebSocket을 통한 실시간 댓글 업데이트

### 주요 기술 스택

- **Framework**: Spring Boot 3.x
- **Database**: PostgreSQL (JSONB 지원)
- **Storage**: AWS S3
- **Real-time**: WebSocket (STOMP)
- **Authentication**: Firebase ID Token
- **Validation**: Bean Validation (JSR-380)
- **ORM**: JPA/Hibernate

### 성능 최적화

- JOIN FETCH로 N+1 쿼리 문제 방지
- 페이지네이션으로 대용량 데이터 처리
- 파형 데이터를 별도 테이블로 분리하여 조회 성능 개선
- 비동기 알림 전송으로 응답 속도 개선
- S3 파일 삭제를 비동기로 처리

### 보안 고려사항

- Firebase ID Token 검증
- Rate Limiting (분당 10회)
- 권한 검증 (본인만 수정/삭제)
- 파일 형식 및 크기 검증
- SQL Injection 방지 (JPA 사용)
