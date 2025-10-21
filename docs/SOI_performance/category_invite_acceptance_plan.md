# 카테고리 초대 수락 기능 요약

## 1. 목적
- 카테고리에 이미 포함된 구성원 중 초대 대상과 친구가 아닌 사용자가 있으면, 초대 받은 사용자를 즉시 `mates`에 편입하지 않고 수락 절차를 거치도록 한다.
- 사용자 경험은 Figma 시안(프레임 `8305:10407`, `8305:10487`)을 기반으로 구현한다.

## 2. 요구사항
- 초대 조건 감지: `FriendService`로 기존 멤버와의 친구 관계를 확인하여 보류 여부를 판단한다.
- 알림 처리: 보류 시 `NotificationType.categoryInvite` 알림을 “수락 필요” 상태로 발송하고, 알림의 “확인” 버튼에서 수락 바텀시트를 띄운다.
- 가입 제어: 초대가 보류된 카테고리는 사용자 카테고리 목록과 스트림에서 제외한다.
- 수락 플로우: 바텀시트에서 수락하면 카테고리 `mates`에 추가하고 초대/알림 상태를 갱신하며, 거절·만료 처리도 지원한다.
- 친구 확인: 바텀시트의 “친구 확인” 버튼으로 멤버 목록 바텀시트를 열고, 항목 선택 시 기존 프로필 상세 바텀시트를 재사용한다.

## 3. 데이터 구조
- `NotificationModel`에 `requiresAcceptance`, `pendingCategoryMemberIds`, `categoryInviteId` 등 초대 수락 관련 필드를 추가한다.
- Firestore `categoryInvites` 컬렉션을 신설하여 `categoryId`, `invitedUserId`, `inviterId`, `status(pending/accepted/declined)`, `blockedMateIds`, `createdAt`, `updatedAt`을 저장하고, `invitedUserId+status`, `categoryId+invitedUserId` 인덱스를 구성한다.
- `CategoryDataModel`은 수락 완료 시에만 `mates`를 갱신하며, 서비스 레이어에서 보류 카테고리를 필터링한다.
- Firestore 보안 규칙을 조정해 초대 당사자만 관련 문서를 읽고 쓸 수 있도록 한다.

## 4. 서비스/레포지토리 변경
- `CategoryService`
  - 멤버 추가 시 친구 관계를 검사해 보류 여부를 결정한다.
  - 보류 시 `categoryInvites` 문서와 알림을 생성하고, 즉시 가입 조건과 분리한다.
  - `getUserCategories{,Stream}` 결과에서 보류 카테고리를 제외한다.
- `NotificationService`
  - 초대 알림에 새 필드를 반영하고, `acceptCategoryInvite`·`declineCategoryInvite`로 상태 전환을 처리한다.
  - 수락 시 `mates` 업데이트, 초대 문서 상태 변경, 알림 읽음 처리까지 묶어서 수행한다.
- `CategoryRepository`
  - 보류 상태 확인 및 `mates` 갱신을 지원하기 위한 보조 메서드를 추가한다.
- 필요 시 초대 만료 스케줄러 등 부가 로직도 도입한다.

## 5. UI/UX 흐름
- 알림 화면에서 “확인”을 누르면 `showModalBottomSheet`로 수락 안내 바텀시트를 연다.
Figma link: https://www.figma.com/design/rOPJ7cmvUKQUUPzBQsJGoP/%EB%89%B4%EB%8D%98?node-id=8305-10369&t=N4dtLCl1Q6XvVrOu-4

- 1차 바텀시트: 초대 메시지와 “친구 확인”, “수락”, “취소” 버튼을 제공한다.
Figma link: https://www.figma.com/design/rOPJ7cmvUKQUUPzBQsJGoP/%EB%89%B4%EB%8D%98?node-id=8305-10407&m=dev

- “친구 확인”을 탭하면 2차 바텀시트에서 전체 멤버 목록을 표시하고, 각 항목은 프로필 상세 바텀시트를 호출한다.
Figma link: https://www.figma.com/design/rOPJ7cmvUKQUUPzBQsJGoP/%EB%89%B4%EB%8D%98?node-id=8305-10487&m=dev

- 수락 또는 거절 이후 알림 목록과 카테고리 리스트가 즉시 갱신되도록 컨트롤러 상태를 업데이트한다.
Figma link: https://www.figma.com/design/rOPJ7cmvUKQUUPzBQsJGoP/%EB%89%B4%EB%8D%98?node-id=8305-10407&m=dev

### 구현 현황 (2024-04)
- `lib/views/about_notification/notification_screen.dart:116`에서 초대 알림 클릭 시 수락 바텀시트를 띄우고, 수락/거절 흐름 및 친구 리스트/상세 바텀시트(`CategoryInviteFriendListSheet`, `CategoryInviteFriendDetailSheet`)를 연결.
- `lib/views/about_notification/widgets/notification_item_widget.dart:50`과 `:100`에서 수락 대기 여부를 반영해 라벨과 확인 버튼 노출 조건을 갱신.
- `lib/views/about_notification/widgets/category_invite_confirm_sheet.dart:5`에 Figma 시안을 토대로 1차 수락 시트와 친구 확인 시트 UI 컴포넌트를 구현.
- `lib/controllers/notification_controller.dart:349`와 `lib/services/notification_service.dart:426`에서 초대 수락 시 알림 상태를 갱신하고 `CategoryService`의 `acceptPendingInvite`/`declinePendingInvite`와 연동.
- `lib/services/category_service.dart:505`에 비친구 탐색 및 초대 문서 생성, 수락/거절 처리 로직을 추가하여 UI 동작과 데이터가 일치하도록 했다.

## 6. 테스트 및 QA
- 서비스 단위 테스트: 친구/비친구 조합, 중복 수락 방지, 거절 후 재초대, 상태 전이 시나리오를 검증한다.
- UI 테스트: 알림 → 바텀시트 → 친구 목록 → 세부 정보 흐름과 오류/타임아웃 대응을 확인한다.
- QA 체크리스트: 수락 전 카테고리 비노출, 수락 후 전체 화면 동기화, 초대 만료 시 기대 동작을 확인한다.

## 7. 후속 작업
1. Firestore 보안 규칙과 인덱스를 작성해 배포한다.
2. Figma 시안을 기준으로 상세 UI 컴포넌트를 개발한다.
3. 기존 초대 데이터가 있다면 마이그레이션 또는 백필 전략을 마련한다.
4. 재알림, 만료 정책 등 추가 UX 요구사항을 논의한다.
