import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../api/media_processing/media_processing_backend.dart';

/// 비디오 썸네일 3-tier 캐시 (Memory → Disk → Generate)
///
/// 메모리 캐시(즉시) → 디스크 캐시(5-50ms) → 비디오에서 생성(500-2000ms)
/// 순서로 조회하여 최적의 성능을 제공합니다.
class VideoThumbnailCache {
  // Tier 1: 메모리 캐시 (LRU)
  static const int _maxEntries = 120;
  static const int _maxBytes = 12 * 1024 * 1024;
  static final LinkedHashMap<String, _MemoryCacheEntry> _memoryCache =
      LinkedHashMap<String, _MemoryCacheEntry>();
  static int _currentBytes = 0;

  // 디스크 캐시 디렉토리 경로 (lazy init)
  static String? _cacheDirPath;
  static final Map<String, Future<Uint8List?>> _inFlightLoads =
      <String, Future<Uint8List?>>{};
  static MediaProcessingBackend _mediaProcessingBackend =
      DefaultMediaProcessingBackend.instance;

  /// 안정적인 캐시 키 생성
  /// postFileKey가 유효하면 이를 사용하고,
  /// 그렇지 않으면 videoUrl에서 쿼리와 프래그먼트를 제거하여 생성
  static String buildStableCacheKey({
    String? fileKey,
    required String videoUrl,
  }) {
    final trimmedFileKey = fileKey?.trim();
    if (trimmedFileKey != null && trimmedFileKey.isNotEmpty) {
      return trimmedFileKey;
    }

    final uri = Uri.tryParse(videoUrl);
    if (uri == null) {
      return videoUrl.split('#').first.split('?').first;
    }

    return uri.replace(query: null, fragment: null).toString();
  }

  /// 메모리 캐시에서 동기적으로 조회 (UI 즉시 반영용)
  static Uint8List? getFromMemory(String cacheKey) {
    final entry = _memoryCache.remove(cacheKey);
    if (entry == null) return null;

    // LRU 갱신: 최근 접근한 키를 뒤로 이동
    _memoryCache[cacheKey] = entry;
    return entry.bytes;
  }

  /// 3-tier 캐시에서 썸네일 조회
  ///
  /// [videoUrl]: 비디오 presigned URL
  /// [cacheKey]: 안정적인 캐시 키 (postFileKey)
  static Future<Uint8List?> getThumbnail({
    required String videoUrl,
    required String cacheKey,
    int maxWidth = 262,
    int quality = 75,
  }) async {
    // Tier 1: 메모리 캐시 (즉시)
    final memHit = getFromMemory(cacheKey);
    if (memHit != null) {
      if (kDebugMode) {
        debugPrint('[VideoThumbnailCache] Memory hit: $cacheKey');
      }
      return memHit;
    }

    final task = _inFlightLoads.putIfAbsent(
      cacheKey,
      () => _loadOrGenerateThumbnail(
        videoUrl: videoUrl,
        cacheKey: cacheKey,
        maxWidth: maxWidth,
        quality: quality,
      ),
    );

    try {
      return await task;
    } finally {
      if (identical(_inFlightLoads[cacheKey], task)) {
        _inFlightLoads.remove(cacheKey);
      }
    }
  }

  /// 디스크 캐시 디렉토리 경로 (lazy init)
  static Future<String> _getCacheDir() async {
    if (_cacheDirPath != null) return _cacheDirPath!;

    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/video_thumbnails');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    _cacheDirPath = cacheDir.path;
    return _cacheDirPath!;
  }

  /// postFileKey를 파일명으로 변환
  static String _sanitizeKey(String key) {
    return '${key.replaceAll('/', '_').replaceAll('\\', '_').replaceAll(':', '_').replaceAll(' ', '_')}.jpg';
  }

