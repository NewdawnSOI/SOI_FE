import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:soi_api_client/api.dart';

import '../api_client.dart';
import '../api_exception.dart';

/// 디바이스 종류를 식별하기 위한 열거형입니다.
/// 각 플랫폼에 맞는 FCM 토큰 등록을 위해 사용됩니다.
enum NotificationDevicePlatform { android, ios, web }

class NotificationDeviceService {
  /// OpenAPI로 생성된 NotificationDeviceAPIApi 인스턴스
  /// 기본적으로 SoiApiClient의 notificationDeviceApi를 사용
  final NotificationDeviceAPIApi _notificationDeviceApi;

  // ==========================Class에 대한 설명======================================================
  /// 디바이스 토큰 관련 API 래퍼 서비스입니다.
  /// 로그인/로그아웃 시점의 FCM 토큰 등록/삭제를 담당합니다.
  ///
  /// parameters:
  /// - [_notificationDeviceApi]: OpenAPI로 생성된 NotificationDeviceAPIApi 인스턴스
  ///
  /// methods:
  /// - [registerToken]
  ///   - FCM 토큰을 서버에 등록하는 메소드
  ///   - 토큰이 비어 있거나 공백만 있는 경우 BadRequestException을 던집니다.
  ///   - API 호출 중 ApiException이 발생하면 HTTP 상태 코드에 따라 적절한 SoiApiException 서브클래스로 변환하여 던집니다.
  ///   - 네트워크 관련 메시지를 감지하여 NetworkException으로 변환하는 로직도 포함합니다.
  /// - [deleteToken]
  ///   - FCM 토큰을 서버에서 삭제하는 메소드
  ///   - 토큰이 비어 있거나 공백만 있는 경우 BadRequestException을 던집니다.
  ///   - API 호출 중 ApiException이 발생하면 HTTP 상태 코드에 따라 적절한 SoiApiException 서브클래스로 변환하여 던집니다.
  ///   - 네트워크 관련 메시지를 감지하여 NetworkException으로 변환하는 로직도 포함합니다.
  /// - [_toPlatformEnum]: NotificationDevicePlatform을 OpenAPI에서 사용하는 Enum으로 변환합니다.
  /// - [_handleApiException]
  ///   - ApiException을 받아서 HTTP 상태 코드에 따라 적절한 SoiApiException 서브클래스로 변환하여 반환합니다.
  ///   - 네트워크 관련 메시지를 감지하여 NetworkException으로 변환하는 로직도 포함합니다.
  /// - [_isTransportFailure]: ApiException 메시지를 분석하여 네트워크 연결 실패와 관련된 메시지가 포함되어 있는지 확인하는 헬퍼 메서드입니다.
  // ===========================Class에 대한 설명==================================================================================

  NotificationDeviceService({NotificationDeviceAPIApi? notificationDeviceApi})
    : _notificationDeviceApi =
          notificationDeviceApi ?? SoiApiClient.instance.notificationDeviceApi;

  /// FCM 토큰을 **서버에 등록**하는 메서드입니다.
  ///
  /// parameters:
  /// - [token]: 등록할 FCM 토큰 문자열
  /// - [platform]: 디바이스 플랫폼 (android, ios, web)
  ///
  /// 예외처리:
  /// - 토큰이 비어 있거나 공백만 있는 경우 [BadRequestException]을 던집니다.
  /// - API 호출 중 [ApiException]이 발생하면 HTTP 상태 코드에 따라 적절한 [SoiApiException] 서브클래스로 변환하여 던집니다.
  /// - 네트워크 관련 메시지를 감지하여 [NetworkException]으로 변환하는 로직도 포함합니다.
  Future<bool> registerToken({
    required String token,
    required NotificationDevicePlatform platform,
  }) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      throw const BadRequestException(message: '디바이스 토큰이 비어 있습니다.');
    }

    try {
      // fcm토큰을 등록하기 위해서 register API를 호출합니다.
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

  /// FCM 토큰을 **서버에서 삭제**하는 메서드입니다.
  ///
  /// parameters:
  /// - [token]: 삭제할 FCM 토큰 문자열
  ///
  /// 예외처리:
  /// - 토큰이 비어 있거나 공백만 있는 경우 [BadRequestException]을 던집니다.
  /// - API 호출 중 [ApiException]이 발생하면 HTTP 상태 코드에 따라 적절한 [SoiApiException] 서브클래스로 변환하여 던집니다.
  /// - 네트워크 관련 메시지를 감지하여 [NetworkException]으로 변환하는 로직도 포함합니다.
  Future<bool> deleteToken(String token) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      throw const BadRequestException(message: '디바이스 토큰이 비어 있습니다.');
    }

    try {
      // fcm토큰을 삭제하기 위해서 delete API를 호출합니다.
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

  /// NotificationDevicePlatform을 OpenAPI에서 사용하는 Enum으로 변환합니다.
  /// 각 플랫폼에 맞는 FCM 토큰 등록을 위해 사용됩니다.
  ///
  /// parameters:
  /// - [platform]: NotificationDevicePlatform 열거형 값 (android, ios, web)
  ///
  /// returns:
  /// - OpenAPI에서 사용하는 [NotificationRegisterTokenReqDtoPlatformEnum] 열거형 값
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

  /// ApiException을 받아서 HTTP 상태 코드에 따라 적절한 SoiApiException 서브클래스로 변환하여 반환합니다.
  /// 네트워크 관련 메시지를 감지하여 NetworkException으로 변환하는 로직도 포함합니다.
  ///
  /// parameters:
  /// - [e]: API 호출 중 발생한 ApiException 인스턴스
  ///
  /// returns:
  /// - HTTP 상태 코드에 따라 변환된 [SoiApiException] 서브클래스 인스턴스
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

  /// ApiException 메시지를 분석하여 네트워크 연결 실패와 관련된 메시지가 포함되어 있는지 확인하는 헬퍼 메서드입니다.
  /// 네트워크 연결 실패와 관련된 메시지가 포함되어 있으면 true를 반환하고, 그렇지 않으면 false를 반환합니다.
  ///
  /// parameters:
  /// - [message]: ApiException의 메시지 문자열
  ///
  /// returns:
  /// - 네트워크 연결 실패와 관련된 메시지가 포함되어 있으면 true, 그렇지 않으면 false
  bool _isTransportFailure(String? message) {
    if (message == null) return false;
    final normalized = message.toLowerCase();
    return normalized.contains('socket operation failed') ||
        normalized.contains('tls/ssl communication failed') ||
        normalized.contains('http connection failed') ||
        normalized.contains('i/o operation failed');
  }
}
