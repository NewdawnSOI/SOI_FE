import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:soi_api_client/api.dart';

import '../api_client.dart';
import '../api_exception.dart';

enum NotificationDevicePlatform { android, ios, web }

/// 디바이스 토큰 관련 API 래퍼 서비스
///
/// 로그인/로그아웃 시점의 FCM 토큰 등록/삭제를 담당합니다.
/// 현재는 앱 전역 상태가 아니라 서비스 레이어에서만 노출합니다.
class NotificationDeviceService {
  final NotificationDeviceAPIApi _notificationDeviceApi;

  NotificationDeviceService({NotificationDeviceAPIApi? notificationDeviceApi})
    : _notificationDeviceApi =
          notificationDeviceApi ?? SoiApiClient.instance.notificationDeviceApi;

  Future<bool> registerToken({
    required String token,
    required NotificationDevicePlatform platform,
  }) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      throw const BadRequestException(message: '디바이스 토큰이 비어 있습니다.');
    }

    try {
      final response = await _notificationDeviceApi.register(
        NotificationRegisterTokenReqDto(
          token: normalizedToken,
          platform: _toPlatformEnum(platform),
        ),
      );

      if (response == null) {
        return false;
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '디바이스 토큰 등록 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '디바이스 토큰 등록 실패: $e', originalException: e);
    }
  }

  Future<bool> deleteToken(String token) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      throw const BadRequestException(message: '디바이스 토큰이 비어 있습니다.');
    }

    try {
      final response = await _notificationDeviceApi.delete(
        NotificationDeleteTokenReqDto(token: normalizedToken),
      );

      if (response == null) {
        return false;
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '디바이스 토큰 삭제 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '디바이스 토큰 삭제 실패: $e', originalException: e);
    }
  }

  NotificationRegisterTokenReqDtoPlatformEnum _toPlatformEnum(
    NotificationDevicePlatform platform,
  ) {
    switch (platform) {
      case NotificationDevicePlatform.android:
        return NotificationRegisterTokenReqDtoPlatformEnum.ANDROID;
      case NotificationDevicePlatform.ios:
        return NotificationRegisterTokenReqDtoPlatformEnum.IOS;
      case NotificationDevicePlatform.web:
        return NotificationRegisterTokenReqDtoPlatformEnum.WEB;
    }
  }

  SoiApiException _handleApiException(ApiException e) {
    debugPrint('DeviceToken API Error [${e.code}]: ${e.message}');

    if (_isTransportFailure(e.message)) {
      return NetworkException(
        message: '네트워크 연결을 확인해주세요.',
        originalException: e,
      );
    }

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
          message: e.message ?? '디바이스 토큰을 찾을 수 없습니다.',
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

  bool _isTransportFailure(String? message) {
    if (message == null) return false;
    final normalized = message.toLowerCase();
    return normalized.contains('socket operation failed') ||
        normalized.contains('tls/ssl communication failed') ||
        normalized.contains('http connection failed') ||
        normalized.contains('i/o operation failed');
  }
}
