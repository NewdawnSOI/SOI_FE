# Audio System - Features Implementation

## 📖 문서 목적

이 문서는 SOI 앱의 **음성 시스템**을 Spring Boot로 마이그레이션하기 위한 **기능 명세서**입니다.

Flutter 코드(AudioRepository, AudioService, AudioController)를 분석하여 백엔드에서 구현해야 할 8가지 핵심 기능을 정의합니다.

---

## 🎯 기능 개요

| 기능                    | 엔드포인트                                   | Flutter 소스                                                                                             | 설명                                |
| ----------------------- | -------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| 1. 음성 업로드          | `POST /api/v1/audios`                        | AudioService.uploadAudio()<br>AudioRepository.uploadAudioFile()<br>AudioRepository.extractWaveformData() | 음성 파일 + 파형 데이터 업로드      |
| 2. 카테고리 음성 목록   | `GET /api/v1/categories/{categoryId}/audios` | AudioRepository.getAudiosByCategory()                                                                    | 카테고리별 음성 조회 (페이지네이션) |
| 3. 사용자 음성 목록     | `GET /api/v1/users/{userId}/audios`          | AudioRepository.getAudiosByUser()                                                                        | 사용자별 음성 조회                  |
| 4. 음성 상세 조회       | `GET /api/v1/audios/{audioId}`               | AudioRepository.getAudioData()                                                                           | 특정 음성 상세 정보                 |
| 5. 파형 데이터 조회     | `GET /api/v1/audios/{audioId}/waveform`      | AudioRepository.extractWaveformData()                                                                    | 파형 데이터 별도 조회               |
| 6. 음성 메타데이터 수정 | `PUT /api/v1/audios/{audioId}`               | AudioService.updateAudioInfo()                                                                           | 파일명, 설명 수정                   |
| 7. 음성 삭제            | `DELETE /api/v1/audios/{audioId}`            | AudioService.deleteAudio()<br>AudioRepository.deleteAudioFile()                                          | 음성 및 파형 삭제                   |
| 8. 실시간 음성 알림     | WebSocket `/ws`                              | AudioRepository.getAudiosByCategoryStream()                                                              | 새 음성 업로드 실시간 알림          |

---

## 📦 Feature 1: 음성 업로드 (Audio Upload with Waveform)

### Flutter 소스 분석

**AudioService.uploadAudio()**:

```dart
Future<AuthResult> uploadAudio(String audioId) async {
  final audioData = await _repository.getAudioData(audioId);
  if (!audioData.canUpload) {
    return AuthResult.failure('업로드할 수 없는 상태입니다.');
  }

  // 상태를 업로드 중으로 업데이트
  await _repository.updateAudioData(audioId, {
    'status': AudioStatus.uploading.name,
  });

  // Firebase Storage에 업로드
  final downloadUrl = await _repository.uploadAudioFile(audioId, uploadPath);

  // 업로드 완료 상태로 업데이트
  await _repository.updateAudioData(audioId, {
    'firebaseUrl': downloadUrl,
    'status': AudioStatus.uploaded.name,
    'uploadedAt': DateTime.now(),
  });
}
```

**AudioRepository.extractWaveformData()**:

```dart
Future<List<double>> extractWaveformData(String audioFilePath) async {
  final controller = PlayerController();
  await controller.preparePlayer(
    path: audioFilePath,
    shouldExtractWaveform: true,
  );

  List<double> rawData = controller.waveformData;

  // 데이터 최적화 (100개 포인트로 압축)
  final compressedData = _compressWaveformData(rawData, targetLength: 100);
  return compressedData;
}
```

**AudioService 검증 로직**:

```dart
bool _isValidFileSize(double fileSizeInMB) {
  return fileSizeInMB <= 10.0; // 10MB 제한
}

bool _isValidDuration(int durationInSeconds) {
  return durationInSeconds <= 300; // 5분 제한
}

String? _validateAudioFileName(String fileName) {
  if (fileName.trim().isEmpty) return '파일 이름을 입력해주세요.';
  if (fileName.trim().length > 50) return '파일 이름은 50글자 이하여야 합니다.';
  return null;
}
```

### 백엔드 구현 명세

#### Input Format

**Endpoint**: `POST /api/v1/audios`

**Content-Type**: `multipart/form-data`

**Request Parameters**:

```java
public class AudioUploadRequest {
    @NotNull(message = "음성 파일은 필수입니다.")
    private MultipartFile audioFile;

    @NotNull(message = "카테고리 ID는 필수입니다.")
    private UUID categoryId;

    @NotNull(message = "파형 데이터는 필수입니다.")
    @Size(min = 50, max = 500, message = "파형 데이터는 50~500개 포인트여야 합니다.")
    private List<@DecimalMin("0.0") @DecimalMax("1.0") Double> waveformData;

    @Size(max = 500, message = "설명은 500자 이하여야 합니다.")
    private String description;
}
```

#### Process Flow

**단계 1: 파일 검증**

```
1. 파일 크기 검증: 1KB ~ 10MB (10,485,760 bytes)
2. 파일 형식 검증: AAC (.m4a, .aac), MP3 (.mp3), WAV (.wav)
   - MIME type 확인: audio/aac, audio/mpeg, audio/wav
   - 파일 확장자 확인
3. 음성 길이 검증: 1초 ~ 300초 (5분)
   - 음성 파일 메타데이터 파싱 필요
4. 파형 데이터 검증:
   - 포인트 개수: 50~500개
   - 각 값 범위: 0.0 ~ 1.0
```

