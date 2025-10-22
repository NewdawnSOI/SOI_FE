# 음성/텍스트 댓글 시스템 - 비즈니스 규칙

이 문서는 음성/텍스트 댓글 시스템의 **비즈니스 규칙**, **검증 로직**, **보안 정책**을 정의합니다.

---

## 📋 목차

1. [음성 댓글 생성 규칙](#1-음성-댓글-생성-규칙)
2. [텍스트 댓글 생성 규칙](#2-텍스트-댓글-생성-규칙)
3. [댓글 조회 규칙](#3-댓글-조회-규칙)
4. [댓글 삭제 규칙](#4-댓글-삭제-규칙)
5. [프로필 위치 규칙](#5-프로필-위치-규칙)
6. [보안 규칙](#6-보안-규칙)
7. [데이터 무결성 규칙](#7-데이터-무결성-규칙)

---

## 1. 음성 댓글 생성 규칙

### 1.1 필수 입력값 검증

| 필드             | 타입         | 필수 여부 | 검증 규칙                         |
| ---------------- | ------------ | --------- | --------------------------------- |
| audioFilePath    | String       | ✅        | 빈 문자열 불가                    |
| photoId          | String       | ✅        | 존재하는 사진 ID (FK 제약)        |
| recorderUser     | String       | ✅        | 존재하는 사용자 ID (FK 제약)      |
| waveformData     | List<double> | ✅        | 빈 배열 불가, 각 값 0.0~1.0 범위  |
| duration         | int          | ✅        | 0보다 큰 값, 최대 300,000ms (5분) |
| profileImageUrl  | String       | ✅        | 유효한 URL 형식                   |
| relativePosition | Offset?      | ❌        | nullable, 있으면 0.0~1.0 범위     |

### 1.2 오디오 파일 검증

```dart
// 의사코드
validateAudioFile(filePath):
  1. 파일 존재 확인
     if (!File.exists(filePath)):
       throw "음성 파일이 존재하지 않습니다"

  2. 파일 크기 확인
     fileSize = File.length(filePath)
     if (fileSize > 10 * 1024 * 1024):  // 10MB
       throw "음성 파일 크기가 너무 큽니다 (최대 10MB)"

  3. 파일 확장자 확인
     extension = filePath.split('.').last.toLowerCase()
     allowedExtensions = ['aac', 'm4a', 'mp3', 'wav']
     if (extension not in allowedExtensions):
       throw "지원하지 않는 음성 파일 형식입니다"
```

### 1.3 녹음 시간 제한

```dart
// 의사코드
validateDuration(duration):
  const MIN_DURATION = 1000  // 1초
  const MAX_DURATION = 300000  // 5분

  if (duration < MIN_DURATION):
    throw "녹음 시간이 너무 짧습니다 (최소 1초)"

  if (duration > MAX_DURATION):
    throw "녹음 시간이 너무 깁니다 (최대 5분)"
```

### 1.4 파형 데이터 정규화

```dart
// 의사코드
normalizeWaveformData(waveformData):
  if (waveformData.isEmpty):
    return []

  // 최대값 찾기
  maxValue = max(abs(waveformData))
  if (maxValue == 0):
    return waveformData

  // 0.0 ~ 1.0 범위로 정규화
  normalized = []
  for value in waveformData:
    normalized.add(clamp(abs(value) / maxValue, 0.0, 1.0))

  return normalized
```

### 1.5 Firebase Storage 업로드 규칙

```dart
// 의사코드
uploadAudioFile(filePath, photoId, recorderUser):
  1. 고유한 파일명 생성
     timestamp = DateTime.now().millisecondsSinceEpoch
     fileName = "{photoId}_{recorderUser}_{timestamp}.aac"
     storagePath = "comment_records/{fileName}"

  2. 메타데이터 설정
     metadata = {
       contentType: "audio/aac",
       customMetadata: {
         photoId: photoId,
         recorderUser: recorderUser,
         uploadedAt: DateTime.now().toIso8601String()
       }
     }

  3. 파일 업로드
     uploadTask = FirebaseStorage.ref(storagePath).putFile(file, metadata)
     snapshot = await uploadTask

  4. 다운로드 URL 반환
     downloadUrl = await snapshot.ref.getDownloadURL()
     return downloadUrl
```

---

## 2. 텍스트 댓글 생성 규칙

### 2.1 필수 입력값 검증

| 필드             | 타입    | 필수 여부 | 검증 규칙                             |
| ---------------- | ------- | --------- | ------------------------------------- |
| text             | String  | ✅        | trim() 후 빈 문자열 불가, 최대 1000자 |
| photoId          | String  | ✅        | 존재하는 사진 ID                      |
| recorderUser     | String  | ✅        | 존재하는 사용자 ID                    |
| profileImageUrl  | String  | ✅        | 유효한 URL 형식                       |
| relativePosition | Offset? | ❌        | nullable, 있으면 0.0~1.0 범위         |

### 2.2 텍스트 내용 검증

```dart
// 의사코드
validateText(text):
  1. null 체크
     if (text == null):
       throw "댓글 내용을 입력해주세요"

  2. 공백 제거 및 빈 문자열 체크
     trimmedText = text.trim()
     if (trimmedText.isEmpty):
       throw "댓글 내용을 입력해주세요"

  3. 최대 길이 체크
     const MAX_LENGTH = 1000
     if (trimmedText.length > MAX_LENGTH):
       throw "댓글은 최대 1000자까지 입력 가능합니다"

  4. 금지어 필터링 (선택 사항)
     forbiddenWords = ["욕설1", "욕설2", ...]
     for word in forbiddenWords:
       if (word in trimmedText):
         throw "부적절한 단어가 포함되어 있습니다"

  return trimmedText
```

### 2.3 텍스트 댓글 저장 규칙

```dart
// 의사코드
createTextComment(text, photoId, recorderUser, profileImageUrl, relativePosition):
  commentRecord = {
    id: "",  // Firestore 자동 생성
    audioUrl: "",  // 텍스트 댓글은 음성 없음
    text: validateText(text),
    photoId: photoId,
    recorderUser: recorderUser,
    waveformData: [],  // 텍스트 댓글은 파형 없음
    duration: 0,  // 텍스트 댓글은 재생 시간 없음
    profileImageUrl: profileImageUrl,
    relativePosition: relativePosition,
    type: CommentType.text,
    isDeleted: false,
    createdAt: DateTime.now()
  }

  // Firestore 저장
  docRef = await firestore.collection("comment_records").add(commentRecord)
  return commentRecord.copyWith(id: docRef.id)
```

---

## 3. 댓글 조회 규칙

### 3.1 사진별 댓글 조회

```dart
// 의사코드
getCommentsByPhotoId(photoId):
  // 입력 검증
  if (photoId.isEmpty):
    throw "유효하지 않은 사진 ID입니다"

  // Firestore 쿼리
  query = firestore.collection("comment_records")
    .where("photoId", isEqualTo: photoId)
    .where("isDeleted", isEqualTo: false)
    .orderBy("createdAt", descending: false)

  querySnapshot = await query.get()

  // 결과 변환
  comments = []
  for doc in querySnapshot.docs:
    comments.add(CommentRecordModel.fromFirestore(doc))

  return comments
```

### 3.2 사용자별 댓글 조회

```dart
// 의사코드
getCommentsByUser(userId):
  // 입력 검증
  if (userId.isEmpty):
    throw "유효하지 않은 사용자 ID입니다"

  // Firestore 쿼리
  query = firestore.collection("comment_records")
    .where("recorderUser", isEqualTo: userId)
    .where("isDeleted", isEqualTo: false)
    .orderBy("createdAt", descending: true)

  querySnapshot = await query.get()

  return querySnapshot.docs.map((doc) => CommentRecordModel.fromFirestore(doc))
```

### 3.3 페이지네이션 규칙

```dart
// 의사코드
getCommentsByPhotoIdWithPagination(photoId, page, size):
  const MAX_PAGE_SIZE = 100
  const DEFAULT_PAGE_SIZE = 20

  // 페이지 크기 검증
  pageSize = min(size, MAX_PAGE_SIZE)
  if (pageSize <= 0):
    pageSize = DEFAULT_PAGE_SIZE

  // Firestore 쿼리 (페이징)
  query = firestore.collection("comment_records")
    .where("photoId", isEqualTo: photoId)
    .where("isDeleted", isEqualTo: false)
    .orderBy("createdAt", descending: false)
    .limit(pageSize)

  // 페이지 오프셋
  if (page > 0):
    // 이전 페이지의 마지막 문서 ID로 시작
    lastDocId = getLastDocIdFromCache(photoId, page - 1)
    if (lastDocId):
      query = query.startAfter(lastDocId)

  querySnapshot = await query.get()
  return querySnapshot.docs
```

---

## 4. 댓글 삭제 규칙

### 4.1 권한 검증

```dart
// 의사코드
canDeleteComment(currentUserId, comment):
  // 본인 댓글인지 확인
  if (comment.recorderUser == currentUserId):
    return true

  // 권한 없음
  return false
```

### 4.2 Soft Delete

```dart
// 의사코드
deleteComment(commentId, currentUserId):
  // 1. 댓글 조회
  comment = await getCommentById(commentId)
  if (!comment):
    throw "존재하지 않는 댓글입니다"

  // 2. 권한 확인
  if (!canDeleteComment(currentUserId, comment)):
    throw "자신의 댓글만 삭제할 수 있습니다"

  // 3. Soft delete
  await firestore.collection("comment_records")
    .doc(commentId)
    .update({"isDeleted": true})
```

### 4.3 Hard Delete (관리자 전용)

```dart
// 의사코드
hardDeleteComment(commentId):
  // 1. 댓글 조회
  doc = await firestore.collection("comment_records").doc(commentId).get()
  if (!doc.exists):
    return  // 이미 삭제됨

  comment = CommentRecordModel.fromFirestore(doc)

  // 2. Storage 파일 삭제 (음성 댓글인 경우)
  if (comment.audioUrl.isNotEmpty):
    try:
      ref = FirebaseStorage.refFromURL(comment.audioUrl)
      await ref.delete()
    catch (e):
      // 파일 없거나 권한 문제면 무시
      log("Storage 파일 삭제 실패: $e")

  // 3. Firestore 문서 삭제
  await firestore.collection("comment_records").doc(commentId).delete()
```

---

## 5. 프로필 위치 규칙

### 5.1 상대 좌표 검증

```dart
// 의사코드
validateRelativePosition(relativePosition):
  if (relativePosition == null):
    return  // nullable이므로 통과

  // X 좌표 검증 (0.0 ~ 1.0)
  if (relativePosition.dx < 0.0 || relativePosition.dx > 1.0):
    throw "X 좌표는 0.0 ~ 1.0 범위여야 합니다: ${relativePosition.dx}"

  // Y 좌표 검증 (0.0 ~ 1.0)
  if (relativePosition.dy < 0.0 || relativePosition.dy > 1.0):
    throw "Y 좌표는 0.0 ~ 1.0 범위여야 합니다: ${relativePosition.dy}"
```

### 5.2 프로필 위치 업데이트

```dart
// 의사코드
updateRelativeProfilePosition(commentId, relativePosition):
  // 1. 좌표 검증
  validateRelativePosition(relativePosition)

  // 2. 댓글 존재 확인
  doc = await firestore.collection("comment_records").doc(commentId).get()
  if (!doc.exists):
    throw "존재하지 않는 댓글입니다"

  // 3. Firestore 업데이트
  await firestore.collection("comment_records").doc(commentId).update({
    "relativePosition": {
      "x": relativePosition.dx,
      "y": relativePosition.dy
    }
  })
```

### 5.3 절대 좌표 → 상대 좌표 변환 (UI Layer)

```dart
// 의사코드
absoluteToRelative(absolutePosition, imageSize):
  relativeX = absolutePosition.dx / imageSize.width
  relativeY = absolutePosition.dy / imageSize.height

  // 범위 제한 (안전장치)
  relativeX = clamp(relativeX, 0.0, 1.0)
  relativeY = clamp(relativeY, 0.0, 1.0)

  return Offset(relativeX, relativeY)
```

### 5.4 상대 좌표 → 절대 좌표 변환 (UI Layer)

```dart
// 의사코드
relativeToAbsolute(relativePosition, imageSize):
  absoluteX = relativePosition.dx * imageSize.width
  absoluteY = relativePosition.dy * imageSize.height

  return Offset(absoluteX, absoluteY)
```

---

## 6. 보안 규칙

### 6.1 Firebase ID Token 검증

```dart
// 의사코드
verifyUserAuthentication(idToken):
  if (idToken.isEmpty):
    throw "인증 토큰이 필요합니다"

  try:
    decodedToken = FirebaseAuth.verifyIdToken(idToken)
    return decodedToken.uid
  catch (error):
    throw "유효하지 않은 인증 토큰입니다"
```

### 6.2 Rate Limiting (댓글 생성)

```dart
// 의사코드
checkRateLimit(userId):
  const MAX_COMMENTS_PER_MINUTE = 10

  // Redis 또는 In-Memory 캐시 사용
  key = "comment_rate_limit:{userId}"
  count = cache.get(key) ?? 0

  if (count >= MAX_COMMENTS_PER_MINUTE):
    throw "너무 많은 댓글을 작성했습니다. 잠시 후 다시 시도해주세요."

  // 카운트 증가 (1분 TTL)
  cache.set(key, count + 1, ttl: 60)
```

### 6.3 Spam 방지

```dart
// 의사코드
detectSpam(userId, text, photoId):
  // 1. 동일 내용 연속 작성 방지
  lastComment = getLastCommentByUser(userId)
  if (lastComment && lastComment.text == text):
    if (DateTime.now().difference(lastComment.createdAt).inSeconds < 10):
      throw "동일한 댓글을 연속으로 작성할 수 없습니다"

  // 2. 같은 사진에 연속 댓글 방지
  recentComments = getRecentCommentsByUser(userId, photoId, limit: 3)
  if (recentComments.length >= 3):
    timeSinceFirst = DateTime.now().difference(recentComments.first.createdAt)
    if (timeSinceFirst.inSeconds < 30):
      throw "댓글을 너무 빠르게 작성하고 있습니다"
```

### 6.4 파일 업로드 보안

```dart
// 의사코드
validateAudioFileForSecurity(file):
  // 1. MIME 타입 검증
  mimeType = file.contentType
  allowedMimeTypes = ["audio/aac", "audio/mpeg", "audio/wav", "audio/x-m4a"]
  if (mimeType not in allowedMimeTypes):
    throw "지원하지 않는 파일 형식입니다"

  // 2. Magic Bytes 검증 (파일 헤더)
  bytes = file.readBytes(0, 12)
  if (!isValidAudioHeader(bytes)):
    throw "손상되었거나 유효하지 않은 오디오 파일입니다"

  // 3. 바이러스 스캔 (선택 사항)
  if (USE_VIRUS_SCAN):
    if (virusScanner.scan(file)):
      throw "악성 파일이 감지되었습니다"
```

---

## 7. 데이터 무결성 규칙

### 7.1 외래키 제약

```sql
-- PostgreSQL 스키마 (마이그레이션 후)
ALTER TABLE comments
  ADD CONSTRAINT fk_photo
    FOREIGN KEY (photo_id)
    REFERENCES photos(id)
    ON DELETE CASCADE;

ALTER TABLE comments
  ADD CONSTRAINT fk_recorder_user
    FOREIGN KEY (recorder_user_id)
    REFERENCES users(id)
    ON DELETE CASCADE;
```

**의미**:

- 사진이 삭제되면 해당 사진의 모든 댓글도 자동 삭제
- 사용자가 탈퇴하면 해당 사용자의 모든 댓글도 자동 삭제

### 7.2 NOT NULL 제약

```sql
ALTER TABLE comments
  ALTER COLUMN photo_id SET NOT NULL,
  ALTER COLUMN recorder_user_id SET NOT NULL,
  ALTER COLUMN type SET NOT NULL,
  ALTER COLUMN profile_image_url SET NOT NULL,
  ALTER COLUMN is_deleted SET NOT NULL,
  ALTER COLUMN created_at SET NOT NULL;
```

### 7.3 CHECK 제약

```sql
-- 댓글 타입 검증
ALTER TABLE comments
  ADD CONSTRAINT check_comment_type
    CHECK (type IN ('audio', 'text', 'emoji'));

-- 상대 좌표 범위 검증
ALTER TABLE comments
  ADD CONSTRAINT check_relative_x
    CHECK (relative_x IS NULL OR (relative_x >= 0.0 AND relative_x <= 1.0));

ALTER TABLE comments
  ADD CONSTRAINT check_relative_y
    CHECK (relative_y IS NULL OR (relative_y >= 0.0 AND relative_y <= 1.0));

-- 음성 댓글은 audio_url 필수
ALTER TABLE comments
  ADD CONSTRAINT check_audio_comment
    CHECK (type != 'audio' OR audio_url IS NOT NULL);

-- 텍스트 댓글은 text 필수
ALTER TABLE comments
  ADD CONSTRAINT check_text_comment
    CHECK (type != 'text' OR text IS NOT NULL);

-- 재생 시간 범위 검증
ALTER TABLE comments
  ADD CONSTRAINT check_duration
    CHECK (duration >= 0 AND duration <= 300000);  -- 최대 5분
```

### 7.4 인덱스 전략

```sql
-- 사진별 댓글 조회 최적화
CREATE INDEX idx_comments_photo_created
  ON comments(photo_id, created_at)
  WHERE is_deleted = FALSE;

-- 사용자별 댓글 조회 최적화
CREATE INDEX idx_comments_user
  ON comments(recorder_user_id, created_at DESC)
  WHERE is_deleted = FALSE;

-- Soft delete 필터링 최적화
CREATE INDEX idx_comments_is_deleted
  ON comments(is_deleted);
```

### 7.5 트랜잭션 규칙

```dart
// 의사코드
createAudioCommentWithTransaction(data):
  transaction = beginTransaction()

  try:
    // 1. S3 업로드
    audioUrl = await s3.upload(data.audioFile)

    // 2. comments 테이블 INSERT
    commentId = await db.insert("comments", {
      photo_id: data.photoId,
      recorder_user_id: data.userId,
      type: 'audio',
      audio_url: audioUrl,
      duration: data.duration,
      profile_image_url: data.profileImageUrl,
      relative_x: data.relativeX,
      relative_y: data.relativeY,
      is_deleted: false
    })

    // 3. waveform_data 테이블 INSERT
    await db.insert("waveform_data", {
      comment_id: commentId,
      data: JSON.stringify(data.waveformData)
    })

    // 4. 알림 생성 (비동기, 트랜잭션 외부)
    notificationQueue.add({
      type: 'voice_comment',
      photoId: data.photoId,
      commentId: commentId,
      actorUserId: data.userId
    })

    transaction.commit()
    return commentId

  catch (error):
    transaction.rollback()

    // S3 파일도 삭제 (cleanup)
    if (audioUrl):
      await s3.delete(audioUrl)

    throw error
```

---

## 📊 규칙 요약표

| 카테고리         | 규칙 수 | 핵심 내용                                  |
| ---------------- | ------- | ------------------------------------------ |
| 음성 댓글 생성   | 5개     | 파일 크기 10MB, 녹음 시간 5분, 파형 정규화 |
| 텍스트 댓글 생성 | 3개     | 텍스트 최대 1000자, 금지어 필터링          |
| 댓글 조회        | 3개     | isDeleted=false, 시간순 정렬, 페이지네이션 |
| 댓글 삭제        | 1개     | 본인만 가능, Soft delete                   |
| 프로필 위치      | 4개     | 상대 좌표 0.0~1.0, 좌표 변환               |
| 보안             | 4개     | 토큰 검증, Rate limit 10/분, Spam 방지     |
| 데이터 무결성    | 5개     | 외래키 CASCADE, NOT NULL, CHECK 제약       |

---

## 🎯 다음 단계

비즈니스 규칙을 이해했다면:

1. [03-api-endpoints.md](./03-api-endpoints.md)에서 API 명세 확인
2. [04-data-models.md](./04-data-models.md)에서 DB 스키마 확인
3. [05-features.md](./05-features.md)에서 구현 예시 확인
