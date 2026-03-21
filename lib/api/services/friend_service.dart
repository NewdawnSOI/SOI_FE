import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:soi_api_client/api.dart';

import '../api_client.dart';
import '../api_exception.dart';
import '../models/models.dart';

/// 친구 관련 API 래퍼 서비스
///
/// 친구 추가, 조회, 차단, 삭제 등 친구 관련 기능을 제공합니다.
/// Provider를 통해 주입받아 사용합니다.
///
/// 사용 예시:
/// ```
/// final friendService = Provider.of<FriendService>(context, listen: false);
///
/// // 친구 추가
/// final friend = await friendService.addFriend(
///   requesterId: 1,
///   receiverPhoneNum: '01012345678',
/// );
///
/// // 친구 목록 조회
/// final friends = await friendService.getAllFriends(userId: 1);
///
/// // 연락처 친구 확인
/// final relations = await friendService.checkFriendRelations(
///   userId: 1,
///   phoneNumbers: ['01012345678', '01087654321'],
/// );
/// ```
class FriendService {
  static const Duration _friendListCacheTtl = Duration(seconds: 30);
  static const Duration _friendRelationCacheTtl = Duration(seconds: 30);

  final FriendAPIApi _friendApi;

  /// 시간 제공 함수 (테스트 용이성 위해 주입)
  final DateTime Function() _now;

  /// 친구 목록 캐시: 'userId|status' -> 친구 목록 및 캐시 시간
  final Map<String, _FriendListCacheEntry> _friendListCache =
      <String, _FriendListCacheEntry>{};

  final Map<String, Future<List<User>>> _inFlightFriendListRequests =
      <String, Future<List<User>>>{};
  final Map<int, Map<String, _FriendRelationCacheEntry>> _friendRelationCache =
      <int, Map<String, _FriendRelationCacheEntry>>{};
  final Map<String, Future<Map<String, FriendCheck>>>
  _inFlightRelationRequests = <String, Future<Map<String, FriendCheck>>>{};

  FriendService({FriendAPIApi? friendApi, DateTime Function()? now})
    : _friendApi = friendApi ?? SoiApiClient.instance.friendApi,
      _now = now ?? DateTime.now;

  // ============================================
  // 친구 추가
  // ============================================

  /// 친구 추가 요청
  ///
  /// [requesterId]가 [receiverId]에게 친구 추가 요청을 보냅니다.
  ///
  /// Parameters:
  /// - [requesterId]: 요청자 ID
  /// - [receiverId]: 대상 사용자 ID
  ///
  /// Returns: 생성된 친구 관계 정보 (Friend)
  ///
  /// Throws:
  /// - [BadRequestException]: 이미 친구이거나 본인에게 요청
  /// - [NotFoundException]: 대상 사용자를 찾을 수 없음
  Future<Friend> addFriend({
    required int requesterId,
    required String receiverPhoneNum,
  }) async {
    try {
      final dto = FriendCreateReqDto(
        requesterId: requesterId,
        receiverPhoneNum: receiverPhoneNum,
      );

      final response = await _friendApi.create2(dto);

      if (response == null) {
        throw const DataValidationException(message: '친구 추가 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '친구 추가 실패');
      }

      if (response.data == null) {
        throw const DataValidationException(message: '친구 관계 정보가 없습니다.');
      }

      return Friend.fromDto(response.data!);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '친구 추가 실패: $e', originalException: e);
    }
  }

