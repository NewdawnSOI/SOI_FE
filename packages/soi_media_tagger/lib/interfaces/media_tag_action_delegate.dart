import 'package:flutter/material.dart';
import '../models/media_tag.dart';

/// 앱의 UI 계층에서 태그 오버레이가 제공하는 상호작용(탭, 롱프레스, 생성 등)을 
/// 외부 도메인 상태 관리자(Provider/Controller 등)로 브릿징해주는 프로토콜입니다.
abstract class MediaTagActionDelegate<T> {
  /// 사용자가 오버레이 상에서 유효한 위치를 탭하여(혹은 드래그로) 
  /// 신규 태그가 될 임시 타겟 위치가 확정되었을 때 호출됩니다.
  void onTagAdded(Offset relativePosition);

  /// 롱프레스 등을 통해 기존 태그의 삭제 이벤트가 발생했을 때 호출됩니다.
  void onTagDeleted(String tagId);

  /// 기존 태그 아바타 영역이 탭되었을 때 호출됩니다.
  void onTagTap(MediaTag<T> tag, Offset anchorPosition);
}
