import 'package:flutter/material.dart';
import '../models/media_tag.dart';

/// 다른 프로젝트에서 특정 백엔드(Firebase, Supabase 등)를 사용할 때
/// 이 인터페이스를 상속받아 통신 및 세이브 로직을 구현합니다.
/// [T] 태그의 확정된 데이터 모델
/// [DRAFT] 작성 중인 임시 데이터 모델 (로컬 파일 경로 등)
abstract class MediaTagDataSource<T, DRAFT> {
  /// 특정 미디어(이미지/비디오)의 기존 태그 목록을 불러옵니다.
  /// [mediaId] 서버에 저장된 타겟 미디어 레퍼런스 ID
  Future<List<MediaTag<T>>> fetchTags(String mediaId);

  /// 새로운 태그 데이터를 실제 서버에 기록하고 최종 모델을 반환합니다.
  /// [mediaId] 태그가 추가될 대상 미디어의 참조 ID
  /// [relativePosition] 상대 좌표 (0.0 ~ 1.0 비율 구조의 Offset)
  /// [draftData] 사용자 프로필 등 아직 ID가 발급되지 않은 임시 로컬 데이터
  Future<MediaTag<T>> createTag(
    String mediaId,
    Offset relativePosition,
    DRAFT draftData, {
    ValueChanged<double>? onProgress,
  });

  /// 서버에서 해당 태그를 삭제합니다.
  Future<void> deleteTag(String tagId);
}