  /// 닉네임으로 친구 추가 요청
  ///
  /// [requesterId]가 [receiverNickName]에게 친구 추가 요청을 보냅니다.
  ///
  /// Parameters:
  /// - [requesterId]: 요청자 ID
  /// - [receiverNickName]: 대상 사용자 닉네임
  ///
  /// Returns: 생성된 친구 관계 정보 (Friend)
  ///
  /// Throws:
  /// - [BadRequestException]: 이미 친구이거나 본인에게 요청
  /// - [NotFoundException]: 대상 사용자를 찾을 수 없음
  Future<Friend> addFriendByNickName({
    required int requesterId,
    required String receiverNickName,
  }) async {
    try {
      final dto = FriendCreateByNickNameReqDto(
        requesterId: requesterId,
        receiverNickName: receiverNickName,
      );

      final response = await _friendApi.createByNickName(dto);

      if (response == null) {
        throw const DataValidationException(message: '친구 추가 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '친구 추가 실패');
      }

      if (response.data == null) {
        throw const DataValidationException(message: '친구 관계 정보가 없습니다.');
      }

      return Friend.fromDto(response.data!);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '친구 추가 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 친구 조회
  // ============================================

  /// 모든 친구 목록 조회
  ///
  /// [userId]의 모든 친구 목록을 조회합니다.
  ///
  /// Returns: 친구 목록 (`List<User>`)
  Future<List<User>> getAllFriends({
    required int userId,
    FriendStatus status = FriendStatus.accepted,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _friendListCacheKey(userId, status);
    final cachedEntry = _friendListCache[cacheKey];
    if (!forceRefresh &&
        cachedEntry != null &&
        !cachedEntry.isExpired(referenceTime: _now())) {
      return cachedEntry.users;
    }

    final inFlightRequest = _inFlightFriendListRequests[cacheKey];
    if (inFlightRequest != null) {
      return inFlightRequest;
    }

    final request = _fetchFriendList(status: status, cacheKey: cacheKey);
    _inFlightFriendListRequests[cacheKey] = request;

    try {
      return await request;
    } finally {
      final registeredRequest = _inFlightFriendListRequests[cacheKey];
      if (identical(registeredRequest, request)) {
        _inFlightFriendListRequests.remove(cacheKey);
      }
    }
  }

  /// 연락처 친구 관계 확인
  ///
  /// [phoneNumbers] 목록에 해당하는 사용자들과의 친구 관계를 확인합니다.
  /// 연락처 기반 친구 찾기에 사용됩니다.
  ///
  /// Parameters:
  /// - [userId]: 요청 사용자 ID
  /// - [phoneNumbers]: 확인할 전화번호 목록
  ///
  /// Returns: 친구 관계 정보 목록 (`List<FriendCheck>`)
  Future<List<FriendCheck>> checkFriendRelations({
    required int userId,
    required List<String> phoneNumbers,
    bool forceRefresh = false,
  }) async {
    final normalizedPhoneNumbers = _normalizePhoneNumbers(phoneNumbers);
    if (normalizedPhoneNumbers.isEmpty) {
      return const <FriendCheck>[];
    }

    final relationCache = _friendRelationCache.putIfAbsent(
      userId,
      () => <String, _FriendRelationCacheEntry>{},
    );
    final resolvedRelations = <String, FriendCheck>{};
    final missingPhoneNumbers = <String>[];

    for (final phoneNumber in normalizedPhoneNumbers) {
      final cachedEntry = relationCache[phoneNumber];
      final isFresh =
          cachedEntry != null &&
          !cachedEntry.isExpired(referenceTime: _now()) &&
          !forceRefresh;

      if (isFresh) {
        resolvedRelations[phoneNumber] = cachedEntry.relation;
      } else {
        missingPhoneNumbers.add(phoneNumber);
      }
    }

    if (missingPhoneNumbers.isNotEmpty) {
      final requestKey = _friendRelationRequestKey(userId, missingPhoneNumbers);
      final inFlightRequest = _inFlightRelationRequests[requestKey];
      final request =
          inFlightRequest ??
          _fetchFriendRelations(
            phoneNumbers: missingPhoneNumbers,
            relationCache: relationCache,
          );
      if (inFlightRequest == null) {
        _inFlightRelationRequests[requestKey] = request;
      }

      try {
        final fetchedRelations = await request;
        resolvedRelations.addAll(fetchedRelations);
      } finally {
        final registeredRequest = _inFlightRelationRequests[requestKey];
        if (identical(registeredRequest, request)) {
          _inFlightRelationRequests.remove(requestKey);
        }
      }
    }

    return List<FriendCheck>.unmodifiable(
      normalizedPhoneNumbers.map(
        (phoneNumber) =>
            resolvedRelations[phoneNumber] ?? _noneFriendCheck(phoneNumber),
      ),
    );
  }

  List<User>? peekCachedFriends({
    required int userId,
    FriendStatus status = FriendStatus.accepted,
  }) {
    return _friendListCache[_friendListCacheKey(userId, status)]?.users;
  }

  bool hasFreshFriendsCache({
    required int userId,
    FriendStatus status = FriendStatus.accepted,
  }) {
    final cachedEntry = _friendListCache[_friendListCacheKey(userId, status)];
    return cachedEntry != null && !cachedEntry.isExpired(referenceTime: _now());
  }

  void invalidateFriendListCache({int? userId, FriendStatus? status}) {
    if (userId == null && status == null) {
      _friendListCache.clear();
      return;
    }

    if (userId != null && status != null) {
      _friendListCache.remove(_friendListCacheKey(userId, status));
      return;
    }

    if (userId != null) {
      final cacheKeyPrefix = '$userId|';
      _friendListCache.removeWhere(
        (cacheKey, _) => cacheKey.startsWith(cacheKeyPrefix),
      );
      return;
    }

    final statusSuffix = '|${status!.name}';
    _friendListCache.removeWhere(
      (cacheKey, _) => cacheKey.endsWith(statusSuffix),
    );
  }

  void invalidateRelationCache({int? userId, Iterable<String>? phoneNumbers}) {
    if (userId == null) {
      _friendRelationCache.clear();
      return;
    }

    final relationCache = _friendRelationCache[userId];
    if (relationCache == null) {
      return;
    }

    if (phoneNumbers == null) {
      _friendRelationCache.remove(userId);
      return;
    }

    final normalizedPhoneNumbers = _normalizePhoneNumbers(phoneNumbers);
    for (final phoneNumber in normalizedPhoneNumbers) {
      relationCache.remove(phoneNumber);
    }

    if (relationCache.isEmpty) {
      _friendRelationCache.remove(userId);
    }
  }

  // ============================================
  // 친구 차단
  // ============================================

  /// 친구 차단
  ///
  /// [requesterId]가 [receiverId]를 차단합니다.
  ///
  /// Returns: 차단 성공 여부
  Future<bool> blockFriend({
    required int requesterId,
    required int receiverId,
  }) async {
    try {
      final dto = FriendReqDto(
        requesterId: requesterId,
        receiverId: receiverId,
      );

      final response = await _friendApi.blockFriend(dto);

      if (response == null) {
        throw const DataValidationException(message: '차단 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '친구 차단 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '친구 차단 실패: $e', originalException: e);
    }
  }

  /// 친구 차단 해제
  ///
  /// [requesterId]가 [receiverId]의 차단을 해제합니다.
  /// 차단 해제 후 친구 관계는 완전히 초기화됩니다.
  ///
  /// Returns: 차단 해제 성공 여부
  Future<bool> unblockFriend({
    required int requesterId,
    required int receiverId,
  }) async {
    try {
      final dto = FriendReqDto(
        requesterId: requesterId,
        receiverId: receiverId,
      );

      final response = await _friendApi.unBlockFriend(dto);

      if (response == null) {
        throw const DataValidationException(message: '차단 해제 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '차단 해제 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '차단 해제 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 친구 삭제
  // ============================================

  /// 친구 삭제
  ///
  /// [requesterId]가 [receiverId]를 친구에서 삭제합니다.
  /// 서로 모두 삭제한 경우 친구 관계 자체가 삭제됩니다.
  ///
  /// Returns: 삭제 성공 여부
  Future<bool> deleteFriend({
    required int requesterId,
    required int receiverId,
  }) async {
    try {
      final dto = FriendReqDto(
        requesterId: requesterId,
        receiverId: receiverId,
      );

      final response = await _friendApi.deleteFriend(dto);

      if (response == null) {
        throw const DataValidationException(message: '삭제 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '친구 삭제 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '친구 삭제 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 친구 상태 업데이트
  // ============================================

  /// 친구 관계 상태 업데이트
  ///
  /// 친구 관계의 상태를 변경합니다.
  ///
  /// Parameters:
  /// - [friendId]: 친구 관계 ID
  /// - [status]: 변경할 상태 (ACCEPTED, BLOCKED, CANCELLED)
  ///
  /// Returns: 업데이트된 친구 관계 정보 (FriendRespDto)
  Future<FriendRespDto> updateFriendStatus({
    required int friendId,
    required FriendStatus status,
    int notificationId = 0,
  }) async {
    try {
      final dto = FriendUpdateRespDto(
        id: friendId,
        status: _toFriendStatusEnum(status),
        notificationId: notificationId == 0 ? null : notificationId,
      );

      final response = await _friendApi.update(dto);

      if (response == null) {
        throw const DataValidationException(message: '상태 업데이트 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '친구 상태 업데이트 실패');
      }

      if (response.data == null) {
        throw const DataValidationException(message: '업데이트된 친구 정보가 없습니다.');
      }

      return response.data!;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '친구 상태 업데이트 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 에러 핸들링 헬퍼
  // ============================================

  SoiApiException _handleApiException(ApiException e) {
    debugPrint('🔴 API Error [${e.code}]: ${e.message}');

    switch (e.code) {
      case 400:
        return BadRequestException(
          message: e.message ?? '잘못된 요청입니다.',
          originalException: e,
        );
      case 401:
        return AuthException(
          message: e.message ?? '인증이 필요합니다.',
          originalException: e,
        );
      case 403:
        return ForbiddenException(
          message: e.message ?? '접근 권한이 없습니다.',
          originalException: e,
        );
      case 404:
        return NotFoundException(
          message: e.message ?? '사용자를 찾을 수 없습니다.',
          originalException: e,
        );
      case >= 500:
        return ServerException(
          statusCode: e.code,
          message: e.message ?? '서버 오류가 발생했습니다.',
          originalException: e,
        );
      default:
        return SoiApiException(
          statusCode: e.code,
          message: e.message ?? '알 수 없는 오류가 발생했습니다.',
          originalException: e,
        );
    }
  }

  Future<List<User>> _fetchFriendList({
    required FriendStatus status,
    required String cacheKey,
  }) async {
    try {
      final response = await _friendApi.getAllFriend(
        _mapStatusToQueryParam(status),
      );

      if (response == null) {
        const users = <User>[];
        _friendListCache[cacheKey] = _FriendListCacheEntry(
          users: users,
          cachedAt: _now(),
        );
        return users;
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '친구 목록 조회 실패');
      }

      final users = List<User>.unmodifiable(
        response.data.map((dto) => User.fromFindDto(dto)),
      );
      _friendListCache[cacheKey] = _FriendListCacheEntry(
        users: users,
        cachedAt: _now(),
      );
      return users;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '친구 목록 조회 실패: $e', originalException: e);
    }
  }

  Future<Map<String, FriendCheck>> _fetchFriendRelations({
    required List<String> phoneNumbers,
    required Map<String, _FriendRelationCacheEntry> relationCache,
  }) async {
    try {
      final response = await _friendApi.getAllFriend1(phoneNumbers);

      if (response != null && response.success != true) {
        throw SoiApiException(message: response.message ?? '친구 관계 확인 실패');
      }

      final fetchedRelations = <String, FriendCheck>{};
      for (final dto in response?.data ?? const <FriendCheckRespDto>[]) {
        final relation = FriendCheck.fromDto(dto);
        final normalizedPhoneNumber = _normalizePhoneNumber(
          relation.phoneNumber,
        );
        if (normalizedPhoneNumber.isEmpty) {
          continue;
        }

        fetchedRelations[normalizedPhoneNumber] = FriendCheck(
          phoneNumber: normalizedPhoneNumber,
          isFriend: relation.isFriend,
          status: relation.status,
        );
      }

      final cachedAt = _now();
      for (final phoneNumber in phoneNumbers) {
        final relation =
            fetchedRelations[phoneNumber] ?? _noneFriendCheck(phoneNumber);
        relationCache[phoneNumber] = _FriendRelationCacheEntry(
          relation: relation,
          cachedAt: cachedAt,
        );
        fetchedRelations.putIfAbsent(phoneNumber, () => relation);
      }

      return Map<String, FriendCheck>.unmodifiable(fetchedRelations);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '친구 관계 확인 실패: $e', originalException: e);
    }
  }

  String _friendListCacheKey(int userId, FriendStatus status) {
    return '$userId|${status.name}';
  }

  String _friendRelationRequestKey(int userId, List<String> phoneNumbers) {
    return '$userId|${phoneNumbers.join(',')}';
  }

  List<String> _normalizePhoneNumbers(Iterable<String> phoneNumbers) {
    final normalizedPhoneNumbers = <String>[];
    final seenPhoneNumbers = <String>{};

    for (final phoneNumber in phoneNumbers) {
      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);
      if (normalizedPhoneNumber.isEmpty ||
          !seenPhoneNumbers.add(normalizedPhoneNumber)) {
        continue;
      }
      normalizedPhoneNumbers.add(normalizedPhoneNumber);
    }

    return normalizedPhoneNumbers;
  }

  String _normalizePhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  FriendCheck _noneFriendCheck(String phoneNumber) {
    return FriendCheck(
      phoneNumber: phoneNumber,
      isFriend: false,
      status: FriendStatus.none,
    );
  }

  /// FriendStatus를 API enum으로 변환
  FriendUpdateRespDtoStatusEnum? _toFriendStatusEnum(FriendStatus status) {
    switch (status) {
      case FriendStatus.pending:
        return FriendUpdateRespDtoStatusEnum.PENDING;
      case FriendStatus.accepted:
        return FriendUpdateRespDtoStatusEnum.ACCEPTED;
      case FriendStatus.blocked:
        return FriendUpdateRespDtoStatusEnum.BLOCKED;
      case FriendStatus.cancelled:
        return FriendUpdateRespDtoStatusEnum.CANCELLED;
      case FriendStatus.none:
        return null;
    }
  }

  String _mapStatusToQueryParam(FriendStatus status) {
    switch (status) {
      case FriendStatus.pending:
        return 'PENDING';
      case FriendStatus.accepted:
        return 'ACCEPTED';
      case FriendStatus.blocked:
        return 'BLOCKED';
      case FriendStatus.cancelled:
        return 'CANCELLED';
      case FriendStatus.none:
        return 'NONE';
    }
  }
}

class _FriendListCacheEntry {
  const _FriendListCacheEntry({required this.users, required this.cachedAt});

  final List<User> users;
  final DateTime cachedAt;

  bool isExpired({required DateTime referenceTime}) {
    return referenceTime.difference(cachedAt) >=
        FriendService._friendListCacheTtl;
  }
}

class _FriendRelationCacheEntry {
  const _FriendRelationCacheEntry({
    required this.relation,
    required this.cachedAt,
  });

  final FriendCheck relation;
  final DateTime cachedAt;

  bool isExpired({required DateTime referenceTime}) {
    return referenceTime.difference(cachedAt) >=
        FriendService._friendRelationCacheTtl;
  }
}