**단계 2: 카테고리 멤버십 확인**

```java
Category category = categoryRepository.findById(categoryId)
    .orElseThrow(() -> new CategoryNotFoundException());

boolean isMember = categoryMemberRepository
    .existsByCategoryIdAndUserId(categoryId, currentUserId);

if (!isMember) {
    throw new ForbiddenException("카테고리 멤버만 음성을 업로드할 수 있습니다.");
}
```

**단계 3: S3 업로드**

```java
// S3 키 생성: audios/{categoryId}/{audioId}.{extension}
String s3Key = String.format("audios/%s/%s.%s",
    categoryId, audioId, fileExtension);

// S3에 업로드 (AWS SDK 사용)
PutObjectRequest putRequest = PutObjectRequest.builder()
    .bucket(s3BucketName)
    .key(s3Key)
    .contentType(audioFile.getContentType())
    .build();

s3Client.putObject(putRequest, RequestBody.fromInputStream(
    audioFile.getInputStream(), audioFile.getSize()));

// 공개 URL 생성 또는 Presigned URL 생성
String s3Url = s3Client.utilities().getUrl(builder ->
    builder.bucket(s3BucketName).key(s3Key)).toString();
```

**단계 4: PostgreSQL 저장 (트랜잭션)**

```java
@Transactional
public AudioDTO uploadAudio(AudioUploadRequest request, UUID userId) {
    // 1. Audio 엔티티 생성 및 저장
    Audio audio = Audio.builder()
        .category(category)
        .user(user)
        .fileName(generateFileName(audioFile))
        .s3Key(s3Key)
        .s3Url(s3Url)
        .durationInSeconds(extractDuration(audioFile))
        .fileSizeInBytes(audioFile.getSize())
        .format(AudioFormat.fromExtension(fileExtension))
        .status(AudioStatus.UPLOADED)
        .description(request.getDescription())
        .uploadedAt(LocalDateTime.now())
        .build();

    Audio savedAudio = audioRepository.save(audio);

    // 2. 파형 데이터 저장 (별도 테이블)
    AudioWaveformData waveform = AudioWaveformData.builder()
        .audio(savedAudio)
        .waveformData(request.getWaveformData())
        .sampleCount(request.getWaveformData().size())
        .build();

    waveformDataRepository.save(waveform);

    return AudioDTO.fromWithUser(savedAudio);
}
```

**단계 5: WebSocket 알림**

```java
// 카테고리 멤버들에게 실시간 알림
AudioNotificationMessage message = AudioNotificationMessage.builder()
    .type("NEW_AUDIO")
    .audioId(savedAudio.getId())
    .categoryId(categoryId)
    .userId(userId)
    .userName(user.getNickname())
    .fileName(savedAudio.getFileName())
    .durationInSeconds(savedAudio.getDurationInSeconds())
    .createdAt(savedAudio.getCreatedAt())
    .build();

messagingTemplate.convertAndSend(
    "/topic/categories/" + categoryId + "/audios",
    message
);
```

#### Output Format

**Success Response** (201 Created):

```json
{
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "categoryId": "550e8400-e29b-41d4-a716-446655440000",
  "userId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "fileName": "audio_1634567890.m4a",
  "s3Url": "https://soi-audios.s3.amazonaws.com/audios/550e8400.../3fa85f64....m4a",
  "durationInSeconds": 30,
  "fileSizeInBytes": 2457600,
  "format": "AAC",
  "status": "UPLOADED",
  "description": "제주도 여행 음성 메모",
  "createdAt": "2025-10-22T14:30:00Z",
  "uploadedAt": "2025-10-22T14:30:05Z",
  "user": {
    "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "nickname": "지훈",
    "profileImageUrl": "https://..."
  }
}
```

**Error Responses**:

- **400 Bad Request**: 파일 크기/길이/형식 오류, 파형 데이터 검증 실패
- **403 Forbidden**: 카테고리 멤버가 아님
- **429 Too Many Requests**: Rate limiting (분당 10개 제한)
- **500 Internal Server Error**: S3 업로드 실패

#### 구현 시 주의사항

1. **Rate Limiting**: Redis 기반 분당 10개 제한

   ```java
   @RateLimiter(name = "audioUpload", fallbackMethod = "uploadRateLimitFallback")
   ```

2. **음성 길이 추출**: FFmpeg 또는 Tika 라이브러리 사용

   ```java
   // Apache Tika 예시
   Metadata metadata = new Metadata();
   parser.parse(audioFile.getInputStream(), handler, metadata);
   String duration = metadata.get("xmpDM:duration");
   ```

3. **트랜잭션 관리**: Audio + WaveformData 원자적 저장

   ```java
   @Transactional(rollbackFor = Exception.class)
   ```

4. **비동기 처리 고려**: S3 업로드는 동기, WebSocket 알림은 비동기
   ```java
   @Async
   public void sendAudioNotification(...) { ... }
   ```

---

## 📦 Feature 2: 카테고리 음성 목록 (Category Audios Query)

### Flutter 소스 분석

**AudioRepository.getAudiosByCategory()**:

```dart
Future<List<AudioDataModel>> getAudiosByCategory(String categoryId) async {
  final querySnapshot = await _firestore
      .collection('audios')
      .where('categoryId', isEqualTo: categoryId)
      .orderBy('createdAt', descending: true)
      .get();

  return querySnapshot.docs
      .map((doc) => AudioDataModel.fromFirestore(doc.data(), doc.id))
      .toList();
}
```

