import 'package:flutter/foundation.dart';

import '../../../../api/models/category.dart' as api_category;

/// 모델: 카테고리 프로필 행 데이터
/// 카테고리 프로필 행에 표시할 사용자 프로필 URL 키 목록과 총 사용자 수를 포함합니다.
/// ApiArchiveCardWidget 및 ApiArchiveProfileRowWidget에서 사용됩니다.
class CategoryProfileRowData {
  final List<String> profileUrlKeys;
  final int totalUserCount;

  const CategoryProfileRowData({
    required this.profileUrlKeys,
    required this.totalUserCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryProfileRowData &&
          runtimeType == other.runtimeType &&
          totalUserCount == other.totalUserCount &&
          listEquals(profileUrlKeys, other.profileUrlKeys);

  @override
  int get hashCode =>
      Object.hash(totalUserCount, Object.hashAll(profileUrlKeys));
}

class ArchiveCardViewData {
  final String name;
  final String? photoUrl;
  final bool isNew;
  final CategoryProfileRowData profileRowData;

  const ArchiveCardViewData({
    required this.name,
    required this.photoUrl,
    required this.isNew,
    required this.profileRowData,
  });

  ///
  /// 모델: 아카이브 카드 뷰 데이터
  /// 아카이브 카드에 표시할 카테고리 이름, 대표 사진 URL, 신규 여부, 프로필 행 데이터를 포함합니다.
  /// ApiArchiveCardWidget에서 사용됩니다.
  ///
  /// fields:
  /// - [name]: 카테고리 이름
  /// - [photoUrl]: 카테고리 대표 사진 URL (null일 수 있음)
  /// - [isNew]: 카테고리가 신규인지 여부
  /// - [profileRowData]: 카테고리 프로필 행 데이터 (CategoryProfileRowData 객체)
  ///
  /// methods:
  /// - [fromCategory]: API 카테고리 모델(api_category.Category)에서 ArchiveCardViewData로 변환하는 팩토리 생성자
  /// - [== operator]: 객체 동등성 비교 연산자, 모든 필드를 비교하여 동일한 값을 가지는 경우에 true 반환
  /// - [hashCode]: 객체 해시 코드 계산, 모든 필드를 기반으로 고유한 해시 코드 생성
  ///

  factory ArchiveCardViewData.fromCategory(api_category.Category category) {
    return ArchiveCardViewData(
      name: category.name,
      photoUrl: category.photoUrl,
      isNew: category.isNew,
      profileRowData: CategoryProfileRowData(
        profileUrlKeys: category.usersProfileKey,
        totalUserCount: category.totalUserCount,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArchiveCardViewData &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          photoUrl == other.photoUrl &&
          isNew == other.isNew &&
          profileRowData == other.profileRowData;

  @override
  int get hashCode => Object.hash(name, photoUrl, isNew, profileRowData);
}
