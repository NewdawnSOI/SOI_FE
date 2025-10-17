# SOI 개발 명령어 가이드

## Flutter 개발 명령어
```bash
# 앱 실행 (디버그)
flutter run

# 앱 실행 (릴리즈)
flutter run --release

# 플랫폼별 실행
flutter run -d ios
flutter run -d android
flutter run -d chrome

# 의존성 관리
flutter pub get
flutter pub upgrade
flutter pub deps

# 빌드
flutter build ios
flutter build android
flutter build web
```

## Firebase 명령어
```bash
# Firebase 프로젝트 연결 확인
firebase projects:list

# 에뮬레이터 실행
firebase emulators:start
```

## iOS 네이티브 명령어
```bash
cd ios
pod install
pod update
```

## 코드 품질 관리
```bash
# 코드 분석
flutter analyze

# 포매팅
dart format .

# 테스트 (있는 경우)
flutter test
```

## Git 명령어 (macOS)
```bash
git status
git add .
git commit -m "메시지"
git push
git pull
```

## 유틸리티 명령어 (macOS)
```bash
# 파일 찾기
find . -name "*.dart"

# 텍스트 검색
grep -r "패턴" lib/

# 디렉토리 구조 보기
tree -I "build|.dart_tool"
```