**AudioController.loadAudiosByCategory()**:

```dart
Future<void> loadAudiosByCategory(String categoryId) async {
  _isLoading = true;
  notifyListeners();

  _audioList = await _audioService.getAudiosByCategory(categoryId);

  _isLoading = false;
  notifyListeners();
}
```

### 백엔드 구현 명세

#### Input Format

**Endpoint**: `GET /api/v1/categories/{categoryId}/audios`

**Path Parameters**:

- `categoryId`: UUID (카테고리 ID)

**Query Parameters**:

```java
@RequestParam(defaultValue = "0") int page,
@RequestParam(defaultValue = "20") int size,
@RequestParam(defaultValue = "createdAt,desc") String sort
```

#### Process Flow

**단계 1: 카테고리 멤버십 검증**

```java
Category category = categoryRepository.findById(categoryId)
    .orElseThrow(() -> new CategoryNotFoundException());

boolean isMember = categoryMemberRepository
    .existsByCategoryIdAndUserId(categoryId, currentUserId);

if (!isMember) {
    throw new ForbiddenException("카테고리 멤버만 음성 목록을 조회할 수 있습니다.");
}
```

**단계 2: 음성 목록 조회 (JOIN FETCH로 N+1 방지)**

```java
@Query("""
    SELECT a FROM Audio a
    JOIN FETCH a.user u
    WHERE a.category.id = :categoryId
    AND a.status = 'UPLOADED'
    ORDER BY a.createdAt DESC
    """)
Page<Audio> findByCategoryIdWithUser(
    @Param("categoryId") UUID categoryId,
    Pageable pageable
);
```

**단계 3: DTO 변환 및 페이지네이션**

```java
public Page<AudioDTO> getAudiosByCategory(UUID categoryId, Pageable pageable) {
    // 멤버십 확인 생략...

    Page<Audio> audioPage = audioRepository.findByCategoryIdWithUser(
        categoryId, pageable);

    return audioPage.map(AudioDTO::fromWithUser);
}
```

#### Output Format

**Success Response** (200 OK):

```json
{
  "content": [
    {
      "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "categoryId": "550e8400-e29b-41d4-a716-446655440000",
      "userId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "fileName": "성산일출봉 일출 🌅",
      "s3Url": "https://...",
      "durationInSeconds": 30,
      "fileSizeInBytes": 2457600,
      "format": "AAC",
      "status": "UPLOADED",
      "description": "제주도 여행 첫날",
      "createdAt": "2025-10-22T06:00:00Z",
      "user": {
        "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
        "nickname": "지훈",
        "profileImageUrl": "https://..."
      }
    }
  ],
  "pageable": {
    "pageNumber": 0,
    "pageSize": 20
  },
  "totalElements": 45,
  "totalPages": 3,
  "last": false
}
```

#### 구현 시 주의사항

1. **인덱스 최적화**: `(category_id, created_at DESC)` 복합 인덱스 필수
2. **JOIN FETCH**: N+1 문제 방지를 위해 user 정보 함께 로드
3. **파형 데이터 제외**: 목록 조회 시 파형은 포함하지 않음 (별도 엔드포인트)
4. **정렬 옵션**: createdAt, duration, fileName 등 다양한 정렬 지원

---

## 📦 Feature 3: 사용자 음성 목록 (User Audios Query)

### Flutter 소스 분석

**AudioRepository.getAudiosByUser()**:

```dart
Future<List<AudioDataModel>> getAudiosByUser(String userId) async {
  final querySnapshot = await _firestore
      .collection('audios')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .get();

  return querySnapshot.docs
      .map((doc) => AudioDataModel.fromFirestore(doc.data(), doc.id))
      .toList();
}
```

### 백엔드 구현 명세

#### Input Format

**Endpoint**:

- `GET /api/v1/users/{userId}/audios` (특정 사용자)
- `GET /api/v1/users/me/audios` (현재 로그인 사용자)

**Query Parameters**: Feature 2와 동일 (page, size, sort)

#### Process Flow

**단계 1: 사용자 음성 조회**

```java
@Query("""
    SELECT a FROM Audio a
    JOIN FETCH a.category c
    WHERE a.user.id = :userId
    AND a.status = 'UPLOADED'
    ORDER BY a.createdAt DESC
    """)
Page<Audio> findByUserIdWithCategory(
    @Param("userId") UUID userId,
    Pageable pageable
);
```

**단계 2: DTO 변환 (카테고리 이름 포함)**

```java
public Page<AudioDTO> getAudiosByUser(UUID userId, Pageable pageable) {
    Page<Audio> audioPage = audioRepository.findByUserIdWithCategory(
        userId, pageable);

    return audioPage.map(AudioDTO::fromWithCategory);
}
```

#### Output Format

**Success Response** (200 OK):

```json
{
  "content": [
    {
      "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "categoryId": "550e8400-e29b-41d4-a716-446655440000",
      "categoryName": "제주도 여행",
      "userId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "fileName": "성산일출봉 일출 🌅",
      "s3Url": "https://...",
      "durationInSeconds": 30,
      "fileSizeInBytes": 2457600,
      "format": "AAC",
      "status": "UPLOADED",
      "createdAt": "2025-10-22T06:00:00Z"
    }
  ],
  "totalElements": 12,
  "totalPages": 1
}
```

