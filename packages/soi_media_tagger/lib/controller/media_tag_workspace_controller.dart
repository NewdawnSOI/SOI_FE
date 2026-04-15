import 'package:flutter/material.dart';

import '../interfaces/media_tag_data_source.dart';
import '../models/media_tag.dart';

/// 태깅 워크스페이스의 현재 모드를 나타냅니다.
enum TaggerWorkspaceMode {
  /// 기본 상태: 태그 목록을 렌더링하고 사용자가 새 입력(하단 바 등)을 대기합니다.
  ready,
  /// 로딩 상태: 초기 태그를 불러오거나 네트워크 요청 중인 상태입니다.
  initialLoading,
  /// 배치 상태: 임시 프로필 마커(Pending Tag)를 띄워두고 사용자가 위치를 잡을 때까지 기다립니다.
  placing,
  /// 저장 상태: 드래그가 끝나고 서버로 통신을 보내 저장 중인 상태입니다.
  saving,
}

/// 패키지 기본 composer가 입력 단계 전환을 맞출 때 사용하는 UI 모드입니다.
enum MediaTagComposerMode {
  base,
  typing,
}

/// 패키지 내부에서 태그 목록과 임시 생성 상태를 알아서 동기화하는 상태 엔진입니다.
class MediaTaggerWorkspaceController<T, DRAFT> extends ChangeNotifier {
  final MediaTagDataSource<T, DRAFT> dataSource;
  final String mediaId;

  MediaTaggerWorkspaceController({
    required this.mediaId,
    required this.dataSource,
  });

  List<MediaTag<T>> _tags = [];
  List<MediaTag<T>> get tags => _tags;

  TaggerWorkspaceMode _mode = TaggerWorkspaceMode.initialLoading;
  TaggerWorkspaceMode get mode => _mode;

  DRAFT? _pendingDraft;
  DRAFT? get pendingDraft => _pendingDraft;

  Offset? _pendingPosition;
  Offset? get pendingPosition => _pendingPosition;

  double? _pendingProgress;
  double? get pendingProgress => _pendingProgress;

  Object? _lastError;
  Object? get lastError => _lastError;

  /// 서버에서 태그 목록을 불러옵니다.
  Future<void> fetchTags() async {
    _mode = TaggerWorkspaceMode.initialLoading;
    notifyListeners();

    try {
      _tags = await dataSource.fetchTags(mediaId);
      _mode = TaggerWorkspaceMode.ready;
    } catch (e) {
      _lastError = e;
      _mode = TaggerWorkspaceMode.ready; // 에러가 나도 그릴 수는 있게 레디로 변경
    }
    notifyListeners();
  }

  /// 텍스트, 사진, 비디오 등 입력 델리게이트로부터 임시 데이터[draft]를 전달받으면,
  /// 화면을 배치 모드(placing)로 변경합니다.
  void startPlacing(DRAFT draft) {
    _pendingDraft = draft;
    _pendingPosition = null;
    _pendingProgress = null;
    _mode = TaggerWorkspaceMode.placing;
    notifyListeners();
  }

  /// 배치 모드에서 유저가 임시 마커를 드래그하는 동안 계속 호출되어 좌표를 업데이트합니다.
  void updatePendingPosition(Offset relativePosition) {
    if (_mode != TaggerWorkspaceMode.placing) return;
    _pendingPosition = relativePosition;
    notifyListeners();
  }

  /// 드롭 타깃이 위치를 확정했을 때 저장 전 pending 마커 좌표를 기록합니다.
  void confirmPendingPosition(Offset relativePosition) {
    if (_mode != TaggerWorkspaceMode.placing) return;
    _pendingPosition = relativePosition;
    notifyListeners();
  }

  /// 유저가 마커 드래그를 끝내고 서버에 저장을 확정합니다.
  Future<void> commitPendingTag() async {
    if (_pendingDraft == null || _pendingPosition == null) return;
    if (_mode != TaggerWorkspaceMode.placing) return;

    _mode = TaggerWorkspaceMode.saving;
    _pendingProgress = 0.0;
    notifyListeners();

    try {
      final newTag = await dataSource.createTag(
        mediaId,
        _pendingPosition!,
        _pendingDraft as DRAFT,
        onProgress: (value) {
          _pendingProgress = value.clamp(0.0, 1.0).toDouble();
          notifyListeners();
        },
      );
      
      // 성공 시 내부 리스트에 반영하고 대기 모드로 돌아감
      _tags.add(newTag);
      _cancelPlacing();
    } catch (e) {
      _lastError = e;
      _pendingProgress = null;
      // 실패 시 다시 배치 모드로 돌아가 재시도할 수 있게 함
      _mode = TaggerWorkspaceMode.placing;
      notifyListeners();
      // 실패했다는 것을 뷰 쪽에 에러 팝업으로 알리기 위해 에러를 다시 던질 수 있습니다.
      rethrow;
    }
  }

  /// 템플릿 배치를 취소하고 처음 상태로 돌아갑니다.
  void cancelPlacing() {
    _cancelPlacing();
  }

  void _cancelPlacing() {
    _pendingDraft = null;
    _pendingPosition = null;
    _pendingProgress = null;
    _mode = TaggerWorkspaceMode.ready;
    notifyListeners();
  }

  Future<void> removeTag(String tagId) async {
    try {
      await dataSource.deleteTag(tagId);
      _tags.removeWhere((t) => t.id == tagId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
