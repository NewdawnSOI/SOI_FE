import 'package:flutter/foundation.dart';

/// 아카이브 카테고리 상세 화면의 상태를 나타내는 클래스
/// 카테고리 상세 화면에서 필요한 상태 정보를 캡슐화하여, 화면이 상태 변경을 감지하고 적절히 업데이트할 수 있도록 합니다.
///
/// fields:
/// - [categoryIds]: 현재 화면에 표시할 카테고리 ID 목록
/// - [isInitialLoading]: 초기 로딩 중인지 여부
/// - [fatalErrorMessage]: 치명적인 오류 발생 시 사용자에게 보여줄 메시지
///
/// methods:
/// - [operator ==]: 동일한 필드 값을 가진 경우 같은 상태로 간주하여 화면 업데이트를 방지
/// - [hashCode]: 필드 값을 기반으로 해시 코드를 생성하여, 동일한 상태에 대해서는 동일한 해시 코드를 반환
///
class ArchiveCategoryViewState {
  final List<int> categoryIds;
  final bool isInitialLoading;
  final String? fatalErrorMessage;

  const ArchiveCategoryViewState({
    required this.categoryIds,
    required this.isInitialLoading,
    required this.fatalErrorMessage,
  });

  /// 동일한 필드 값을 가진 경우 같은 상태로 간주하여 화면 업데이트를 방지합니다.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArchiveCategoryViewState &&
          runtimeType == other.runtimeType &&
          isInitialLoading == other.isInitialLoading &&
          fatalErrorMessage == other.fatalErrorMessage &&
          listEquals(categoryIds, other.categoryIds);

  /// 필드 값을 기반으로 해시 코드를 생성하여, 동일한 상태에 대해서는 동일한 해시 코드를 반환합니다.
  @override
  int get hashCode => Object.hash(
    isInitialLoading,
    fatalErrorMessage,
    Object.hashAll(categoryIds),
  );
}