#### 구현 시 주의사항

1. **인덱스**: `(user_id, created_at DESC)` 복합 인덱스
2. **카테고리 정보**: 사용자 히스토리 조회 시 어느 카테고리의 음성인지 표시
3. **권한**: 다른 사용자의 음성 목록 조회 시 공개 범위 고려 (현재는 제한 없음)

---

## 📦 Feature 4: 음성 상세 조회 (Audio Detail Query)

### Flutter 소스 분석

**AudioRepository.getAudioData()**:

```dart
Future<AudioDataModel?> getAudioData(String audioId) async {
  final doc = await _firestore.collection('audios').doc(audioId).get();

  if (!doc.exists || doc.data() == null) return null;

  return AudioDataModel.fromFirestore(doc.data()!, doc.id);
}
```

### 백엔드 구현 명세

#### Input Format

**Endpoint**: `GET /api/v1/audios/{audioId}`

**Path Parameters**:

- `audioId`: UUID (음성 ID)

#### Process Flow

**단계 1: 음성 조회**

```java
@Query("""
    SELECT a FROM Audio a
    JOIN FETCH a.user u
    JOIN FETCH a.category c
    WHERE a.id = :audioId
    """)
Optional<Audio> findByIdWithDetails(@Param("audioId") UUID audioId);
```

**단계 2: 카테고리 멤버십 확인**

```java
Audio audio = audioRepository.findByIdWithDetails(audioId)
    .orElseThrow(() -> new AudioNotFoundException());

boolean isMember = categoryMemberRepository
    .existsByCategoryIdAndUserId(audio.getCategory().getId(), currentUserId);

if (!isMember) {
    throw new ForbiddenException("카테고리 멤버만 음성을 조회할 수 있습니다.");
}
```

**단계 3: DTO 반환**

```java
return AudioDTO.fromWithUser(audio);
```

#### Output Format

**Success Response** (200 OK):

```json
{
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "categoryId": "550e8400-e29b-41d4-a716-446655440000",
  "userId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "fileName": "성산일출봉에서 본 일출 🌅",
  "s3Url": "https://soi-audios.s3.amazonaws.com/audios/.../audio.m4a",
  "durationInSeconds": 30,
  "fileSizeInBytes": 2457600,
  "format": "AAC",
  "status": "UPLOADED",
  "description": "제주도 여행 첫날 일출",
  "createdAt": "2025-10-22T06:00:00Z",
  "uploadedAt": "2025-10-22T06:00:05Z",
  "user": {
    "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "nickname": "지훈",
    "profileImageUrl": "https://..."
  }
}
```

**Error Responses**:

- **403 Forbidden**: 카테고리 멤버가 아님
- **404 Not Found**: 음성을 찾을 수 없음

---

## 📦 Feature 5: 파형 데이터 조회 (Waveform Data Query)

### Flutter 소스 분석

**AudioRepository.extractWaveformData()** (클라이언트에서 추출):

```dart
Future<List<double>> extractWaveformData(String audioFilePath) async {
  final controller = PlayerController();
  await controller.preparePlayer(
    path: audioFilePath,
    shouldExtractWaveform: true,
  );

  List<double> rawData = controller.waveformData;
  final compressedData = _compressWaveformData(rawData, targetLength: 100);

  return compressedData;
}
```

**주의**: 백엔드는 클라이언트가 업로드한 파형 데이터를 저장하고 조회만 담당

### 백엔드 구현 명세

#### Input Format

**Endpoint**: `GET /api/v1/audios/{audioId}/waveform`

**Path Parameters**:

- `audioId`: UUID (음성 ID)

#### Process Flow

**단계 1: 음성 및 멤버십 확인** (Feature 4와 동일)

**단계 2: 파형 데이터 조회**

```java
@Query("""
    SELECT w FROM AudioWaveformData w
    JOIN FETCH w.audio a
    WHERE a.id = :audioId
    """)
Optional<AudioWaveformData> findByAudioId(@Param("audioId") UUID audioId);
```

**단계 3: DTO 반환**

```java
AudioWaveformData waveform = waveformDataRepository.findByAudioId(audioId)
    .orElseThrow(() -> new WaveformNotFoundException());

return WaveformDTO.from(waveform);
```

#### Output Format

**Success Response** (200 OK):

```json
{
  "audioId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "waveformData": [
    0.1, 0.15, 0.2, 0.3, 0.5, 0.7, 0.8, 0.9, 0.85, 0.7, 0.5, 0.3, 0.2, 0.15,
    0.1, 0.05, 0.1, 0.2, 0.4, 0.6, 0.8, 0.9, 0.95, 0.9, 0.8, 0.6, 0.4, 0.2, 0.1,
    0.05
  ],
  "sampleCount": 100
}
```

#### 구현 시 주의사항

1. **별도 엔드포인트**: 파형 데이터는 크기가 크므로 상세 조회와 분리
2. **JSONB 조회**: PostgreSQL JSONB는 효율적이지만 큰 배열은 네트워크 오버헤드 발생 가능
3. **캐싱 고려**: 파형 데이터는 변경되지 않으므로 Redis 캐싱 적용 가능

---

## 📦 Feature 6: 음성 메타데이터 수정 (Audio Metadata Update)

### Flutter 소스 분석

**AudioService.updateAudioInfo()**:

