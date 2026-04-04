import 'package:flutter/services.dart';

/// IOSHapticFeedbackService는 Flutter 레이어에서 iOS 네이티브 탭틱 제너레이터를 호출합니다.
class IOSHapticFeedbackService {
  static const MethodChannel _channel = MethodChannel('com.soi.haptics');

  /// 댓글 롱프레스에 맞춘 iOS 네이티브 햅틱을 재생합니다.
  static Future<void> playCommentLongPress() async {
    await _channel.invokeMethod<void>('playCommentLongPress');
  }
}
