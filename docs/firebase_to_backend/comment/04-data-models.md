# 음성/텍스트 댓글 시스템 - 데이터 모델

이 문서는 음성/텍스트 댓글 시스템의 **데이터베이스 스키마**, **엔티티**, **DTO**를 정의합니다.

---

## 📋 목차

1. [데이터베이스 스키마](#데이터베이스-스키마)
2. [엔티티 클래스](#엔티티-클래스)
3. [DTO 클래스](#dto-클래스)
4. [Firebase vs Spring Boot 비교](#firebase-vs-spring-boot-비교)
5. [데이터 마이그레이션](#데이터-마이그레이션)

---

## 데이터베이스 스키마

### 1. comments 테이블

```sql
CREATE TABLE comments (
    id BIGSERIAL PRIMARY KEY,
    photo_id BIGINT NOT NULL,
    recorder_user_id BIGINT NOT NULL,
    type VARCHAR(20) NOT NULL DEFAULT 'audio',
    audio_url VARCHAR(500),
    text TEXT,
    duration INT DEFAULT 0,
    profile_image_url VARCHAR(500) NOT NULL,
    relative_x DECIMAL(5,4),
    relative_y DECIMAL(5,4),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- 외래키 제약
    CONSTRAINT fk_photo FOREIGN KEY (photo_id)
        REFERENCES photos(id) ON DELETE CASCADE,
    CONSTRAINT fk_recorder_user FOREIGN KEY (recorder_user_id)
        REFERENCES users(id) ON DELETE CASCADE,

    -- CHECK 제약
    CONSTRAINT check_comment_type
        CHECK (type IN ('audio', 'text', 'emoji')),
    CONSTRAINT check_audio_comment
        CHECK (type != 'audio' OR audio_url IS NOT NULL),
    CONSTRAINT check_text_comment
        CHECK (type != 'text' OR text IS NOT NULL),
    CONSTRAINT check_relative_x
        CHECK (relative_x IS NULL OR (relative_x >= 0.0 AND relative_x <= 1.0)),
    CONSTRAINT check_relative_y
        CHECK (relative_y IS NULL OR (relative_y >= 0.0 AND relative_y <= 1.0)),
    CONSTRAINT check_duration
        CHECK (duration >= 0 AND duration <= 300000)
);

-- 인덱스
CREATE INDEX idx_comments_photo_created
    ON comments(photo_id, created_at)
    WHERE is_deleted = FALSE;

CREATE INDEX idx_comments_user
    ON comments(recorder_user_id, created_at DESC)
    WHERE is_deleted = FALSE;

CREATE INDEX idx_comments_is_deleted
    ON comments(is_deleted);

-- Updated_at 자동 업데이트 트리거
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_comments_updated_at
    BEFORE UPDATE ON comments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

### 2. waveform_data 테이블

```sql
CREATE TABLE waveform_data (
    id BIGSERIAL PRIMARY KEY,
    comment_id BIGINT NOT NULL UNIQUE,
    data JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- 외래키 제약
    CONSTRAINT fk_comment FOREIGN KEY (comment_id)
        REFERENCES comments(id) ON DELETE CASCADE
);

-- 인덱스
CREATE INDEX idx_waveform_comment
    ON waveform_data(comment_id);

-- JSONB 인덱스 (선택 사항)
CREATE INDEX idx_waveform_data_gin
    ON waveform_data USING GIN (data);
```

---

## 엔티티 클래스

### Comment 엔티티

```java
@Entity
@Table(name = "comments")
public class Comment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "photo_id", nullable = false)
    private Long photoId;

    @Column(name = "recorder_user_id", nullable = false)
    private Long recorderUserId;

    @Enumerated(EnumType.STRING)
    @Column(name = "type", nullable = false, length = 20)
    private CommentType type = CommentType.AUDIO;

    @Column(name = "audio_url", length = 500)
    private String audioUrl;

    @Column(name = "text", columnDefinition = "TEXT")
    private String text;

    @Column(name = "duration")
    private Integer duration = 0;

    @Column(name = "profile_image_url", nullable = false, length = 500)
    private String profileImageUrl;

    @Column(name = "relative_x", precision = 5, scale = 4)
    private BigDecimal relativeX;

    @Column(name = "relative_y", precision = 5, scale = 4)
    private BigDecimal relativeY;

    @Column(name = "is_deleted", nullable = false)
    private Boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    @CreationTimestamp
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    @UpdateTimestamp
    private LocalDateTime updatedAt;

    // 연관 관계 (선택 사항)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "photo_id", insertable = false, updatable = false)
    private Photo photo;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "recorder_user_id", insertable = false, updatable = false)
    private User recorderUser;

    @OneToOne(mappedBy = "comment", cascade = CascadeType.ALL, orphanRemoval = true)
    private WaveformData waveformData;

    // Getters, Setters, Constructors...
}
```

### CommentType Enum

```java
public enum CommentType {
    AUDIO("audio"),
    TEXT("text"),
    EMOJI("emoji");

    private final String value;

    CommentType(String value) {
        this.value = value;
    }

    public String getValue() {
        return value;
    }
}
```

### WaveformData 엔티티

```java
@Entity
@Table(name = "waveform_data")
public class WaveformData {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "comment_id", nullable = false, unique = true)
    private Long commentId;

    @Type(type = "jsonb")
    @Column(name = "data", nullable = false, columnDefinition = "jsonb")
    private List<Double> data;

    @Column(name = "created_at", nullable = false, updatable = false)
    @CreationTimestamp
    private LocalDateTime createdAt;

    // 연관 관계
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "comment_id", insertable = false, updatable = false)
    private Comment comment;

    // Getters, Setters, Constructors...
}
```

---

## DTO 클래스

### 1. CommentDTO (응답용)

```java
public class CommentDTO {
    private Long id;
    private Long photoId;
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