```dart
Future<AuthResult> updateAudioInfo({
  required String audioId,
  String? fileName,
  String? description,
}) async {
  final updateData = <String, dynamic>{};

  if (fileName != null) {
    final validationError = _validateAudioFileName(fileName);
    if (validationError != null) {
      return AuthResult.failure(validationError);
    }
    updateData['fileName'] = _normalizeFileName(fileName);
  }

  if (description != null) {
    updateData['description'] = description;
  }

  if (updateData.isEmpty) {
    return AuthResult.failure('업데이트할 내용이 없습니다.');
  }

  await _repository.updateAudioData(audioId, updateData);
  return AuthResult.success();
}
```

### 백엔드 구현 명세

#### Input Format

**Endpoint**: `PUT /api/v1/audios/{audioId}`

**Path Parameters**:

- `audioId`: UUID (음성 ID)

**Request Body**:

```java
public class AudioUpdateRequest {
    @Size(min = 1, max = 50, message = "파일명은 1~50자여야 합니다.")
    private String fileName;

    @Size(max = 500, message = "설명은 500자 이하여야 합니다.")
    private String description;
}
```

#### Process Flow

**단계 1: 음성 조회 및 권한 확인**

```java
Audio audio = audioRepository.findById(audioId)
    .orElseThrow(() -> new AudioNotFoundException());

if (!audio.isUploadedBy(currentUserId)) {
    throw new ForbiddenException("업로더 본인만 음성을 수정할 수 있습니다.");
}
```

**단계 2: 메타데이터 업데이트**

```java
@Transactional
public AudioDTO updateAudio(UUID audioId, AudioUpdateRequest request) {
    Audio audio = // ... 권한 확인 생략

    if (request.getFileName() != null) {
        audio.setFileName(request.getFileName());
    }

    if (request.getDescription() != null) {
        audio.setDescription(request.getDescription());
    }

    Audio updatedAudio = audioRepository.save(audio);
    return AudioDTO.from(updatedAudio);
}
```

#### Output Format

**Success Response** (200 OK):

```json
{
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "categoryId": "550e8400-e29b-41d4-a716-446655440000",
  "userId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "fileName": "성산일출봉 일출 🌅",
  "s3Url": "https://...",
  "durationInSeconds": 30,
  "fileSizeInBytes": 2457600,
  "format": "AAC",
  "status": "UPLOADED",
  "description": "2025년 10월 22일 오전 6시 일출",
  "createdAt": "2025-10-22T06:00:00Z",
  "uploadedAt": "2025-10-22T06:00:05Z"
}
```

**Error Responses**:

- **400 Bad Request**: 파일명/설명 검증 실패
- **403 Forbidden**: 업로더 본인이 아님
- **404 Not Found**: 음성을 찾을 수 없음

#### 구현 시 주의사항

1. **수정 불가 필드**: audioFile, waveformData, categoryId, duration 등은 수정 불가
2. **파일명 정규화**: 특수문자 제거, trim 적용
3. **변경 감지**: JPA dirty checking으로 변경된 필드만 UPDATE

---

## 📦 Feature 7: 음성 삭제 (Audio Deletion)

### Flutter 소스 분석

**AudioService.deleteAudio()**:

```dart
Future<AuthResult> deleteAudio(String audioId) async {
  final audioData = await _repository.getAudioData(audioId);
  if (audioData == null) {
    return AuthResult.failure('삭제할 오디오를 찾을 수 없습니다.');
  }

  // Firebase Storage에서 파일 삭제
  if (audioData.firebaseUrl != null) {
    await _repository.deleteAudioFile(audioData.firebaseUrl!);
  }

  // 로컬 파일들 삭제
  if (audioData.originalPath.isNotEmpty) {
    await _repository.deleteLocalFile(audioData.originalPath);
  }

  // Firestore에서 데이터 삭제
  await _repository.deleteAudioData(audioId);

  return AuthResult.success();
}
```

**AudioRepository.deleteAudioFile()**:

```dart
Future<void> deleteAudioFile(String downloadUrl) async {
  try {
    final ref = _storage.refFromURL(downloadUrl);
    await ref.delete();
  } catch (e) {
    debugPrint('오디오 파일 삭제 실패: $e');
  }
}
```

### 백엔드 구현 명세

#### Input Format

**Endpoint**: `DELETE /api/v1/audios/{audioId}`

**Path Parameters**:

- `audioId`: UUID (음성 ID)

#### Process Flow

**단계 1: 음성 조회 및 권한 확인**

```java
Audio audio = audioRepository.findById(audioId)
    .orElseThrow(() -> new AudioNotFoundException());

if (!audio.isUploadedBy(currentUserId)) {
    throw new ForbiddenException("업로더 본인만 음성을 삭제할 수 있습니다.");
}
```

**단계 2: PostgreSQL 삭제 (CASCADE로 파형 데이터도 자동 삭제)**

```java
@Transactional
public void deleteAudio(UUID audioId) {
    Audio audio = // ... 권한 확인 생략

    String s3Key = audio.getS3Key(); // S3 삭제용 키 저장

    // 1. DB에서 삭제 (CASCADE로 audio_waveform_data도 삭제됨)
    audioRepository.delete(audio);

    // 2. S3에서 비동기 삭제
    CompletableFuture.runAsync(() -> {
        try {
            s3Service.deleteFile(s3Key);
            log.info("S3 파일 삭제 완료: {}", s3Key);
        } catch (Exception e) {
            log.error("S3 파일 삭제 실패: {}", s3Key, e);
            // 실패해도 DB는 이미 삭제되었으므로 에러 무시
        }
    });
}
```

