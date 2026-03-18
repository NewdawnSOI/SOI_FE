import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:soi_api_client/api.dart';

import '../api_client.dart';
import '../api_exception.dart';
import '../models/notification.dart';

/// 알림 관련 API 래퍼 서비스
///
/// 알림 조회 등 알림 관련 기능을 제공합니다.
/// Provider를 통해 주입받아 사용합니다.
///
/// fields;
/// - [_notificationApi]: OpenAPI로 생성된 NotificationAPIApi 인스턴스
///
/// methods:
/// - [getAllNotifications]
///   - "userId"의 모든 알림을 조회합니다.
///   - 친구 요청 개수와 전체 알림 목록을 반환합니다.
/// - [getFriendNotifications]
///   - "userId"의 친구 요청 관련 알림만 조회합니다.
/// - [getFriendRequestCount]
///   - 모든 알림을 조회하여 친구 요청 개수만 반환하는 편의 메서드입니다.
/// - [getNotificationCount]
///   - 모든 알림을 조회하여 전체 알림 개수만 반환하는 편의 메서드입니다.
/// - [_handleApiException]
///   - [ApiException]을 받아서 HTTP 상태 코드에 따라 적절한 [SoiApiException] 서브클래스로 변환하여 반환합니다.
///   - 네트워크 관련 메시지를 감지하여 [NetworkException]으로 변환하는 로직도 포함합니다.
class NotificationService {
  final NotificationAPIApi _notificationApi;

  NotificationService({NotificationAPIApi? notificationApi})
    : _notificationApi =
          notificationApi ?? SoiApiClient.instance.notificationApi;

  void _validatePagingParams({required int page}) {
    if (page < 0) {
      throw const BadRequestException(message: 'page는 0 이상이어야 합니다.');
    }
  }

  // ============================================
  // 알림 조회
  // ============================================

  /// 모든 알림 조회
  ///
  /// [userId]의 모든 알림을 조회합니다.
  /// 친구 요청 개수와 전체 알림 목록을 반환합니다.
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  ///
  /// Returns:
  /// - [NotificationGetAllResult]: 알림 결과 (친구 요청 개수와 전체 알림 목록)
  ///
  /// Throws:
  /// - [BadRequestException]: 잘못된 요청
  /// - [SoiApiException]: 알림 조회 실패
  Future<NotificationGetAllResult> getAllNotifications({
    required int userId,
    int page = 0,
  }) async {
    try {
      // 파라미터 검증
      _validatePagingParams(page: page);
      final response = await _notificationApi.getAll(page);

      if (response == null) {
        return const NotificationGetAllResult();
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '알림 조회 실패');
      }

      if (response.data == null) {
        return const NotificationGetAllResult();
      }

      return NotificationGetAllResult.fromDto(response.data!);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '알림 조회 실패: $e', originalException: e);
    }
  }

  /// 친구 관련 알림 조회: [userId]의 친구 요청 관련 알림만 조회합니다.
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  /// - [page]: 페이지 번호 (0부터 시작, 기본값: 0)
  ///
  /// Returns:
  /// - [List<AppNotification>]: 친구 관련 알림 목록
  ///
  /// Throws:
  /// - [BadRequestException]: 잘못된 요청
  /// - [SoiApiException]: 알림 조회 실패
  Future<List<AppNotification>> getFriendNotifications({
    required int userId,
    int page = 0,
  }) async {
    try {
      // 파라미터 검증
      _validatePagingParams(page: page);

      // 친구 알림 조회 API 호출
      final response = await _notificationApi.getFriend(page);

      if (response == null) {
        return [];
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '친구 알림 조회 실패');
      }

      return response.data.map((dto) => AppNotification.fromDto(dto)).toList();
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '친구 알림 조회 실패: $e', originalException: e);
    }
  }

  /// 친구 요청 개수 조회 (편의 메서드): 모든 알림을 조회하여 친구 요청 개수만 반환합니다.
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  ///
  /// Returns
  /// - [int]: 친구 요청 개수
  Future<int> getFriendRequestCount({required int userId}) async {
    // 친구 요청 배지는 count만 있으면 되므로, 전체 friend history 순회를 피하고
    // 집계 응답의 friendRequestCount를 재사용합니다.
    final result = await getAllNotifications(userId: userId);
    return result.friendRequestCount;
  }

  /// 알림 개수 조회 (편의 메서드): 모든 알림을 조회하여 전체 알림 개수만 반환합니다.
  ///
  /// parameters:
  /// - [userId]: 사용자 ID
  ///
  /// Returns
  /// - [int]: 전체 알림 개수
  Future<int> getNotificationCount({required int userId}) async {
    final result = await getAllNotifications(userId: userId);
    return result.totalCount;
  }

  // ============================================
  // 에러 핸들링 헬퍼
  // ============================================

  SoiApiException _handleApiException(ApiException e) {
    debugPrint('API Error [${e.code}]: ${e.message}');

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
          message: e.message ?? '알림을 찾을 수 없습니다.',
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
}