  /// 디스크에서 썸네일 로드
  static Future<Uint8List?> _loadFromDisk(String cacheKey) async {
    try {
      final dir = await _getCacheDir();
      final file = File('$dir/${_sanitizeKey(cacheKey)}');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VideoThumbnailCache] Disk read failed: $e');
      }
    }
    return null;
  }

  /// 디스크에 썸네일 저장
  static Future<void> _saveToDisk(String cacheKey, Uint8List bytes) async {
    try {
      final dir = await _getCacheDir();
      final file = File('$dir/${_sanitizeKey(cacheKey)}');
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VideoThumbnailCache] Disk write failed: $e');
      }
    }
  }

  /// 메모리 캐시에 썸네일 추가 및 LRU 갱신, 필요 시 오래된 항목 제거
  ///
  /// Parameters:
  /// - [cacheKey]: 캐시 키 (postFileKey)
  /// - [bytes]: 썸네일 바이트 List
  ///
  /// Returns:
  /// - 없음 (void): 메모리 캐시에 항목을 추가하고, 필요 시 오래된 항목을 제거하여 메모리 사용량을 관리합니다.
  static void _putIntoMemory(String cacheKey, Uint8List bytes) {
    final incomingSize = bytes.lengthInBytes; // 새로 추가하려는 항목의 크기를 바이트로 계산

    // 새로 추가하려는 항목이 최대 허용 크기를 초과하는 경우,
    // 메모리에 추가하지 않고 바로 반환합니다.
    if (incomingSize > _maxBytes) {
      return; // 너무 큰 항목은 메모리에 추가하지 않음
    }

    final previous = _memoryCache.remove(cacheKey); // 기존 항목이 있으면 제거하여 LRU 갱신

    // 기존 항목이 있으면(previous != null),
    if (previous != null) {
      // 현재 메모리 사용량에서 그 크기를 빼줍니다.
      _currentBytes -= previous.sizeBytes;
    }

    //
    _memoryCache[cacheKey] = _MemoryCacheEntry(
      bytes: bytes,
      sizeBytes: incomingSize,
    );

    // 현재 메모리 사용량(_currentBytes)에 새로 추가된 항목(incomingSize)의 크기를 더해줍니다.
    // 이렇게 하면 메모리 캐시에 새 항목이 추가된 후의 총 메모리 사용량이 정확하게 반영됩니다.
    _currentBytes += incomingSize;

    _evictIfNeeded();
  }

  static void _evictIfNeeded() {
    while (_memoryCache.length > _maxEntries || _currentBytes > _maxBytes) {
      if (_memoryCache.isEmpty) break;
      final oldestKey = _memoryCache.keys.first;
      final removed = _memoryCache.remove(oldestKey);
      if (removed == null) break;
      _currentBytes -= removed.sizeBytes;
      if (_currentBytes < 0) {
        _currentBytes = 0;
      }
    }
  }

  /// 디스크 캐시 확인 후, 같은 key의 생성 요청을 하나로 합쳐 썸네일을 가져옵니다.
  /// 디스크에도 없으면 비디오에서 생성하여 캐싱합니다.
  ///
  /// Parameters:
  /// - [videoUrl]: 비디오 presigned URL
  /// - [cacheKey]: 안정적인 캐시 키 (postFileKey)
  /// - [maxWidth]: 생성할 썸네일의 최대 너비 (기본값: 262)
  /// - [quality]: 생성할 썸네일의 품질 (1-100, 기본값: 75)
  ///
  /// Returns:
  /// - [Uint8List?]: 썸네일 바이트 List (캐시에서 로드하거나 새로 생성된 경우)
  /// - [null]: (생성 실패 또는 캐시에도 없는 경우)
  static Future<Uint8List?> _loadOrGenerateThumbnail({
    required String videoUrl,
    required String cacheKey,
    required int maxWidth,
    required int quality,
  }) async {
    final diskHit = await _loadFromDisk(cacheKey); // 디스크 캐시 확인

    // 디스크 캐시가 있으면(diskHit != null)
    if (diskHit != null) {
      // 키를 메모리에 넣어 LRU를 갱신하여 다음 접근 시 메모리에서 바로 반환되도록 합니다.
      _putIntoMemory(cacheKey, diskHit);
      if (kDebugMode) {
        debugPrint('[VideoThumbnailCache] Disk hit: $cacheKey');
      }

      // 디스크에서 로드한 썸네일을 메모리에 넣어 다음 접근 시 메모리에서 바로 반환되도록 합니다.
      return diskHit;
    }

    try {
      final bytes = await _mediaProcessingBackend.generateThumbnailData(
        videoPath: videoUrl,
        format: MediaThumbnailFormat.jpeg,
        maxWidth: maxWidth,
        quality: quality,
      );

      if (bytes != null) {
        _putIntoMemory(cacheKey, bytes);
        unawaited(_saveToDisk(cacheKey, bytes));
        if (kDebugMode) {
          debugPrint('[VideoThumbnailCache] Generated & cached: $cacheKey');
        }
      }
      return bytes;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VideoThumbnailCache] Generation failed: $e');
      }
      return null;
    }
  }

  /// 메모리 캐시와 진행 중 요청을 비워 화면 전환 후 즉시 재사용 상태를 리셋합니다.
  static void clearMemory() {
    // LRU 캐시 초기화
    // LRU 캐시: LinkedHashMap에서 모든 항목을 제거하여 메모리를 해제합니다.
    _memoryCache.clear();
    _currentBytes = 0; // 메모리 사용량 초기화
    _inFlightLoads.clear(); // 진행 중인 요청 초기화
  }

  /// 테스트에서는 공통 백엔드를 교체해 캐시 계약만 독립적으로 검증합니다.
  @visibleForTesting
  static void debugOverrideBackend(MediaProcessingBackend? backend) {
    _mediaProcessingBackend = backend ?? DefaultMediaProcessingBackend.instance;
  }

  /// 테스트에서는 path_provider 없이도 디스크 캐시 경로를 직접 고정할 수 있게 합니다.
  @visibleForTesting
  static void debugPrimeCacheDirectory(String path) {
    _cacheDirPath = path;
  }

  /// 테스트에서는 메모리·디스크 경로와 백엔드를 초기 상태로 되돌립니다.
  @visibleForTesting
  static void debugReset() {
    clearMemory();
    _cacheDirPath = null;
    _mediaProcessingBackend = DefaultMediaProcessingBackend.instance;
  }

  /// 디버그 통계를 노출해 캐시 크기와 메모리 사용량을 빠르게 점검할 수 있게 합니다.
  static Map<String, int> debugStats() {
    return <String, int>{
      'entries': _memoryCache.length,
      'bytes': _currentBytes,
      'maxEntries': _maxEntries,
      'maxBytes': _maxBytes,
    };
  }
}

/// 메모리 LRU 항목 하나가 보유한 바이트와 용량을 함께 보관합니다.
class _MemoryCacheEntry {
  final Uint8List bytes;
  final int sizeBytes;

  const _MemoryCacheEntry({required this.bytes, required this.sizeBytes});
}