**단계 3: S3 파일 삭제**

```java
public void deleteFile(String s3Key) {
    DeleteObjectRequest deleteRequest = DeleteObjectRequest.builder()
        .bucket(s3BucketName)
        .key(s3Key)
        .build();

    s3Client.deleteObject(deleteRequest);
}
```

#### Output Format

**Success Response** (204 No Content):

- 응답 본문 없음

**Error Responses**:

- **403 Forbidden**: 업로더 본인이 아님
- **404 Not Found**: 음성을 찾을 수 없음

#### 구현 시 주의사항

1. **CASCADE 삭제**: `audio_waveform_data` 테이블에 `ON DELETE CASCADE` 설정 필수
2. **비동기 S3 삭제**: DB 삭제 후 빠른 응답, S3 삭제는 백그라운드 처리
3. **S3 삭제 실패 처리**: S3 삭제 실패해도 DB는 이미 삭제되었으므로 재시도 로직 필요 없음
4. **트랜잭션**: DB 삭제만 트랜잭션 범위에 포함, S3는 별도 비동기 처리

---

## 📦 Feature 8: 실시간 음성 알림 (Real-time Audio Notification)

### Flutter 소스 분석

**AudioRepository.getAudiosByCategoryStream()**:

```dart
Stream<List<AudioDataModel>> getAudiosByCategoryStream(String categoryId) {
  return _firestore
      .collection('audios')
      .where('categoryId', isEqualTo: categoryId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs
                .map((doc) => AudioDataModel.fromFirestore(doc.data(), doc.id))
                .toList(),
      );
}
```

**AudioController에서 사용**:

```dart
Stream<List<AudioDataModel>> getAudiosByCategoryStream(String categoryId) {
  return _audioService.getAudiosByCategoryStream(categoryId);
}
```

### 백엔드 구현 명세

#### WebSocket Configuration

**Endpoint**: `wss://api.soi.com/ws`

**Protocol**: STOMP over WebSocket

**Topic**: `/topic/categories/{categoryId}/audios`

#### Process Flow

**단계 1: WebSocket 서버 구성**

```java
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        config.enableSimpleBroker("/topic"); // 메시지 브로커
        config.setApplicationDestinationPrefixes("/app"); // 클라이언트 요청 prefix
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws")
            .setAllowedOriginPatterns("*")
            .withSockJS();
    }
}
```

**단계 2: 음성 업로드 시 알림 브로드캐스트**

```java
@Service
public class AudioService {

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    @Transactional
    public AudioDTO uploadAudio(AudioUploadRequest request, UUID userId) {
        // ... 음성 업로드 로직 생략

        // WebSocket 알림 전송
        AudioNotificationMessage message = AudioNotificationMessage.builder()
            .type("NEW_AUDIO")
            .audioId(savedAudio.getId())
            .categoryId(categoryId)
            .userId(userId)
            .userName(user.getNickname())
            .fileName(savedAudio.getFileName())
            .durationInSeconds(savedAudio.getDurationInSeconds())
            .createdAt(savedAudio.getCreatedAt())
            .build();

        messagingTemplate.convertAndSend(
            "/topic/categories/" + categoryId + "/audios",
            message
        );

        return AudioDTO.fromWithUser(savedAudio);
    }
}
```

**단계 3: 메시지 DTO**

```java
@Getter
@Builder
public class AudioNotificationMessage {
    private String type; // "NEW_AUDIO"
    private UUID audioId;
    private UUID categoryId;
    private UUID userId;
    private String userName;
    private String fileName;
    private Integer durationInSeconds;
    private LocalDateTime createdAt;
}
```

#### Flutter 클라이언트 연동

**STOMP 클라이언트 설정**:

```dart
import 'package:stomp_dart_client/stomp_dart_client.dart';

final stompClient = StompClient(
  config: StompConfig.sockJS(
    url: 'https://api.soi.com/ws',
    onConnect: (StompFrame frame) {
      // 카테고리별 음성 알림 구독
      stompClient.subscribe(
        destination: '/topic/categories/$categoryId/audios',
        callback: (StompFrame frame) {
          final message = jsonDecode(frame.body!);

          if (message['type'] == 'NEW_AUDIO') {
            // 새 음성 알림 처리
            _handleNewAudio(AudioNotificationMessage.fromJson(message));
          }
        },
      );
    },
    onWebSocketError: (dynamic error) {
      print('WebSocket 에러: $error');
    },
  ),
);

stompClient.activate();
```

**알림 처리**:

```dart
void _handleNewAudio(AudioNotificationMessage message) {
  // 1. 음성 목록 최상단에 새 항목 추가
  setState(() {
    _audioList.insert(0, AudioDataModel(
      id: message.audioId,
      categoryId: message.categoryId,
      userId: message.userId,
      fileName: message.fileName,
      durationInSeconds: message.durationInSeconds,
      createdAt: message.createdAt,
    ));
  });

  // 2. 푸시 알림 표시 (백그라운드 상태인 경우)
  if (!isAppInForeground) {
    showPushNotification(
      title: '새 음성이 도착했어요',
      body: '${message.userName}님이 "${message.fileName}"를 올렸어요 🎤',
    );
  }

  // 3. 스낵바 표시 (포그라운드 상태인 경우)
  if (isAppInForeground) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${message.userName}님이 새 음성을 올렸어요')),
    );
  }
}
```

