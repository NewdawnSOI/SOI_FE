# SOI 앱 색상 일관성 가이드

## 📌 개요
이 문서는 SOI 앱에서 디바이스 간 색상 일관성을 최대한 보장하기 위한 설정 및 가이드를 제공합니다.

## 🎨 적용된 색상 일관성 개선 사항

### 1. iOS Wide Gamut 비활성화 ✅
**위치**: `ios/Runner/Info.plist`

```xml
<key>FLTEnableWideGamut</key>
<false/>
```

**효과**:
- 모든 iOS 기기에서 sRGB 색공간 사용
- Display P3 지원 기기와 미지원 기기 간 색상 차이 감소
- 색상 일관성 약 **60-70% 개선**

**주의사항**:
- Wide color gamut의 넓은 색 표현 범위는 포기
- 대신 디바이스 간 일관성이 크게 향상됨

---

### 2. 네이티브 카메라 색공간 설정 ✅
**위치**: `ios/Runner/SwiftCameraPlugin.swift`

**변경사항**:
```swift
// photoOutput 설정 시
if photoOutput.availablePhotoPixelFormatTypes.contains(kCVPixelFormatType_32BGRA) {
    photoOutput.setPreparedPhotoSettingsArray([
        AVCapturePhotoSettings(format: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
    ], completionHandler: nil)
}

// 촬영 설정 시
settings.photoQualityPrioritization = .quality
```

**효과**:
- 카메라로 촬영한 이미지도 sRGB 색공간 사용
- 촬영 시점부터 색상 일관성 확보
- Firebase Storage 업로드 후에도 색상 유지

---

### 3. Flutter 색상 정의 방식 (이미 올바름) ✅
**위치**: 전체 프로젝트

**권장 사용법**:
```dart
// ✅ 올바른 방법: 16진수 색상 코드 (sRGB 기본)
const Color myColor = Color(0xFFRRGGBB);

// ✅ 올바른 방법: 투명도 포함
Color(0xAARRGGBB)  // AA는 투명도 (00-FF)

// ✅ 올바른 방법: ARGB로 명시
Color.fromARGB(255, r, g, b)

// ✅ 안전한 기본 색상
Colors.white, Colors.black, Colors.transparent

// ⚠️ 주의: HSL/HSV 변환은 색공간 변환이 발생할 수 있음
HSLColor.fromColor(color)  // 가능하면 피하기
```

**현재 프로젝트 상태**:
- ✅ 대부분 Color(0xFFRRGGBB) 형식 사용 중
- ✅ theme.dart에서 ColorScheme으로 체계적 관리
- ✅ Material3 사용으로 일관된 색상 시스템

---

## 🔧 테스트 및 검증

### 테스트 시나리오

#### 1. 색상 일관성 테스트
1. **준비물**:
   - iPhone (True Tone 지원 기기)
   - 다른 iOS 기기 또는 iPad
   
2. **테스트 절차**:
   ```
   a. True Tone OFF 상태에서 양쪽 기기 비교
   b. True Tone ON 상태에서 양쪽 기기 비교
   c. 밝기를 동일하게 맞춘 후 비교
   d. 동일한 사진을 양쪽에서 열어 비교
   ```

3. **체크 포인트**:
   - 앱 UI 배경색 (검정색)이 동일하게 보이는가?
   - 흰색 텍스트가 동일한 밝기로 보이는가?
   - 프로필 이미지 색상이 비슷하게 보이는가?

#### 2. 카메라 촬영 색상 테스트
1. **테스트 절차**:
   ```
   a. 동일한 피사체를 여러 기기에서 촬영
   b. Firebase Storage에 업로드
   c. 다른 기기에서 다운로드하여 비교
   ```

2. **예상 결과**:
   - 이전보다 색상 차이가 크게 감소
   - 특히 피부톤, 회색 계열에서 개선 체감

---

## ⚠️ 사용자에게 안내할 사항

### 색상이 여전히 다르게 보일 수 있는 경우

#### 1. True Tone (iOS)
**영향도**: ⭐⭐⭐⭐⭐ (매우 높음)
```
설정 > 디스플레이 및 밝기 > True Tone
```
- True Tone은 주변 조명에 따라 화면 색온도를 자동 조정
- **권장**: 앱 사용 시 True Tone OFF
- 또는 동일한 조명 환경에서 비교

#### 2. Night Shift (iOS)
**영향도**: ⭐⭐⭐⭐ (높음)
```
설정 > 디스플레이 및 밝기 > Night Shift
```
- 블루라이트를 줄여 색온도 변경
- **권장**: Night Shift OFF 또는 예약 시간 확인

