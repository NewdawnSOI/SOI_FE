# JWT + FCM Frontend Integration Guide

## 목적
- 프론트가 새 로그인 API를 사용해 JWT를 발급받는다.
- 인증이 필요한 API는 `Authorization: Bearer {accessToken}` 헤더로 호출한다.
- `@AuthenticationPrincipal Long userId`로 바뀐 API는 더 이상 body/query에 내 `userId`를 보내지 않는다.
- FCM 토큰 등록/삭제 API를 통해 푸시 알림을 연결한다.

## 1. 로그인 API

### 사용해야 하는 로그인 API
- `POST /auth/login`

### 요청 body
```json
{
  "nickname": "tester",
  "phoneNum": "01012345678"
}
```

### 응답 body
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiJ9..."
}
```

## 주의
- 이 로그인 API는 다른 API와 다르게 `ApiResponseDto`로 감싸지지 않는다.
- 즉 프론트는 `data.accessToken`이 아니라 응답 JSON 최상위의 `accessToken`을 읽어야 한다.

## 현재 보안 설정 기준
- `/auth/**` 만 비인증 허용
- 그 외 모든 API는 JWT 필요

즉 프론트는 로그인에 `POST /auth/login`만 사용해야 한다.

### 사용하지 말아야 하는 기존 로그인 API
- `POST /user/login/by-phone`
- `POST /user/login/by-nickname`

위 두 API는 현재 `SecurityConfig` 기준으로 공개 API가 아니라서 로그인 진입점으로 쓰면 안 된다.

## 2. JWT 전달 방식

모든 인증 API 요청 헤더:
```http
Authorization: Bearer {accessToken}
```

예시:
```http
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

백엔드는 이 토큰에서 `userId`를 꺼내서 Spring Security Context에 넣고, 컨트롤러에서 `@AuthenticationPrincipal Long userId`로 받는다.

## 3. 프론트 공통 규칙

### 해야 하는 것
- 로그인 성공 후 `accessToken` 저장
- 인증이 필요한 모든 요청에 `Authorization` 헤더 자동 부착
- `@AuthenticationPrincipal` 기반으로 바뀐 API는 내 `userId`를 body/query에서 제거

### 하면 안 되는 것
- JWT 기반 API에서 내 `userId`를 프론트가 별도로 신뢰 소스로 사용
- 토큰 기반 API인데 body에 임의의 내 userId를 같이 보내는 것

## 4. userId를 JWT에서 가져오는 API

아래 API들은 백엔드가 토큰에서 `userId`를 가져온다.
프론트는 내 `userId`를 보내지 않는다.

### User
- `GET /user/get`
- `PATCH /user/update`
- `PATCH /user/update-profile?profileImageKey=...`

### Friend
- `GET /friend/get-all?friendStatus=...`
- `GET /friend/check-friend-relation?friendPhoneNums=010...,010...`

### Comment
- `GET /comment/get/by-user-id?page=0`

### Media
- `POST /media/upload`
  - multipart 요청
  - `types`
  - `usageTypes`
  - `refId`
  - `usageCount`
  - `files`
  - 내 `userId`는 보내지 않음

### Category
- `POST /category/delete?categoryId=...`
- `POST /category/find?categoryFilter=ALL&page=0`
- `POST /category/find-by-keyword?categoryFilter=ALL&keyword=...&page=0`
- `POST /category/set/pinned?categoryId=...`
- `POST /category/set/name?categoryId=...&name=...`
- `POST /category/set/profile?categoryId=...&profileImageKey=...`
- `POST /category/set/alert?categoryId=...`

### Post
- `GET /post/find-by/category?categoryId=...&notificationId=...&page=0`
- `GET /post/find-all?postStatus=ACTIVE&page=0`
- `GET /post/find/by-user-id?postType=PHOTO&page=0`

### Notification
- `POST /notification/get-all?page=0`
- `POST /notification/get-friend?page=0`

### FCM Device Token
- `POST /notification/device-token/register`
- `POST /notification/device-token/delete`

## 5. 아직 body/query에 userId가 남아 있는 API

아래 API들은 현재 코드 기준으로 아직 완전히 JWT 전환이 끝나지 않았다.
즉 프론트가 기존처럼 `userId`, `requesterId`, `responserId` 등을 body에 보내야 한다.

### Category
- `POST /category/create`
  - body에 `requesterId` 필요
- `POST /category/invite`
  - body에 `requesterId` 필요
- `POST /category/invite/response`
  - body에 `responserId` 필요

### Friend
- `POST /friend/create`
  - body에 `requesterId` 필요
- `POST /friend/create/by-nickname`
  - body에 `requesterId` 필요
- `POST /friend/delete`
  - body에 `requesterId`, `receiverId` 필요
- `POST /friend/block`
  - body에 `requesterId`, `receiverId` 필요
- `POST /friend/unblock`
  - body에 `requesterId`, `receiverId` 필요

### Comment
- `POST /comment/create`
  - body에 `userId` 필요

### Post
- `POST /post/create`
  - body에 `userId` 필요

## 프론트 해석 기준
- 위 목록은 "현재 코드 실제 상태" 기준이다.
- 즉 JWT 전환이 완료된 API와 미완료 API가 섞여 있다.
- 프론트는 API별로 다르게 처리해야 한다.

## 6. FCM 연동 시 프론트가 해야 할 요청

### 6-1. 로그인 후 또는 앱 시작 시 토큰 등록
- Firebase Messaging에서 FCM token 발급
- JWT 로그인 완료 후 아래 API 호출

#### 요청
- `POST /notification/device-token/register`

```json
{
  "token": "fcm_device_token_here",
  "platform": "ANDROID"
}
```

#### 헤더
```http
Authorization: Bearer {accessToken}
Content-Type: application/json
```

#### platform 값
- `ANDROID`
- `IOS`
- `WEB`

### 6-2. 토큰 refresh 시 재등록
- FCM token이 갱신되면 같은 API를 다시 호출
- 같은 유저 기준으로 최신 token을 재바인딩한다

### 6-3. 로그아웃 시 토큰 삭제
- `POST /notification/device-token/delete`

```json
{
  "token": "fcm_device_token_here"
}
```

로그아웃 순서 권장:
1. `/notification/device-token/delete` 호출
2. 로컬 accessToken 삭제
3. 로컬 FCM 관련 상태 정리

## 7. 프론트 권장 플로우

### 앱 최초 로그인
1. `POST /auth/login`
2. `accessToken` 저장
3. 인증 API 공통 헤더 세팅
4. FCM token 발급
5. `POST /notification/device-token/register`
6. 알림 목록 필요 시 `POST /notification/get-all?page=0`

### 앱 재실행
1. 저장된 `accessToken` 복원
2. 인증 API 헤더 세팅
3. FCM token 확인
4. token이 있으면 `POST /notification/device-token/register`

### 로그아웃
1. 현재 FCM token 조회
2. `POST /notification/device-token/delete`
3. accessToken 삭제

## 8. Flutter 요청 예시

### 공통 Authorization 헤더
```dart
final response = await dio.get(
  '/user/get',
  options: Options(
    headers: {
      'Authorization': 'Bearer $accessToken',
    },
  ),
);
```

### 로그인
```dart
final response = await dio.post(
  '/auth/login',
  data: {
    'nickname': nickname,
    'phoneNum': phoneNum,
  },
);

final accessToken = response.data['accessToken'] as String;
```

### FCM 토큰 등록
```dart
await dio.post(
  '/notification/device-token/register',
  data: {
    'token': fcmToken,
    'platform': 'ANDROID',
  },
  options: Options(
    headers: {
      'Authorization': 'Bearer $accessToken',
    },
  ),
);
```

### FCM 토큰 삭제
```dart
await dio.post(
  '/notification/device-token/delete',
  data: {
    'token': fcmToken,
  },
  options: Options(
    headers: {
      'Authorization': 'Bearer $accessToken',
    },
  ),
);
```

## 9. 푸시 payload에서 프론트가 받을 수 있는 data 키

현재 백엔드가 FCM data payload에 넣는 키:
- `notificationId`
- `type`
- `friendId`
- `categoryId`
- `categoryInviteId`
- `postId`
- `commentId`

예시:
```json
{
  "notificationId": "123",
  "type": "COMMENT_ADDED",
  "postId": "456",
  "categoryId": "10",
  "commentId": "99"
}
```

프론트는 이 값을 기준으로:
- 알림 화면 이동
- 특정 게시물 상세 이동
- 특정 카테고리 이동
- 알림 읽음 처리 연동

를 구현하면 된다.

## 10. 프론트 체크리스트

- 로그인은 `/auth/login` 사용
- 로그인 응답은 `ApiResponseDto`가 아니라 raw JSON으로 파싱
- 보호된 API는 모두 `Authorization: Bearer {accessToken}` 사용
- 토큰 기반 API에서는 내 `userId`를 보내지 않음
- 아직 미전환 API는 기존처럼 `requesterId/userId`를 body에 넣음
- 로그인 후 FCM token 등록
- token refresh 시 재등록
- 로그아웃 시 token 삭제

## 11. 현재 상태에서 꼭 알아둘 점

- 현재 백엔드는 "JWT 완전 전환" 상태가 아니라 "일부 API만 토큰 기반 전환 완료" 상태다.
- 따라서 프론트는 API별로 요청 형식이 다르다.
- 이후 백엔드가 `category create/invite`, `friend create/delete/block`, `comment create`, `post create`까지 토큰 기반으로 바꾸면 프론트도 그때 body의 `userId/requesterId`를 제거하면 된다.