#### Output Format

**WebSocket Message**:

```json
{
  "type": "NEW_AUDIO",
  "audioId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "categoryId": "550e8400-e29b-41d4-a716-446655440000",
  "userId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "userName": "지훈",
  "fileName": "성산일출봉 일출 🌅",
  "durationInSeconds": 30,
  "createdAt": "2025-10-22T06:00:00Z"
}
```

#### 구현 시 주의사항

1. **인증**: WebSocket 연결 시 Firebase ID Token 검증 필요

   ```java
   @Configuration
   public class WebSocketAuthConfig {
       @Bean
       public WebSocketHandlerDecoratorFactory authDecoratorFactory() {
           return handler -> new AuthWebSocketHandler(handler, firebaseAuth);
       }
   }
   ```

2. **스케일아웃**: 서버가 여러 대인 경우 Redis Pub/Sub 사용

   ```java
   @Configuration
   public class WebSocketConfig {
       @Bean
       public MessageBroker messageBroker(RedisConnectionFactory factory) {
           return new StompBrokerRelayRegistration()
               .setRelayHost("redis-server")
               .setRelayPort(6379);
       }
   }
   ```

3. **재연결 로직**: 클라이언트에서 연결 끊김 시 자동 재연결

   ```dart
   config: StompConfig.sockJS(
     reconnectDelay: Duration(seconds: 5),
     heartbeatIncoming: Duration(seconds: 10),
     heartbeatOutgoing: Duration(seconds: 10),
   )
   ```

4. **메시지 필터링**: 카테고리별 구독으로 불필요한 메시지 수신 방지

---

## 📊 기능 구현 체크리스트

### Controller Layer (REST API)

- [ ] **AudioController.java**
  - [ ] `POST /api/v1/audios` - 음성 업로드
  - [ ] `GET /api/v1/audios/{audioId}` - 음성 상세 조회
  - [ ] `GET /api/v1/audios/{audioId}/waveform` - 파형 데이터 조회
  - [ ] `PUT /api/v1/audios/{audioId}` - 메타데이터 수정
  - [ ] `DELETE /api/v1/audios/{audioId}` - 음성 삭제
  - [ ] `GET /api/v1/categories/{categoryId}/audios` - 카테고리 음성 목록
  - [ ] `GET /api/v1/users/{userId}/audios` - 사용자 음성 목록
  - [ ] `GET /api/v1/users/me/audios` - 내 음성 목록

### Service Layer (Business Logic)

- [ ] **AudioService.java**
  - [ ] `uploadAudio()` - 파일 검증, S3 업로드, DB 저장, WebSocket 알림
  - [ ] `getAudiosByCategory()` - 카테고리 멤버십 확인 후 조회
  - [ ] `getAudiosByUser()` - 사용자 음성 조회
  - [ ] `getAudioById()` - 음성 상세 조회
  - [ ] `getWaveformData()` - 파형 데이터 조회
  - [ ] `updateAudio()` - 권한 확인 후 메타데이터 수정
  - [ ] `deleteAudio()` - 권한 확인 후 삭제, 비동기 S3 삭제

### Repository Layer (Data Access)

- [ ] **AudioRepository.java** (JPA Repository)

  - [ ] `findById(UUID id)` - 기본 조회
  - [ ] `findByIdWithDetails(UUID id)` - JOIN FETCH (user, category)
  - [ ] `findByCategoryIdWithUser(UUID categoryId, Pageable)` - 카테고리별 조회
  - [ ] `findByUserIdWithCategory(UUID userId, Pageable)` - 사용자별 조회
  - [ ] `save(Audio)` - 저장/수정
  - [ ] `delete(Audio)` - 삭제

- [ ] **AudioWaveformDataRepository.java**
  - [ ] `findByAudioId(UUID audioId)` - 파형 데이터 조회
  - [ ] `save(AudioWaveformData)` - 파형 저장

### Supporting Services

- [ ] **S3Service.java**

  - [ ] `uploadFile(MultipartFile, String s3Key)` - S3 업로드
  - [ ] `deleteFile(String s3Key)` - S3 삭제 (비동기)
  - [ ] `generatePresignedUrl(String s3Key)` - Presigned URL 생성 (선택)

- [ ] **ValidationService.java**

  - [ ] `validateAudioFile(MultipartFile)` - 파일 크기/형식 검증
  - [ ] `extractDuration(MultipartFile)` - 음성 길이 추출
  - [ ] `validateWaveformData(List<Double>)` - 파형 데이터 검증

- [ ] **CategoryMemberService.java**
  - [ ] `isMember(UUID categoryId, UUID userId)` - 멤버십 확인

### Configuration

- [ ] **WebSocketConfig.java**

  - [ ] STOMP over WebSocket 설정
  - [ ] 엔드포인트 및 브로커 구성
  - [ ] 인증 인터셉터 (Firebase ID Token)

- [ ] **S3Config.java**

  - [ ] AWS S3 클라이언트 Bean 설정
  - [ ] 버킷 이름, 리전 설정

- [ ] **RateLimitConfig.java**
  - [ ] Redis 기반 Rate Limiting 설정
  - [ ] 업로드: 분당 10개 제한

### Entity & DTO

- [ ] **Audio.java** (Entity)

  - [ ] JPA 매핑, 관계 설정
  - [ ] 비즈니스 메서드 (isUploadedBy, markAsUploaded 등)

