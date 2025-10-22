# 인증 시스템 개요

이 문서는 SOI 앱의 **인증 기능**에 대한 전체적인 설명과 사용 시나리오를 제공합니다.

---

## 📱 인증 시스템이란?

SOI의 인증 시스템은 **전화번호 기반 회원가입 및 로그인**을 제공합니다. 사용자는 전화번호 인증을 통해 계정을 생성하고, 자동 로그인으로 편리하게 앱을 사용할 수 있습니다.

---

## 🎯 핵심 개념

### Firebase UID (영구 식별자)

```
Firebase Authentication → UID 발급 → "xYz123AbC..."
                                      ↓
                          백엔드 DB: users.firebase_uid
```

- **변하지 않는** 고유 식별자
- 전화번호 변경해도 UID는 유지
- 백엔드의 모든 관계는 Firebase UID 기반

### Firebase ID Token (인증 토큰)

```
Flutter → Firebase Auth.getIdToken()
       ↓
Backend → FirebaseAuth.verifyIdToken(token)
       ↓
       ✅ 인증 성공 → UID 추출
```

- **매 API 요청마다** 전송
- **1시간 유효기간** (자동 갱신)
- **변조 불가능** (Firebase 서명)

---

## 📖 주요 시나리오

### 시나리오 1: 신규 회원가입

```
1. [Flutter] 전화번호 입력: "010-1234-5678"
         ↓
2. [Firebase] SMS 발송: "인증번호: 123456"
         ↓
3. [Flutter] 인증번호 입력: "123456"
         ↓
4. [Firebase] 인증 성공 → UID 발급: "abc123..."
         ↓
5. [Flutter] 추가 정보 입력: 이름, 닉네임, 생년월일
         ↓
6. [Flutter] Firebase ID Token 획득
         ↓
7. [Backend] POST /auth/register
   {
     "firebaseUid": "abc123...",
     "idToken": "eyJhbG...",
     "nickname": "hong123",
     "name": "홍길동",
     "phoneNumber": "01012345678",
     "birthDate": "1990-01-01"
   }
         ↓
8. [Backend]
   - ID Token 검증 ✅
   - 닉네임 중복 확인 ✅
   - users 테이블에 저장
   - 응답: UserDTO
```

**결과**: 사용자 계정 생성 완료

---

### 시나리오 2: 기존 회원 로그인

```
1. [Flutter] 앱 시작
         ↓
2. [Firebase] 자동 로그인 확인
   - Firebase Auth 세션 존재?
   - YES → currentUser != null
         ↓
3. [Flutter] Firebase ID Token 획득
         ↓
4. [Backend] POST /auth/login
   {
     "firebaseUid": "abc123...",
     "idToken": "eyJhbG..."
   }
         ↓
5. [Backend]
   - ID Token 검증 ✅
   - users 테이블에서 조회
   - last_login 시간 업데이트
   - 응답: UserDTO
         ↓
6. [Flutter] 홈 화면으로 이동
```

**결과**: 자동 로그인 성공

---

### 시나리오 3: 프로필 이미지 변경

```
1. [Flutter] 갤러리에서 이미지 선택
         ↓
2. [Flutter] 이미지 압축 (1024x1024px)
         ↓
3. [Backend] POST /users/me/profile-image
   Headers: Authorization: Bearer {idToken}
   Body: multipart/form-data (imageFile)
         ↓
4. [Backend]
   - ID Token 검증 ✅
   - 파일 검증 (크기, 형식)
   - 이미지 리사이징
   - S3 업로드
   - 기존 이미지 삭제
   - users.profile_image_url 업데이트
   - 응답: { "profileImageUrl": "https://..." }
         ↓
5. [Flutter] UI 업데이트
```

**결과**: 프로필 이미지 변경 완료

---

### 시나리오 4: 친구 찾기 (닉네임 검색)

```
1. [Flutter] 검색창에 "hong" 입력
         ↓
2. [Backend] GET /users/search?nickname=hong
   Headers: Authorization: Bearer {idToken}
         ↓
3. [Backend]
   - ID Token 검증 ✅
   - DB 쿼리: WHERE nickname LIKE '%hong%'
   - 비활성화 계정 제외
   - 본인 제외
   - 최대 50개 결과 반환
   - 응답: List<UserSearchDTO>
         ↓
4. [Flutter] 검색 결과 표시
```

**결과**: "hong"이 포함된 닉네임 목록 반환

---

### 시나리오 5: 회원 탈퇴

```
1. [Flutter] "정말 탈퇴하시겠습니까?" 확인
         ↓
2. [Backend] DELETE /users/me
   Headers: Authorization: Bearer {idToken}
         ↓
3. [Backend] (트랜잭션)
   - ID Token 검증 ✅
   - 카테고리에서 모든 멤버 관계 삭제
   - 친구 관계 모두 삭제
   - 업로드한 사진/오디오 삭제
   - Storage 파일 삭제
   - users 테이블에서 삭제
   - 응답: 200 OK
         ↓
4. [Flutter] Firebase signOut()
         ↓
5. [Flutter] 로그인 화면으로 이동
```

**결과**: 계정 및 모든 데이터 삭제 완료

---

## 🏗️ 현재 구조 vs 목표 구조

### 현재 (Firebase Only)

```
┌─────────────┐
│   Flutter   │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│ Firebase Auth       │ ← SMS 인증
│ (Phone Auth)        │
└─────────────────────┘
       │
       ▼
┌─────────────────────┐
│ Firestore           │ ← 사용자 정보 저장
│ users/{uid}         │
│  - id, name, phone  │
│  - profile_image    │
└─────────────────────┘
```

