# SOI 프로젝트 개요

## 프로젝트 목적
SOI (Social Imaging) - 친구들과 함께 사진과 음성을 공유하는 소셜 이미징 플랫폼

## 기술 스택
- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Auth, Firestore, Storage)
- **Native**: Swift (iOS), Kotlin (Android)
- **플랫폼**: Android, iOS, Web, macOS, Linux, Windows

## 아키텍처
- **패턴**: MVC + Provider 상태 관리
- **구조**: lib/{controllers,models,services,repositories,views,widgets}
- **상태 관리**: Provider + ChangeNotifier 패턴

## 주요 기능
- 전화번호 기반 인증
- 카메라 및 사진 촬영 (네이티브 플러그인)
- 음성 메모 첨부
- 카테고리 기반 사진 공유
- 실시간 음성 댓글 시스템
- 연락처 기반 친구 추가