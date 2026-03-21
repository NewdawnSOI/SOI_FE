import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/media_service.dart';

/// 미디어 컨트롤러
///
/// 미디어 업로드 관련 UI 상태 관리 및 비즈니스 로직을 담당합니다.
/// MediaService를 내부적으로 사용하며, API 변경 시 Service만 수정하면 됩니다.
///
/// 사용 예시:
/// ```dart
/// final controller = Provider.of<MediaController>(context, listen: false);
///
/// // Presigned URL 발급
/// final urls = await controller.getPresignedUrls(['image1.jpg']);
///
/// // 이미지 업로드
/// final key = await controller.uploadPostImage(
///   file: imageFile,
///   userId: 1,
///   refId: 1,
/// );
/// ```
class MediaController extends ChangeNotifier {
  static const Duration _presignedUrlTtl = Duration(minutes: 55);

  final MediaService _mediaService;
  final DateTime Function() _now;

  bool _isLoading = false;
  String? _errorMessage;
  double? _uploadProgress;
  int _activeRequestCount = 0;

  // presigned URL은 1시간 유효하지만, 매번 새로 발급받으면 URL이 바뀌어
  // 이미지 캐시(CachedNetworkImage)가 새 이미지로 인식 → placeholder(쉬머)가 다시 보일 수 있습니다.
  // 그래서 key -> presignedUrl을 메모리에 캐시해서, 이미 본 이미지는 즉시 렌더링되도록 합니다.
  final Map<String, _PresignedUrlCacheEntry> _presignedUrlCache = {};
  final Map<String, Future<String?>> _inFlightPresignRequests = {};

  // 비디오 파일 키 -> 썸네일 키 매핑 캐시
  // photo_editor에서 비디오 업로드 시 생성한 썸네일 키를 저장하여,
  // category_cover_photo_selector 등에서 재사용할 수 있습니다.
  // LRU 캐시로 구현: 최대 100개까지만 유지하여 메모리 과부하 방지
  final LinkedHashMap<String, String> _videoThumbnailCache = LinkedHashMap();
  static const int _maxThumbnailCacheSize = 100;

  /// 생성자
  ///
  /// [mediaService]를 주입받아 사용합니다. 테스트 시 MockMediaService를 주입할 수 있습니다.
  MediaController({MediaService? mediaService, DateTime Function()? now})
    : _mediaService = mediaService ?? MediaService(),
      _now = now ?? DateTime.now;

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  /// 업로드 진행률 (0.0 ~ 1.0)
  double? get uploadProgress => _uploadProgress;

  // ============================================
  // 비디오 썸네일 캐싱
  // ============================================

  /// 비디오 파일 키에 대한 썸네일 키를 캐시에 저장
  ///
  /// photo_editor에서 비디오 업로드 시 생성한 썸네일 키를 저장합니다.
  /// LRU 방식으로 최대 100개까지만 유지하며, 초과 시 가장 오래된 항목을 제거합니다.
  /// [videoKey] 비디오 파일의 S3 키
  /// [thumbnailKey] 비디오 썸네일 이미지의 S3 키
  void cacheThumbnailForVideo(String videoKey, String thumbnailKey) {
    if (videoKey.isEmpty || thumbnailKey.isEmpty) {
      // 유효하지 않은 키는 무시
      return;
    }

    // 이미 존재하는 키면 제거 후 다시 추가 (LRU 순서 갱신)
    if (_videoThumbnailCache.containsKey(videoKey)) {
      _videoThumbnailCache.remove(videoKey);
    }

    _videoThumbnailCache[videoKey] = thumbnailKey;

    // 캐시 크기가 최대값을 초과하면 가장 오래된 항목(첫 번째 항목) 제거
    if (_videoThumbnailCache.length > _maxThumbnailCacheSize) {
      final oldestKey = _videoThumbnailCache.keys.first;
      _videoThumbnailCache.remove(oldestKey);
    }
  }