    // Static factory method
    public static CommentDTO from(Comment comment, User user, WaveformData waveform) {
        CommentDTO dto = new CommentDTO();
        dto.setId(comment.getId());
        dto.setPhotoId(comment.getPhotoId());
        dto.setRecorderUserId(comment.getRecorderUserId());
        dto.setRecorderNickname(user.getNickname());
        dto.setRecorderName(user.getName());
        dto.setType(comment.getType());
        dto.setAudioUrl(comment.getAudioUrl());
        dto.setText(comment.getText());
        dto.setDuration(comment.getDuration());
        dto.setWaveformData(waveform != null ? waveform.getData() : null);
        dto.setProfileImageUrl(comment.getProfileImageUrl());
        dto.setRelativeX(comment.getRelativeX());
        dto.setRelativeY(comment.getRelativeY());
        dto.setCreatedAt(comment.getCreatedAt());
        return dto;
    }

    // Getters, Setters...
}
```

### 2. CreateAudioCommentRequest

```java
public class CreateAudioCommentRequest {

    @NotNull(message = "오디오 파일이 필요합니다")
    private MultipartFile audioFile;

    @NotNull(message = "파형 데이터가 필요합니다")
    @Size(min = 1, message = "파형 데이터는 최소 1개 이상이어야 합니다")
    private List<Double> waveformData;

    @NotNull(message = "재생 시간이 필요합니다")
    @Min(value = 1000, message = "재생 시간은 최소 1초 이상이어야 합니다")
    @Max(value = 300000, message = "재생 시간은 최대 5분 이하여야 합니다")
    private Integer duration;

    @DecimalMin(value = "0.0", message = "X 좌표는 0.0 이상이어야 합니다")
    @DecimalMax(value = "1.0", message = "X 좌표는 1.0 이하여야 합니다")
    private BigDecimal relativeX;

    @DecimalMin(value = "0.0", message = "Y 좌표는 0.0 이상이어야 합니다")
    @DecimalMax(value = "1.0", message = "Y 좌표는 1.0 이하여야 합니다")
    private BigDecimal relativeY;

    // Getters, Setters...
}
```

### 3. CreateTextCommentRequest

```java
public class CreateTextCommentRequest {

    @NotBlank(message = "댓글 내용을 입력해주세요")
    @Size(max = 1000, message = "댓글은 최대 1000자까지 입력 가능합니다")
    private String text;

    @DecimalMin(value = "0.0")
    @DecimalMax(value = "1.0")
    private BigDecimal relativeX;

    @DecimalMin(value = "0.0")
    @DecimalMax(value = "1.0")
    private BigDecimal relativeY;

    // Getters, Setters...
}
```

### 4. UpdateCommentPositionRequest

```java
public class UpdateCommentPositionRequest {

    @NotNull(message = "X 좌표가 필요합니다")
    @DecimalMin(value = "0.0", message = "X 좌표는 0.0 이상이어야 합니다")
    @DecimalMax(value = "1.0", message = "X 좌표는 1.0 이하여야 합니다")
    private BigDecimal relativeX;

