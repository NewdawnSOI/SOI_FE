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
/// 사용 예시:
/// ```dart
/// final notificationService = Provider.of<NotificationService>(context, listen: false);
///
/// // 모든 알림 조회
/// final result = await notificationService.getAllNotifications(userId: 1);
/// print('친구 요청: ${result.friendRequestCount}개');
/// print('알림: ${result.notifications.length}개');
///
/// // 친구 관련 알림만 조회
/// final friendNotifications = await notificationService.getFriendNotifications(userId: 1);
/// ```
class NotificationService {
  final NotificationAPIApi _notificationApi;

  NotificationService({NotificationAPIApi? notificationApi})
    : _notificationApi =
          notificationApi ?? SoiApiClient.instance.notificationApi;

  void _validatePagingParams({required int userId, required int page}) {
    if (userId <= 0) {
      throw const BadRequestException(message: 'userId는 1 이상이어야 합니다.');
    }
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
  /// Returns: 알림 결과 (NotificationGetAllResult)
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
      _validatePagingParams(userId: userId, page: page);
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

  /// 친구 관련 알림 조회
  ///
  /// [userId]의 친구 요청 관련 알림만 조회합니다.
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  ///
  /// Returns: 친구 관련 알림 목록 (List<AppNotification>)
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
      _validatePagingParams(userId: userId, page: page);
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

  /// 친구 요청 개수 조회 (편의 메서드)
  ///
  /// 모든 알림을 조회하여 친구 요청 개수만 반환합니다.
  ///
  /// Returns: 친구 요청 개수
  Future<int> getFriendRequestCount({required int userId}) async {
    final result = await getAllNotifications(userId: userId);
    return result.friendRequestCount;
  }

  /// 알림 개수 조회 (편의 메서드)
  ///
  /// 모든 알림을 조회하여 전체 알림 개수만 반환합니다.
  ///
  /// Returns: 전체 알림 개수
  Future<int> getNotificationCount({required int userId}) async {
    final result = await getAllNotifications(userId: userId);
    return result.totalCount;
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