  /// 비디오 파일 키에 대한 썸네일 키를 조회
  ///
  /// 캐시에 저장된 썸네일 키를 반환하며, 없으면 null을 반환합니다.
  /// 조회 시 해당 항목을 LRU 순서상 최신으로 갱신합니다.
  /// [videoKey] 비디오 파일의 S3 키
  /// Returns: 썸네일 키 또는 null
  String? getThumbnailForVideo(String videoKey) {
    final thumbnailKey = _videoThumbnailCache[videoKey];
    if (thumbnailKey != null) {
      // LRU 순서 갱신: 제거 후 다시 추가하여 맨 뒤로 이동
      _videoThumbnailCache.remove(videoKey);
      _videoThumbnailCache[videoKey] = thumbnailKey;
    }
    return thumbnailKey;
  }

  /// 비디오 썸네일 캐시 초기화
  void clearVideoThumbnailCache() {
    _videoThumbnailCache.clear();
  }

  // ============================================
  // Presigned URL
  // ============================================

  /// 여러 개의 presigned URL 발급
  ///
  /// Parameters:
  /// - [keys]: 미디어 키 목록
  ///
  /// Returns: presigned URL 목록 (List of String)
  /// - 발급 실패 시 빈 목록 반환
  Future<List<String>> getPresignedUrls(List<String> keys) async {
    if (keys.isEmpty) {
      return const [];
    }

    final cachedUrls = _tryGetCachedPresignedUrls(keys);
    if (cachedUrls != null) {
      return cachedUrls;
    }

    _beginRequest();
    try {
      return await _resolvePresignedUrls(keys);
    } catch (e) {
      _setError('URL 발급 실패: $e');
      return [];
    } finally {
      _endRequest();
    }
  }

  /// 캐시에 있는 presigned URL을 즉시 반환 (없거나 만료면 null)
  ///
  /// Parameters:
  /// - [key]: 미디어 키
  ///
  /// Returns:
  /// - success: presigned URL (캐시에 있고 만료되지 않은 경우)
  /// - fail: null (캐시에 없거나 만료된 경우)
  String? peekPresignedUrl(String key) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return null;