    @NotNull(message = "Y 좌표가 필요합니다")
    @DecimalMin(value = "0.0", message = "Y 좌표는 0.0 이상이어야 합니다")
    @DecimalMax(value = "1.0", message = "Y 좌표는 1.0 이하여야 합니다")
    private BigDecimal relativeY;

    // Getters, Setters...
}
```

### 5. UpdateUserProfileImageRequest

```java
public class UpdateUserProfileImageRequest {

    @NotBlank(message = "프로필 이미지 URL이 필요합니다")
    @Pattern(regexp = "^https?://.*\\.(jpg|jpeg|png|webp)$",
             message = "유효한 이미지 URL이 아닙니다")
    private String newProfileImageUrl;

    // Getters, Setters...
}
```

### 6. CommentListResponse

```java
public class CommentListResponse {
    private List<CommentDTO> comments;
    private PaginationInfo pagination;

    public static class PaginationInfo {
        private int currentPage;
        private int pageSize;
        private long totalElements;
        private int totalPages;
        private boolean hasNext;
        private boolean hasPrevious;

        // Getters, Setters...
    }

    // Getters, Setters...
}
```

---

## Firebase vs Spring Boot 비교

### Firestore 문서 구조 (현재)

```json
{
  "id": "comment_abc123",
  "audioUrl": "https://firebasestorage.googleapis.com/.../audio.aac",
  "photoId": "photo_xyz789",
  "recorderUser": "user_456",
  "createdAt": {
    "_seconds": 1705302000,
    "_nanoseconds": 123456000
  },
  "waveformData": [0.5, 0.8, 0.3, 0.9, ...],
  "duration": 5000,
  "profileImageUrl": "https://firebasestorage.googleapis.com/.../profile.jpg",
  "relativePosition": {
    "x": 0.5,
    "y": 0.3
  },
  "type": "audio",
  "text": null,
  "isDeleted": false
}
```

### PostgreSQL 테이블 구조 (마이그레이션 후)

```sql
-- comments 테이블
id              | 123
photo_id        | 789
recorder_user_id| 456
type            | 'audio'
audio_url       | 'https://s3.amazonaws.com/.../audio.aac'
text            | NULL
duration        | 5000
profile_image_url| 'https://s3.amazonaws.com/.../profile.jpg'
relative_x      | 0.5000
relative_y      | 0.3000
is_deleted      | FALSE
created_at      | '2025-01-15 10:00:00'
updated_at      | '2025-01-15 10:00:00'

-- waveform_data 테이블
id              | 1
comment_id      | 123
data            | '[0.5, 0.8, 0.3, 0.9, ...]'  -- JSONB
created_at      | '2025-01-15 10:00:00'
```

### 주요 차이점

| 항목            | Firebase                 | Spring Boot                       |
| --------------- | ------------------------ | --------------------------------- |
| ID 타입         | String (자동 생성)       | BIGINT (AUTO_INCREMENT)           |
| 타임스탬프      | Timestamp 객체           | LocalDateTime                     |
| 위치 데이터     | Map {x, y}               | 2개 컬럼 (relative_x, relative_y) |
| 파형 데이터     | Array (문서 내)          | JSONB (별도 테이블)               |
| 외래키          | 없음 (애플리케이션 레벨) | FOREIGN KEY 제약                  |
| 인덱스          | 수동 생성                | CREATE INDEX                      |
| 실시간 업데이트 | Snapshot Listener        | WebSocket/SSE                     |

---

## 데이터 마이그레이션

### Firebase → PostgreSQL 마이그레이션 스크립트

```java
public class CommentMigrationService {

    private final Firestore firestore;
    private final JdbcTemplate jdbcTemplate;

    public void migrateAllComments() {
        // 1. Firestore에서 모든 댓글 조회
        CollectionReference commentsRef = firestore.collection("comment_records");
        ApiFuture<QuerySnapshot> query = commentsRef.get();

        try {
            QuerySnapshot querySnapshot = query.get();
            List<QueryDocumentSnapshot> documents = querySnapshot.getDocuments();

            log.info("마이그레이션 시작: {} 개 댓글", documents.size());

            for (QueryDocumentSnapshot doc : documents) {
                try {
                    migrateComment(doc);
                } catch (Exception e) {
                    log.error("댓글 마이그레이션 실패: {}", doc.getId(), e);
                }
            }

            log.info("마이그레이션 완료");

        } catch (Exception e) {
            log.error("마이그레이션 실패", e);
            throw new RuntimeException("마이그레이션 실패", e);
        }
    }