**문제점**:

- Firestore는 복잡한 쿼리 어려움
- 트랜잭션 제한적
- 비즈니스 로직이 클라이언트에 분산
- 데이터 무결성 보장 어려움

---

### 목표 (Firebase Auth + Spring Boot)

```
┌─────────────┐
│   Flutter   │
└──────┬──────┘
       │
       ├─────────────────┐
       │                 │
       ▼                 ▼
┌──────────────┐  ┌──────────────────┐
│Firebase Auth │  │ Spring Boot      │
│(Phone Auth)  │  │                  │
│              │  │ ┌──────────────┐ │
│- SMS 발송    │  │ │Firebase      │ │
│- UID 발급    │  │ │ID Token 검증 │ │
│- ID Token    │  │ └──────────────┘ │
│  생성        │  │                  │
└──────────────┘  │ ┌──────────────┐ │
                  │ │PostgreSQL    │ │
                  │ │users 테이블  │ │
                  │ │- firebase_uid│ │
                  │ │- nickname    │ │
                  │ │- name, phone │ │
                  │ └──────────────┘ │
                  │                  │
                  │ ┌──────────────┐ │
                  │ │AWS S3        │ │
                  │ │프로필 이미지 │ │
                  │ └──────────────┘ │
                  └──────────────────┘
```

**장점**:

- ✅ Firebase Auth는 그대로 유지 (SMS 인프라 불필요)
- ✅ 관계형 DB로 복잡한 쿼리 지원
- ✅ 비즈니스 로직 중앙 관리
- ✅ 트랜잭션 완벽 지원
- ✅ 확장성 및 성능 향상

---

## 🔐 보안 흐름

### ID Token 검증 과정

```java
// 1. 클라이언트에서 ID Token 전송
GET /users/me
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...

// 2. Spring Boot에서 검증
FirebaseToken decodedToken = FirebaseAuth.getInstance()
    .verifyIdToken(idToken);

// 3. Firebase UID 추출
String firebaseUid = decodedToken.getUid();

// 4. 사용자 조회
User user = userRepository.findByFirebaseUid(firebaseUid)
    .orElseThrow(() -> new NotFoundException("사용자를 찾을 수 없습니다."));

// 5. 응답
return UserDTO.from(user);
```

---

## 📊 성능 메트릭

### 현재 (Firebase)

| 작업        | 평균 응답 시간 | 병목                |
| ----------- | -------------- | ------------------- |
| 회원가입    | 2-3초          | Firestore 쓰기      |
| 로그인      | 1-2초          | Firestore 읽기      |
| 프로필 조회 | 500ms          | Firestore 읽기      |
| 닉네임 검색 | 1-2초          | Firestore 쿼리 제한 |

### 목표 (Spring Boot)

| 작업        | 목표 응답 시간 | 개선 방법            |
| ----------- | -------------- | -------------------- |
| 회원가입    | **1-2초**      | DB 인덱스, 배치 처리 |
| 로그인      | **500ms-1초**  | 캐싱, 커넥션 풀      |
| 프로필 조회 | **100-300ms**  | Redis 캐싱           |
| 닉네임 검색 | **200-500ms**  | Full-text 인덱스     |

---

## 🔄 데이터 흐름

### 회원가입 데이터 흐름

```
Firebase Auth
     ↓ (UID 발급)
     ↓
Flutter App
     ↓ (사용자 정보 입력)
     ↓
Spring Boot API
     ↓ (검증 + 저장)
     ↓
PostgreSQL
     ↓
users 테이블
  - id: 1
  - firebase_uid: "abc123..."
  - nickname: "hong123"
  - name: "홍길동"
  - phone_number: "01012345678"
  - profile_image_url: "https://..."
  - created_at: 2025-01-15T10:00:00Z
```

---

## 📱 클라이언트 구현 예시

### Flutter - 회원가입

```dart
Future<void> signUp({
  required String phoneNumber,
  required String smsCode,
  required String nickname,
  required String name,
  required String birthDate,
}) async {
  // 1. Firebase 인증
  await FirebaseAuth.instance.verifyPhoneNumber(...);
  final credential = PhoneAuthProvider.credential(
    verificationId: verificationId,
    smsCode: smsCode,
  );
  final userCredential = await FirebaseAuth.instance
      .signInWithCredential(credential);

  // 2. Firebase UID 획득
  String firebaseUid = userCredential.user!.uid;

  // 3. Firebase ID Token 획득
  String idToken = await userCredential.user!.getIdToken();

  // 4. 백엔드 API 호출
  final response = await dio.post('/auth/register', {
    'firebaseUid': firebaseUid,
    'idToken': idToken,
    'nickname': nickname,
    'name': name,
    'phoneNumber': phoneNumber,
    'birthDate': birthDate,
  });

  // 5. 성공
  print('회원가입 완료: ${response.data}');
}
```

---

## 🎨 UI/UX 흐름

### 회원가입 화면 순서

1. **전화번호 입력 화면** (phone_input_screen.dart)

   - 전화번호 입력
   - "인증번호 받기" 버튼

2. **인증번호 입력 화면** (otp_screen.dart)

   - 6자리 인증번호 입력
   - 재전송 버튼

3. **추가 정보 입력 화면** (registration_screen.dart)

   - 닉네임 (ID)
   - 이름
   - 생년월일
   - 프로필 이미지 (선택)

4. **가입 완료 → 홈 화면**

---

## 다음 문서

👉 **[비즈니스 규칙](./02-business-rules.md)** - 검증 로직 및 비즈니스 규칙
