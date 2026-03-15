import 'package:flutter/foundation.dart';

/// 탭 재선택(같은 탭 아이콘을 다시 탭) 시 호출할 콜백 레지스트리.
/// 피드/아카이브 등 각 탭 화면이 "맨 위로 스크롤 + 새로고침" 콜백을 등록합니다.
class TabReselectRegistry {
  TabReselectRegistry._();

  static final Map<int, VoidCallback> _callbacks = {};

  static void register(int index, VoidCallback callback) {
    _callbacks[index] = callback;
  }

  static void unregister(int index) {
    _callbacks.remove(index);
  }

  static void notifyReselect(int index) {
    _callbacks[index]?.call();
  }
}