    final entry = _presignedUrlCache[normalizedKey];
    if (entry == null) return null;
    if (entry.isExpired(referenceTime: _now())) {
      _presignedUrlCache.remove(normalizedKey);
      return null;
    }
    return entry.url;
  }

  Future<String?> getPresignedUrl(String key) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return null;
    }

    // 캐시 hit면 네트워크 없이 즉시 반환
    final cached = peekPresignedUrl(normalizedKey);
    if (cached != null) return cached;

    _beginRequest();
    try {
      final urls = await _resolvePresignedUrls([normalizedKey]);
      return urls.isNotEmpty ? urls.first : null;
    } catch (e) {
      _setError('URL 발급 실패: $e');
      return null;
    } finally {
      _endRequest();
    }
  }

  // ============================================
  // 미디어 업로드
  // ============================================

  /// 미디어 파일 업로드
  ///
  /// Parameters:
  /// - [files]: 업로드할 파일 목록 (MultipartFile 형식)
  /// - [types]: 각 파일의 미디어 타입 목록 (MediaType 형식)
  /// - [usageTypes]: 각 파일의 사용 용도 목록 (MediaUsageType 형식)
  /// - [userId]: 업로드하는 사용자 ID
  /// - [refId]: 참조 ID (예: 게시물 ID)
  /// - [usageCount]: 사용 횟수
  ///
  /// Returns: 업로드된 미디어의 키 목록 (List of String)
  /// - 업로드 실패 시 빈 목록 반환
  Future<List<String>> uploadMedia({
    required List<http.MultipartFile> files,
    required List<MediaType> types,
    required List<MediaUsageType> usageTypes,
    required int userId,
    required int refId,
    required int usageCount,
  }) async {
    _beginRequest(uploadProgress: 0.0);

    try {
      final keys = await _mediaService.uploadMedia(
        files: files,
        types: types,
        usageTypes: usageTypes,
        userId: userId,
        refId: refId,
        usageCount: usageCount,
      );
      _setUploadProgress(1.0);
      return keys;
    } catch (e) {
      _setError('파일 업로드 실패: $e');
      return [];
    } finally {
      _endRequest();
    }
  }

  /// 프로필 이미지 업로드
  ///
  /// Parameters:
  /// - [file]: 업로드할 파일 (MultipartFile 형식)
  /// - [userId]: 업로드하는 사용자 ID
  ///
  /// Returns: 업로드된 프로필 이미지의 키 (String)
  /// - 업로드 실패 시 null 반환
  Future<String?> uploadProfileImage({
    required http.MultipartFile file,
    required int userId,
  }) async {
    _beginRequest(uploadProgress: 0.0);

    try {
      final key = await _mediaService.uploadProfileImage(
        file: file,
        userId: userId,
      );
      _setUploadProgress(1.0);
      return key;
    } catch (e) {
      _setError('프로필 이미지 업로드 실패: $e');
      return null;
    } finally {
      _endRequest();
    }
  }

  /// 댓글 오디오 업로드
  ///
  /// Parameters:
  /// - [file]: 업로드할 오디오 파일 (MultipartFile 형식)
  /// - [userId]: 업로드하는 사용자 ID
  /// - [postId]: 댓글이 달릴 게시물 ID
  ///
  /// Returns: 업로드된 오디오의 키 (String)
  /// - 업로드 실패 시 null 반환
  Future<String?> uploadCommentAudio({
    required http.MultipartFile file,
    required int userId,
    required int postId,
  }) async {
    _beginRequest(uploadProgress: 0.0);

    try {
      final key = await _mediaService.uploadCommentAudio(
        file: file,
        userId: userId,
        postId: postId,
      );
      _setUploadProgress(1.0);
      return key;
    } catch (e) {
      _setError('댓글 오디오 업로드 실패: $e');
      return null;
    } finally {
      _endRequest();
    }
  }

  // ============================================
  // 파일 변환 헬퍼
  // ============================================

  Future<http.MultipartFile> fileToMultipart(
    File file, {
    String fieldName = 'files',
  }) async {
    return MediaService.fileToMultipart(file, fieldName: fieldName);
  }

  Future<List<http.MultipartFile>> filesToMultipart(
    List<File> files, {
    String fieldName = 'files',
  }) async {
    return MediaService.filesToMultipart(files, fieldName: fieldName);
  }

  // ============================================
  // 에러 처리
  // ============================================

  void clearError() {
    final changed = _setErrorValue(null);
    _notifyIfChanged(changed);
  }

  List<String>? _tryGetCachedPresignedUrls(List<String> keys) {
    final resolvedUrls = <String>[];

    for (final rawKey in keys) {
      final normalizedKey = rawKey.trim();
      if (normalizedKey.isEmpty) {
        return null;
      }

      final cachedUrl = peekPresignedUrl(normalizedKey);
      if (cachedUrl == null) {
        return null;
      }

      resolvedUrls.add(cachedUrl);
    }

    return List<String>.unmodifiable(resolvedUrls);
  }

  Future<List<String>> _resolvePresignedUrls(List<String> keys) async {
    final resolvedUrls = List<String?>.filled(keys.length, null);
    final pendingCompleters = <String, Completer<String?>>{};
    final pendingKeys = <String>[];
    final futures = <Future<void>>[];

    for (var i = 0; i < keys.length; i++) {
      final normalizedKey = keys[i].trim();
      if (normalizedKey.isEmpty) {
        continue;
      }

      final cachedUrl = peekPresignedUrl(normalizedKey);
      if (cachedUrl != null) {
        resolvedUrls[i] = cachedUrl;
        continue;
      }

      final inFlight = _inFlightPresignRequests[normalizedKey];
      if (inFlight != null) {
        futures.add(
          inFlight.then((url) {
            if (url != null) {
              resolvedUrls[i] = url;
            }
          }),
        );
        continue;
      }

      final completer = pendingCompleters.putIfAbsent(normalizedKey, () {
        final newCompleter = Completer<String?>();
        pendingKeys.add(normalizedKey);
        _inFlightPresignRequests[normalizedKey] = newCompleter.future;
        return newCompleter;
      });

      futures.add(
        completer.future.then((url) {
          if (url != null) {
            resolvedUrls[i] = url;
          }
        }),
      );
    }

    if (pendingKeys.isNotEmpty) {
      futures.add(_loadPendingPresignedUrls(pendingKeys, pendingCompleters));
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    return resolvedUrls.whereType<String>().toList(growable: false);
  }

  Future<void> _loadPendingPresignedUrls(
    List<String> pendingKeys,
    Map<String, Completer<String?>> pendingCompleters,
  ) async {
    try {
      final urls = await _mediaService.getPresignedUrls(pendingKeys);
      for (var i = 0; i < pendingKeys.length; i++) {
        final key = pendingKeys[i];
        final completer = pendingCompleters[key];
        if (completer == null || completer.isCompleted) {
          continue;
        }

        final url = i < urls.length ? urls[i] : null;
        if (url != null) {
          _cachePresignedUrl(key, url);
        }
        completer.complete(url);
      }

      for (final completer in pendingCompleters.values) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
    } catch (e, stackTrace) {
      for (final completer in pendingCompleters.values) {
        if (!completer.isCompleted) {
          completer.completeError(e, stackTrace);
        }
      }
      rethrow;
    } finally {
      for (final key in pendingKeys) {
        final registeredTask = _inFlightPresignRequests[key];
        final completer = pendingCompleters[key];
        if (registeredTask != null &&
            completer != null &&
            identical(registeredTask, completer.future)) {
          _inFlightPresignRequests.remove(key);
        }
      }
    }
  }

  void _cachePresignedUrl(String key, String url) {
    _presignedUrlCache[key] = _PresignedUrlCacheEntry(
      url: url,
      expiresAt: _now().add(_presignedUrlTtl),
    );
  }

  void _notifyIfChanged(bool changed) {
    if (changed) {
      notifyListeners();
    }
  }

  bool _setLoadingValue(bool value) {
    if (_isLoading == value) return false;
    _isLoading = value;
    return true;
  }

  bool _setErrorValue(String? message) {
    if (_errorMessage == message) return false;
    _errorMessage = message;
    return true;
  }

  bool _setUploadProgressValue(double? value) {
    if (_uploadProgress == value) return false;
    _uploadProgress = value;
    return true;
  }

  void _beginRequest({double? uploadProgress}) {
    var changed = _setErrorValue(null);
    _activeRequestCount += 1;
    changed = _setLoadingValue(true) || changed;
    if (uploadProgress != null) {
      changed = _setUploadProgressValue(uploadProgress) || changed;
    }
    _notifyIfChanged(changed);
  }

  void _endRequest() {
    if (_activeRequestCount > 0) {
      _activeRequestCount -= 1;
    }

    final changed = _setLoadingValue(_activeRequestCount > 0);
    _notifyIfChanged(changed);
  }

  void _setError(String message) {
    final changed = _setErrorValue(message);
    _notifyIfChanged(changed);
  }

  void _setUploadProgress(double? value) {
    final changed = _setUploadProgressValue(value);
    _notifyIfChanged(changed);
  }
}

/// Presigned URL 캐시 엔트리
/// Presigned URL과 만료 시각을 함께 저장합니다.
///
/// Parameters:
/// - [ url ]: presigned URL
/// - [ expiresAt ]: 만료 시각
class _PresignedUrlCacheEntry {
  final String url;
  final DateTime expiresAt;

  const _PresignedUrlCacheEntry({required this.url, required this.expiresAt});

  bool isExpired({required DateTime referenceTime}) {
    return referenceTime.isAfter(expiresAt);
  }
}
