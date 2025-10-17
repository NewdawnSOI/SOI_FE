# 태스크 완료 후 체크리스트

## 코드 변경 후 필수 검증

### 1. 코드 품질 검사
```bash
# 코드 분석 (에러/경고 확인)
flutter analyze

# 코드 포매팅
dart format .
```

### 2. 빌드 테스트
```bash
# 디버그 빌드 확인
flutter build apk --debug
flutter build ios --debug

# 의존성 문제 없는지 확인
flutter pub deps
```

### 3. 기능 테스트
- [ ] 변경한 기능이 정상 작동하는지 확인
- [ ] 기존 기능에 영향이 없는지 확인
- [ ] 플랫폼별 테스트 (iOS/Android)

### 4. 메모리 누수 체크
- [ ] Controller에서 dispose() 메서드 구현 확인
- [ ] Stream 구독 해제 확인
- [ ] 타이머나 애니메이션 정리 확인

### 5. Git 커밋 전
```bash
# 변경사항 확인
git status
git diff

# 적절한 커밋 메시지와 함께 커밋
git add .
git commit -m "feat: 기능 추가/수정 내용"
```

### 6. Firebase 관련 변경시
- [ ] Firestore 규칙 업데이트 필요여부 확인
- [ ] Storage 규칙 확인
- [ ] 인덱스 업데이트 필요여부 확인

### 7. 네이티브 코드 변경시 (iOS/Android)
```bash
# iOS
cd ios && pod install

# 네이티브 빌드 테스트
flutter build ios
flutter build android
```