    private void migrateComment(QueryDocumentSnapshot doc) {
        Map<String, Object> data = doc.getData();

        // 2. Firestore 데이터 → PostgreSQL 변환
        String photoId = (String) data.get("photoId");
        String recorderUser = (String) data.get("recorderUser");
        String type = (String) data.getOrDefault("type", "audio");
        String audioUrl = (String) data.get("audioUrl");
        String text = (String) data.get("text");
        Long duration = ((Number) data.getOrDefault("duration", 0)).longValue();
        String profileImageUrl = (String) data.get("profileImageUrl");
        Boolean isDeleted = (Boolean) data.getOrDefault("isDeleted", false);

        // Timestamp 변환
        Timestamp createdAtTimestamp = (Timestamp) data.get("createdAt");
        LocalDateTime createdAt = LocalDateTime.ofInstant(
            createdAtTimestamp.toDate().toInstant(),
            ZoneId.systemDefault()
        );

        // relativePosition 변환
        Map<String, Object> relativePosition =
            (Map<String, Object>) data.get("relativePosition");
        BigDecimal relativeX = null;
        BigDecimal relativeY = null;
        if (relativePosition != null) {
            relativeX = BigDecimal.valueOf(((Number) relativePosition.get("x")).doubleValue());
            relativeY = BigDecimal.valueOf(((Number) relativePosition.get("y")).doubleValue());
        }

        // waveformData 추출
        List<Double> waveformData = (List<Double>) data.get("waveformData");

        // 3. users 테이블에서 recorder_user_id 조회
        Long recorderUserId = jdbcTemplate.queryForObject(
            "SELECT id FROM users WHERE firebase_uid = ?",
            Long.class,
            recorderUser
        );

        // 4. photos 테이블에서 photo_id 조회
        Long photoIdLong = jdbcTemplate.queryForObject(
            "SELECT id FROM photos WHERE firebase_id = ?",
            Long.class,
            photoId
        );

        // 5. comments 테이블 INSERT
        String insertCommentSql = """
            INSERT INTO comments (
                photo_id, recorder_user_id, type, audio_url, text,
                duration, profile_image_url, relative_x, relative_y,
                is_deleted, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            RETURNING id
            """;

        Long commentId = jdbcTemplate.queryForObject(
            insertCommentSql,
            Long.class,
            photoIdLong, recorderUserId, type, audioUrl, text,
            duration, profileImageUrl, relativeX, relativeY,
            isDeleted, createdAt, createdAt
        );

        // 6. waveform_data 테이블 INSERT (음성 댓글인 경우)
        if ("audio".equals(type) && waveformData != null && !waveformData.isEmpty()) {
            String insertWaveformSql = """
                INSERT INTO waveform_data (comment_id, data, created_at)
                VALUES (?, ?::jsonb, ?)
                """;

            String waveformJson = new ObjectMapper().writeValueAsString(waveformData);

            jdbcTemplate.update(
                insertWaveformSql,
                commentId, waveformJson, createdAt
            );
        }

        log.debug("댓글 마이그레이션 완료: Firestore ID={}, PostgreSQL ID={}",
                  doc.getId(), commentId);
    }
}
```

### 마이그레이션 검증 쿼리

```sql
-- 1. 총 댓글 수 확인
SELECT COUNT(*) FROM comments;

-- 2. 타입별 댓글 수 확인
SELECT type, COUNT(*)
FROM comments
GROUP BY type;

-- 3. 파형 데이터가 있는 음성 댓글 수 확인
SELECT COUNT(*)
FROM comments c
JOIN waveform_data w ON c.id = w.comment_id
WHERE c.type = 'audio';

-- 4. 삭제되지 않은 댓글 수 확인
SELECT COUNT(*)
FROM comments
WHERE is_deleted = FALSE;

-- 5. 사진당 평균 댓글 수
SELECT AVG(comment_count)
FROM (
    SELECT photo_id, COUNT(*) AS comment_count
    FROM comments
    WHERE is_deleted = FALSE
    GROUP BY photo_id
) AS subquery;
```

---

## 🎯 다음 단계

데이터 모델을 이해했다면:

1. [05-features.md](./05-features.md)에서 기능별 구현 가이드 확인
2. 실제 Spring Boot 프로젝트에 엔티티 및 DTO 적용
3. Repository, Service, Controller 계층 구현