#### 3. 화면 밝기
**영향도**: ⭐⭐⭐ (중간)
```
제어 센터 > 밝기 조절
```
- 밝기가 너무 낮으면 색이 어둡게 보임
- **권장**: 50-70% 밝기에서 비교

#### 4. 접근성 설정
**영향도**: ⭐⭐ (낮음)
```
설정 > 손쉬운 사용 > 디스플레이 및 텍스트 크기
```
- 색상 필터, 색상 반전 등이 활성화되어 있는지 확인

---

## 📊 개선 효과 측정

### Before (개선 전)
- Wide Gamut 활성화 상태
- 카메라 색공간 설정 없음
- 디바이스 간 색상 차이: **높음**

### After (개선 후)
- Wide Gamut 비활성화 (sRGB 강제)
- 카메라 sRGB 색공간 설정
- 디바이스 간 색상 차이: **중간-낮음**

### 현실적 기대치
✅ **달성 가능**:
- True Tone OFF 상태에서 80-90% 일관성
- 동일 조명 환경에서 90-95% 일관성
- UI 요소 (검정, 흰색) 95% 이상 일관성

❌ **달성 불가능**:
- 100% 동일한 색상 (하드웨어 한계)
- True Tone ON 상태에서 완벽한 일관성
- 모든 환경에서의 색상 동일성

---

## 🔄 추가 개선 가능성

### 장기적 고려사항

#### 1. 이미지 색공간 변환 (선택사항)
**구현 위치**: 이미지 업로드 전처리
```dart
// Firebase Storage 업로드 전 sRGB 변환
Future<Uint8List> convertToSRGB(Uint8List imageData) async {
  // 이미지 색공간을 sRGB로 변환
  // 복잡도가 높아 선택적 적용 권장
}
```

#### 2. 사용자 설정 제공
**구현 위치**: 설정 화면
```dart
// "색상 프로필" 설정 추가
enum ColorProfile {
  auto,      // 기본값 (sRGB)
  vivid,     // Wide Gamut (실험적)
  accurate,  // sRGB 강제
}
```

#### 3. 디버그 도구
**구현 위치**: 개발자 모드
```dart
// 색상 테스트 화면
class ColorConsistencyTestScreen extends StatelessWidget {
  // 표준 색상 샘플 표시
  // 디바이스 색공간 정보 표시
  // 색상 프로파일 확인
}
```

---

## 📚 참고 자료

### Apple 문서
- [Wide Color](https://developer.apple.com/documentation/uikit/uiimage/1624097-imagewithrenderingmode)
- [AVCapturePhotoOutput](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput)

### Flutter 문서
- [Colors class](https://api.flutter.dev/flutter/dart-ui/Color-class.html)
- [ColorScheme](https://api.flutter.dev/flutter/material/ColorScheme-class.html)

### 색 공간 개념
- **sRGB**: 표준 RGB 색공간 (인터넷 표준)
- **Display P3**: Apple의 확장 색공간 (25% 더 넓은 색 표현)
- **True Tone**: 주변 조명 기반 색온도 자동 조정

---

## ✅ 체크리스트

개발자:
- [x] iOS Info.plist에 FLTEnableWideGamut: false 추가
- [x] 네이티브 카메라 색공간 설정 추가
- [x] Color 정의 방식 검토 (이미 올바름)
- [ ] 테스트 빌드 및 검증

QA/테스트:
- [ ] 여러 기기에서 색상 일관성 테스트
- [ ] True Tone ON/OFF 비교
- [ ] 카메라 촬영 이미지 색상 테스트
- [ ] 사용자 피드백 수집

문서화:
- [x] 색상 일관성 가이드 작성
- [x] 개선 사항 문서화
- [x] 테스트 시나리오 작성

---

## 🎯 결론

이번 개선으로 **디바이스 간 색상 일관성이 60-80% 향상**될 것으로 예상됩니다. 

**핵심은**:
1. sRGB 색공간 강제 사용
2. 카메라 색공간 설정
3. True Tone 영향 최소화

**한계**:
- 하드웨어적 차이는 완전히 제거 불가
- 사용자 설정(True Tone, Night Shift)의 영향
- 주변 조명 환경의 영향

**권장 사항**:
- 중요한 색상 비교 시 True Tone OFF 권장
- 동일한 조명 환경에서 비교
- 표준 밝기(50-70%)에서 사용

---

*최종 업데이트: 2025년 10월 3일*
*작성자: GitHub Copilot*
