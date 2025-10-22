# 음성/텍스트 댓글 시스템 - 시나리오 및 플로우

이 문서는 음성/텍스트 댓글 시스템의 **주요 시나리오**와 **데이터 플로우**를 설명합니다.

---

## 📋 목차

1. [시나리오 1: 음성 댓글 생성](#시나리오-1-음성-댓글-생성)
2. [시나리오 2: 텍스트 댓글 생성](#시나리오-2-텍스트-댓글-생성)
3. [시나리오 3: 댓글 조회](#시나리오-3-댓글-조회)
4. [시나리오 4: 댓글 삭제](#시나리오-4-댓글-삭제)
5. [시나리오 5: 프로필 이미지 업데이트](#시나리오-5-프로필-이미지-업데이트)

---

## 시나리오 1: 음성 댓글 생성

### 사용자 스토리

> "사진을 보던 사용자 A가 음성 메시지를 녹음하여 댓글을 남기고, 자신의 프로필 이미지를 사진의 특정 위치에 배치한다."

### UI/UX 흐름

```
1. 사용자가 사진 상세 화면에서 "음성 댓글" 버튼 탭
   ↓
2. 마이크 권한 확인 및 녹음 화면 표시
   ↓
3. 녹음 시작 (빨간 원 버튼)
   - 실시간 파형 시각화 (audio_waveforms)
   - 녹음 시간 표시 (00:00)
   - 최대 5분 제한
   ↓
4. 녹음 완료 (정지 버튼)
   - 녹음된 음성 재생 가능
   - 다시 녹음 또는 저장 선택
   ↓
5. "저장" 버튼 탭
   - 프로필 이미지 위치 선택 화면으로 전환
   ↓
6. 사진 위에 프로필 이미지를 드래그하여 위치 지정
   ↓
7. "완료" 버튼 탭
   - 로딩 스피너 표시
   - 백엔드 API 호출
   ↓
8. 댓글 목록에 새 댓글 표시 (실시간)
```

### 데이터 플로우 (현재 - Firebase)

```
[Flutter App]
1. audio_waveforms.RecorderController.record()
   → 로컬 파일 저장: /tmp/audio_xxxx.aac
   → 파형 데이터 수집: List<double> [0.5, 0.8, 0.3, ...]

2. CommentRecordController.createCommentRecord()
   ↓
3. CommentRecordService.createCommentRecord()
   - 입력 검증 (파일 존재, 크기, 확장자)
   - 파형 데이터 정규화 (0.0~1.0)
   ↓
4. CommentRecordRepository.createCommentRecord()
   ↓
5. Firebase Storage 업로드
   - 경로: comment_records/{photoId}_{userId}_{timestamp}.aac
   - 메타데이터: {photoId, recorderUser, uploadedAt}
   → 다운로드 URL 반환
   ↓
6. Firestore 저장
   - 컬렉션: comment_records
   - 문서 ID: 자동 생성
   - 데이터: {
       audioUrl: "https://...",
       photoId: "photo123",
       recorderUser: "user456",
       waveformData: [0.5, 0.8, ...],
       duration: 5000,
       profileImageUrl: "https://...",
       relativePosition: {x: 0.5, y: 0.3},
       type: "audio",
       isDeleted: false,
       createdAt: Timestamp
     }
   ↓
7. NotificationService.createVoiceCommentNotification()
   - 사진 업로더에게 알림 생성
   ↓
8. Firestore Snapshot → Flutter UI 실시간 업데이트
```

### 데이터 플로우 (마이그레이션 후 - Spring Boot)

```
[Flutter App]
1. audio_waveforms.RecorderController.record()
   → 로컬 파일: /tmp/audio_xxxx.aac
   → 파형 데이터: List<double>

2. CommentRecordController.createCommentRecord()
   ↓
3. CommentRecordService.createCommentRecord() (수정)
   - 입력 검증
   - 파형 데이터 정규화
   ↓
4. CommentRecordRepository.createCommentRecord() (HTTP 클라이언트)
   ↓
5. POST /api/photos/{photoId}/comments/audio
   - Content-Type: multipart/form-data
   - Body: {
       audioFile: File,
       waveformData: JSON array,
       duration: 5000,
       relativeX: 0.5,
       relativeY: 0.3
     }
   - Header: Authorization: Bearer {idToken}
   ↓
[Spring Boot Backend]
6. CommentsController.createAudioComment()
   ↓
7. Firebase ID Token 검증
   - 사용자 인증 확인
   ↓
8. CommentsService.createAudioComment()
   - 파일 유효성 검증
   - S3 업로드
   ↓
9. S3Service.uploadAudioFile()
   - 경로: comments/audio/{photoId}/{userId}/{timestamp}.aac
   - ACL: private
   → S3 URL 반환
   ↓
10. CommentsRepository.save()
    - comments 테이블에 INSERT
    - waveform_data 테이블에 INSERT
    ↓
11. NotificationService.createCommentNotification()
    - 알림 생성 (비동기)
    ↓
12. WebSocket 또는 SSE로 실시간 알림
    ↓
[Flutter App]
13. 댓글 목록 갱신 (폴링 또는 WebSocket)
```

### 에러 처리

| 에러 상황              | 처리 방법                         |
| ---------------------- | --------------------------------- |
| 마이크 권한 없음       | 권한 요청 다이얼로그 표시         |
| 파일 크기 초과 (>10MB) | "파일 크기가 너무 큽니다" 토스트  |
| 네트워크 오류          | 재시도 옵션 표시                  |
| 서버 오류 (500)        | "서버 오류가 발생했습니다" 토스트 |
| Firebase Auth 만료     | 자동 토큰 갱신 후 재시도          |

---

## 시나리오 2: 텍스트 댓글 생성

### 사용자 스토리

> "사진을 보던 사용자 B가 간단한 텍스트 메시지를 입력하여 댓글을 남기고, 프로필 이미지를 배치한다."

### UI/UX 흐름

```
1. 사용자가 "텍스트 댓글" 버튼 탭
   ↓
2. 텍스트 입력 다이얼로그 표시
   - TextField (최대 1000자)
   - 글자 수 표시 (0/1000)
   ↓
3. 텍스트 입력 후 "다음" 버튼
   ↓
4. 프로필 이미지 위치 선택 화면
   ↓
5. 드래그하여 위치 지정 후 "완료"
   ↓
6. 댓글 목록에 표시 (실시간)
```

### 데이터 플로우 (현재 - Firebase)

```
[Flutter App]
1. 사용자 텍스트 입력: "좋은 사진이네요!"
   ↓
2. CommentRecordController.createTextComment()
   ↓
3. CommentRecordService.createTextComment()
   - 텍스트 trim() 및 검증
   ↓
4. CommentRecordRepository.createTextComment()
   ↓
5. Firestore 저장
   - 데이터: {
       audioUrl: "",
       text: "좋은 사진이네요!",
       photoId: "photo123",
       recorderUser: "user789",
       waveformData: [],
       duration: 0,
       profileImageUrl: "https://...",
       relativePosition: {x: 0.7, y: 0.5},
       type: "text",
       isDeleted: false,
       createdAt: Timestamp
     }
   ↓
6. 알림 생성
   ↓
7. Firestore Snapshot → UI 업데이트
```

### 데이터 플로우 (마이그레이션 후 - Spring Boot)

```
[Flutter App]
1. 텍스트 입력
   ↓
2. POST /api/photos/{photoId}/comments/text
   - Body: {
       text: "좋은 사진이네요!",
       relativeX: 0.7,
       relativeY: 0.5
     }
   ↓
[Spring Boot]
3. CommentsController.createTextComment()
   ↓
4. 토큰 검증 + 입력 검증
   ↓
5. comments 테이블 INSERT
   - type: 'text'
   - audio_url: NULL
   - text: "좋은 사진이네요!"
   ↓
6. 알림 생성
   ↓
7. Response 반환
   ↓
[Flutter App]
8. UI 갱신
```

---

## 시나리오 3: 댓글 조회

### 사용자 스토리

> "사용자가 사진을 열면 해당 사진의 모든 댓글들이 시간순으로 표시되고, 각 댓글의 프로필 이미지가 사진 위에 배치된다."

### UI/UX 흐름

```
1. 사진 상세 화면 진입
   ↓
2. 로딩 스피너 표시
   ↓
3. 댓글 목록 조회 (백엔드 API)
   ↓
4. 사진 위에 프로필 이미지들 렌더링
   - 각 댓글의 relativePosition 기반
   - 프로필 이미지 클릭 시 댓글 재생/표시
   ↓
5. 하단에 댓글 리스트 표시
   - 시간순 정렬 (createdAt ASC)
   - 음성: 재생 버튼 + 파형
   - 텍스트: 텍스트 내용
```

### 데이터 플로우 (현재 - Firebase)

```
[Flutter App]
1. 사진 상세 화면 진입
   ↓
2. CommentRecordController.loadCommentRecordsByPhotoId(photoId)
   ↓
3. 캐시 확인
   - 캐시 있으면: UI에 즉시 표시
   - 캐시 없으면: 계속 진행
   ↓
4. CommentRecordService.getCommentRecordsByPhotoId()
   ↓
5. CommentRecordRepository.getCommentRecordsByPhotoId()
   ↓
6. Firestore 쿼리
   - WHERE photoId == "photo123"
   - WHERE isDeleted == false
   - ORDER BY createdAt ASC
   ↓
7. 결과 반환: List<CommentRecordModel>
   ↓
8. 캐시 업데이트
   ↓
9. UI 렌더링
```

### 데이터 플로우 (마이그레이션 후)

```
[Flutter App]
1. 사진 상세 화면 진입
   ↓
2. GET /api/photos/{photoId}/comments
   - Query params: page=0, size=100
   ↓
[Spring Boot]
3. CommentsController.getCommentsByPhoto()
   ↓
4. 토큰 검증
   ↓
5. CommentsService.getCommentsByPhotoId()
   ↓
6. CommentsRepository.findByPhotoId()
   - SQL:
     SELECT * FROM comments
     WHERE photo_id = ?
       AND is_deleted = FALSE
     ORDER BY created_at ASC
     LIMIT 100 OFFSET 0
   ↓
7. DTO 변환 (waveform_data JOIN)
   ↓
8. Response: {
     comments: [...],
     totalCount: 25
   }
   ↓
[Flutter App]
9. 캐시 업데이트 + UI 렌더링
```

---

## 시나리오 4: 댓글 삭제

### 사용자 스토리

> "사용자가 자신이 작성한 댓글을 길게 눌러 삭제한다. 자신의 댓글만 삭제할 수 있다."

### UI/UX 흐름

```
1. 댓글을 길게 누름 (Long Press)
   ↓
2. 확인 다이얼로그 표시
   - "이 댓글을 삭제하시겠습니까?"
   - [취소] [삭제]
   ↓
3. "삭제" 버튼 탭
   - UI에서 즉시 제거 (Optimistic UI)
   - 백그라운드에서 API 호출
   ↓
4. 성공: 그대로 유지
   실패: 롤백 + 에러 토스트
```

### 데이터 플로우 (현재 - Firebase)

```
[Flutter App]
1. 댓글 삭제 요청
   ↓
2. CommentRecordController.deleteCommentRecord(commentId, photoId)
   ↓
3. UI에서 즉시 제거 (Optimistic)
   - _commentRecords에서 제거
   - _commentCache에서 제거
   - notifyListeners()
   ↓
4. CommentRecordService.deleteCommentRecord()
   ↓
5. CommentRecordRepository.deleteCommentRecord()
   ↓
6. Firestore 업데이트
   - UPDATE: isDeleted = true
   ↓
7. 성공: 아무 작업 없음
   실패: 롤백
```

### 데이터 플로우 (마이그레이션 후)

```
[Flutter App]
1. 댓글 삭제 요청
   ↓
2. UI 즉시 제거 (Optimistic)
   ↓
3. DELETE /api/comments/{commentId}
   ↓
[Spring Boot]
4. CommentsController.deleteComment()
   ↓
5. 토큰 검증
   ↓
6. 권한 확인
   - 본인 댓글인가?
   ↓
7. CommentsService.deleteComment()
   ↓
8. CommentsRepository.softDelete()
   - SQL:
     UPDATE comments
     SET is_deleted = TRUE,
         updated_at = NOW()
     WHERE id = ?
   ↓
9. Response: 200 OK
   ↓
[Flutter App]
10. 성공: 유지
    실패: 롤백
```

### 권한 로직

```
댓글 삭제 가능 조건:
- 현재 사용자 ID == 댓글 작성자 ID

그 외: 403 Forbidden
```

---

## 시나리오 5: 프로필 이미지 업데이트

### 사용자 스토리

> "사용자가 프로필 이미지를 변경하면, 해당 사용자가 작성한 모든 댓글의 프로필 이미지도 자동으로 업데이트된다."

### UI/UX 흐름

```
1. 설정 화면에서 프로필 이미지 변경
   ↓
2. AuthController.updateProfileImage()
   - Firebase Storage 업로드
   - Firestore users 문서 업데이트
   ↓
3. 연쇄적으로 댓글 프로필 이미지 업데이트
   - CommentRecordController.updateUserProfileImageUrl()
   ↓
4. 모든 댓글의 profileImageUrl 갱신
```

### 데이터 플로우 (현재 - Firebase)

```
[Flutter App - AuthController]
1. 프로필 이미지 업로드 완료
   - 새 URL: "https://storage.../new_profile.jpg"
   ↓
2. Firestore users 업데이트
   ↓
3. CommentRecordController.updateUserProfileImageUrl()
   ↓
4. CommentRecordService.updateUserProfileImageUrl()
   ↓
5. CommentRecordRepository.updateUserProfileImageUrl()
   ↓
6. Firestore 배치 업데이트
   - WHERE recorderUser == userId
   - WHERE isDeleted == false
   - UPDATE profileImageUrl = "https://..."
   ↓
7. 캐시 갱신
   - _commentCache의 모든 댓글 순회
   - userId 일치하는 댓글의 profileImageUrl 갱신
   ↓
8. notifyListeners()
```

### 데이터 플로우 (마이그레이션 후)

```
[Flutter App - AuthController]
1. 프로필 이미지 변경 완료
   ↓
2. PUT /api/users/me/profile-image
   ↓
[Spring Boot - UserService]
3. S3 업로드 + users 테이블 업데이트
   ↓
4. CommentsService.updateUserProfileImageUrl() 호출
   ↓
5. SQL:
   UPDATE comments
   SET profile_image_url = ?
   WHERE recorder_user_id = ?
     AND is_deleted = FALSE
   ↓
6. Response: 200 OK
   ↓
[Flutter App]
7. 캐시 갱신
   ↓
8. UI 갱신
```

---

## 🔄 실시간 업데이트 비교

### 현재 (Firebase)

```
Firestore Snapshot Listener
    ↓
getCommentRecordsStream(photoId)
    ↓
StreamBuilder in Flutter
    ↓
UI 자동 업데이트
```

**장점**: 간단한 구현  
**단점**: Firebase 종속성

### 마이그레이션 후 (Spring Boot)

#### 옵션 1: 폴링 (초기 단계)

```
Timer.periodic(Duration(seconds: 5), (_) {
  GET /api/photos/{photoId}/comments
})
```

**장점**: 구현 간단  
**단점**: 불필요한 네트워크 요청

#### 옵션 2: WebSocket (권장)

```
WebSocket 연결
    ↓
댓글 생성/삭제 시 서버가 메시지 전송
    ↓
Flutter WebSocket Listener
    ↓
UI 업데이트
```

**장점**: 실시간, 효율적  
**단점**: 구현 복잡도 증가

#### 옵션 3: Server-Sent Events (SSE)

```
EventSource 연결
    ↓
서버에서 이벤트 스트림 전송
    ↓
Flutter SSE Listener
    ↓
UI 업데이트
```

**장점**: 단방향 통신에 최적  
**단점**: 브라우저 환경에서 제한

---

## 📊 데이터 흐름 요약

| 기능             | 현재 (Firebase)     | 마이그레이션 후 (Spring Boot) |
| ---------------- | ------------------- | ----------------------------- |
| 음성 댓글 생성   | Firestore + Storage | PostgreSQL + S3               |
| 텍스트 댓글 생성 | Firestore           | PostgreSQL                    |
| 댓글 조회        | Firestore Query     | SQL Query                     |
| 댓글 삭제        | Firestore Update    | SQL UPDATE                    |
| 실시간 업데이트  | Snapshot Listener   | WebSocket/SSE/Polling         |
| 파일 업로드      | 클라이언트 직접     | 백엔드 경유                   |

---

## 🎯 다음 단계

이 문서를 이해했다면:

1. [02-business-rules.md](./02-business-rules.md)에서 비즈니스 규칙 확인
2. [03-api-endpoints.md](./03-api-endpoints.md)에서 API 명세 확인
3. [04-data-models.md](./04-data-models.md)에서 DB 스키마 확인
4. [05-features.md](./05-features.md)에서 구현 가이드 확인