- [ ] **AudioWaveformData.java** (Entity)

  - [ ] JSONB 타입 매핑 (Hypersistence Utils)
  - [ ] OneToOne 관계 설정

- [ ] **AudioDTO.java**

  - [ ] from(), fromWithUser(), fromWithCategory() 팩토리 메서드

- [ ] **WaveformDTO.java**

  - [ ] 파형 데이터 전용 DTO

- [ ] **AudioUploadRequest.java**

  - [ ] Bean Validation 어노테이션
  - [ ] 커스텀 Validator (waveformData 범위 검증)

- [ ] **AudioUpdateRequest.java**

  - [ ] fileName, description 검증

- [ ] **AudioNotificationMessage.java**
  - [ ] WebSocket 메시지 DTO

### Database

- [ ] **Migration Scripts**
  - [ ] `V1__create_audios_table.sql` - audios 테이블 생성
  - [ ] `V2__create_audio_waveform_data_table.sql` - 파형 데이터 테이블
  - [ ] `V3__create_indexes.sql` - 성능 최적화 인덱스
    - [ ] `idx_audio_category_created` - (category_id, created_at DESC)
    - [ ] `idx_audio_user_created` - (user_id, created_at DESC)
    - [ ] `idx_waveform_audio` - (audio_id UNIQUE)

### Testing

- [ ] **Unit Tests**

  - [ ] AudioServiceTest - 비즈니스 로직 테스트
  - [ ] ValidationServiceTest - 검증 로직 테스트

- [ ] **Integration Tests**

  - [ ] AudioControllerTest - API 엔드포인트 테스트
  - [ ] AudioRepositoryTest - JPA 쿼리 테스트

- [ ] **E2E Tests**
  - [ ] 음성 업로드 → 조회 → 수정 → 삭제 전체 플로우
  - [ ] WebSocket 실시간 알림 테스트

---

## 🚀 마이그레이션 우선순위

### Phase 1: 기본 CRUD (1-2주)

1. **Feature 1**: 음성 업로드 (가장 중요)
2. **Feature 2**: 카테고리 음성 목록
3. **Feature 4**: 음성 상세 조회
4. **Feature 7**: 음성 삭제

### Phase 2: 고급 기능 (1주)

5. **Feature 3**: 사용자 음성 목록
6. **Feature 5**: 파형 데이터 조회
7. **Feature 6**: 메타데이터 수정

### Phase 3: 실시간 기능 (1주)

8. **Feature 8**: WebSocket 실시간 알림

### Phase 4: 최적화 & 모니터링 (1주)

- Rate Limiting 적용
- 성능 최적화 (쿼리 튜닝, 인덱스)
- 로깅 및 모니터링 대시보드
- S3 비용 최적화 (Lifecycle Policy)

---

## 📝 구현 시 핵심 고려사항

### 1. 파일 검증

**음성 길이 추출** (Apache Tika 사용):

```java
@Service
public class AudioMetadataExtractor {

    private final Parser parser = new Mp3Parser();

    public int extractDuration(MultipartFile audioFile) throws Exception {
        Metadata metadata = new Metadata();
        ContentHandler handler = new DefaultHandler();

        try (InputStream stream = audioFile.getInputStream()) {
            parser.parse(stream, handler, metadata, new ParseContext());
        }

        String duration = metadata.get("xmpDM:duration");
        return (int) (Double.parseDouble(duration) / 1000); // 밀리초 → 초
    }
}
```

### 2. S3 업로드 최적화

**멀티파트 업로드** (큰 파일 대응):

```java
@Service
public class S3Service {

    public String uploadLargeFile(MultipartFile file, String s3Key) {
        CreateMultipartUploadRequest createRequest =
            CreateMultipartUploadRequest.builder()
                .bucket(bucketName)
                .key(s3Key)
                .build();

        CreateMultipartUploadResponse response =
            s3Client.createMultipartUpload(createRequest);

        // 파트별 업로드 로직...

        return s3Client.utilities().getUrl(builder ->
            builder.bucket(bucketName).key(s3Key)).toString();
    }
}
```

### 3. 트랜잭션 관리

**롤백 시 S3 파일도 삭제**:

```java
@Transactional(rollbackFor = Exception.class)
public AudioDTO uploadAudio(AudioUploadRequest request, UUID userId) {
    String s3Key = null;

    try {
        // 1. S3 업로드
        s3Key = s3Service.uploadFile(request.getAudioFile(), generateS3Key());

        // 2. DB 저장
        Audio audio = audioRepository.save(...);
        AudioWaveformData waveform = waveformRepository.save(...);

        return AudioDTO.fromWithUser(audio);

    } catch (Exception e) {
        // 롤백 시 S3 파일 삭제
        if (s3Key != null) {
            s3Service.deleteFile(s3Key);
        }
        throw e;
    }
}
```

### 4. N+1 문제 방지

**JOIN FETCH 사용**:

```java
@Query("""
    SELECT a FROM Audio a
    JOIN FETCH a.user u
    LEFT JOIN FETCH u.profileImage
    WHERE a.category.id = :categoryId
    """)
Page<Audio> findByCategoryIdWithUserAndProfile(
    @Param("categoryId") UUID categoryId,
    Pageable pageable
);
```

---

**작성일**: 2025년 10월 22일  
**작성자**: SOI Development Team  
**버전**: 1.0.0
