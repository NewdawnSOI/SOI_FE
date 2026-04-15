import 'package:flutter/widgets.dart';

/// 무거운 하드웨어 모듈(카메라, 마이크 등)이나 플랫폼 전용 권한 처리 흐름을
/// 본 패키지에서 분리하여 메인 앱 측에 위임하기 위한 델리게이트 인터페이스입니다.
/// 모든 함수는 생성될 데이터의 임시 형태인 [DRAFT]를 반환하게 됩니다.
abstract class MediaTagInputDelegate<DRAFT> {
  /// 사용자가 텍스트 입력을 제출했을 때, 호스트 앱이 문자열을 도메인 draft로 변환해 반환합니다.
  Future<DRAFT?> createTextDraft(BuildContext context, String text);

  /// 사용자가 카메라/갤러리 액션을 눌렀을 때, 호스트 앱이 캡처/선택 플로우를 수행합니다.
  Future<DRAFT?> createCameraDraft(BuildContext context);

  /// 사용자가 마이크 액션을 눌렀을 때, 호스트 앱이 녹음 플로우를 수행합니다.
  Future<DRAFT?> createMicDraft(BuildContext context);
}
