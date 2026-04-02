import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:soi/api/api_exception.dart';

/// Firebase Auth 기반의 임시 전화번호 인증 상태를 보관하고 SMS 검증을 수행합니다.
class FirebasePhoneVerificationService {
  FirebasePhoneVerificationService();

  static const Duration _verificationTimeout = Duration(seconds: 60);
  static const Duration _callbackTimeout = Duration(seconds: 70);

  String? _pendingPhoneNumber;
  String? _verificationId;
  int? _resendToken;
  bool _isCurrentPhoneVerified = false;

  /// 현재 대기 중인 전화번호가 이미 인증되었는지 화면 흐름에서 조회합니다.
  bool get isCurrentPhoneVerified => _isCurrentPhoneVerified;

  /// 실제 인증 시점에 FirebaseAuth 인스턴스를 읽어 앱 초기화 순서와 결합을 최소화합니다.
  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;

  /// Firebase SMS 인증 발송을 시작하고 codeSent 또는 즉시 인증 완료를 기다립니다.
  Future<bool> sendVerificationCode(String phoneNumber) async {
    _ensureSupportedPlatform();

    final normalizedPhoneNumber = phoneNumber.trim();
    if (normalizedPhoneNumber.isEmpty) {
      throw const BadRequestException(message: '전화번호를 입력해주세요.');
    }

    _preparePendingVerification(normalizedPhoneNumber);

    final completer = Completer<bool>();

    try {
      if (kDebugMode) {
        debugPrint(
          '[FirebasePhoneVerificationService] verifyPhoneNumber start phone=$normalizedPhoneNumber, resendToken=$_resendToken',
        );
      }

      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: normalizedPhoneNumber,
        timeout: _verificationTimeout,
        forceResendingToken: _resendToken,
        verificationCompleted: (credential) async {
          if (kDebugMode) {
            debugPrint(
              '[FirebasePhoneVerificationService] verificationCompleted phone=$normalizedPhoneNumber',
            );
          }
          _isCurrentPhoneVerified = true;
          if (!completer.isCompleted) {
            completer.complete(true);
          }

          try {
            await _firebaseAuth.signInWithCredential(credential);
          } on FirebaseAuthException catch (error) {
            if (kDebugMode) {
              debugPrint(
                'Firebase phone auto-verification sign-in skipped: $error',
              );
            }
          } finally {
            await _safeSignOut();
          }
        },
        verificationFailed: (exception) {
          if (kDebugMode) {
            debugPrint(
              '[FirebasePhoneVerificationService] verificationFailed code=${exception.code}, message=${exception.message}',
            );
          }
          if (!completer.isCompleted) {
            completer.completeError(_mapFirebaseAuthException(exception));
          }
        },
        codeSent: (verificationId, resendToken) {
          if (kDebugMode) {
            debugPrint(
              '[FirebasePhoneVerificationService] codeSent verificationId=${verificationId.isNotEmpty}, resendToken=$resendToken',
            );
          }
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (kDebugMode) {
            debugPrint(
              '[FirebasePhoneVerificationService] codeAutoRetrievalTimeout verificationId=${verificationId.isNotEmpty}',
            );
          }
          _verificationId = verificationId;
        },
      );

      return await completer.future.timeout(
        _callbackTimeout,
        onTimeout: () {
          throw const SoiApiException(
            message: '인증번호 발송 시간이 초과되었습니다. 다시 시도해주세요.',
          );
        },
      );
    } on SoiApiException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    } catch (error) {
      throw SoiApiException(
        message: 'SMS 인증 발송 실패: $error',
        originalException: error,
      );
    }
  }

  /// 직전에 발급된 verificationId와 사용자가 입력한 코드를 조합해 Firebase 검증을 완료합니다.
  Future<bool> verifyCode(String phoneNumber, String smsCode) async {
    _ensureSupportedPlatform();

    final normalizedPhoneNumber = phoneNumber.trim();
    final normalizedCode = smsCode.trim();

    if (normalizedPhoneNumber.isEmpty) {
      throw const BadRequestException(message: '전화번호를 입력해주세요.');
    }
    if (normalizedCode.isEmpty) {
      throw const BadRequestException(message: '인증번호를 입력해주세요.');
    }

    if (_isCurrentPhoneVerified &&
        _pendingPhoneNumber == normalizedPhoneNumber) {
      return true;
    }

    final verificationId = _verificationId;
    if (_pendingPhoneNumber != normalizedPhoneNumber ||
        verificationId == null) {
      throw const BadRequestException(message: '먼저 인증번호를 요청해주세요.');
    }

    try {
      if (kDebugMode) {
        debugPrint(
          '[FirebasePhoneVerificationService] verifyCode start phone=$normalizedPhoneNumber, hasVerificationId=${verificationId.isNotEmpty}',
        );
      }
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: normalizedCode,
      );
      await _firebaseAuth.signInWithCredential(credential);
      _isCurrentPhoneVerified = true;
      return true;
    } on FirebaseAuthException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[FirebasePhoneVerificationService] verifyCode failed code=${error.code}, message=${error.message}',
        );
      }
      if (error.code == 'invalid-verification-code' ||
          error.code == 'session-expired') {
        _isCurrentPhoneVerified = false;
        return false;
      }
      throw _mapFirebaseAuthException(error);
    } finally {
      await _safeSignOut();
    }
  }

  /// 다음 인증 시도에서 이전 verificationId나 resend token이 섞이지 않도록 상태를 비웁니다.
  void reset() {
    _pendingPhoneNumber = null;
    _verificationId = null;
    _resendToken = null;
    _isCurrentPhoneVerified = false;
  }

  /// 같은 번호 재전송은 resend token을 유지하고, 번호가 바뀌면 전체 상태를 교체합니다.
  void _preparePendingVerification(String phoneNumber) {
    if (_pendingPhoneNumber != phoneNumber) {
      reset();
    }

    _pendingPhoneNumber = phoneNumber;
    _verificationId = null;
    _isCurrentPhoneVerified = false;
  }

  /// Firebase 전화번호 인증을 지원하지 않는 플랫폼에서는 조기에 명확한 예외를 반환합니다.
  void _ensureSupportedPlatform() {
    if (kIsWeb) {
      throw const SoiApiException(
        message: '현재 플랫폼에서는 Firebase 전화번호 인증을 지원하지 않습니다.',
      );
    }

    final isSupportedMobilePlatform =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isSupportedMobilePlatform) {
      throw const SoiApiException(
        message: '현재 플랫폼에서는 Firebase 전화번호 인증을 지원하지 않습니다.',
      );
    }
  }

  /// 검증 후 남는 Firebase 임시 로그인 상태를 정리해 앱 인증과 분리합니다.
  Future<void> _safeSignOut() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      return;
    }
    await _firebaseAuth.signOut();
  }

  /// Firebase Auth 에러 코드를 기존 앱 예외 체계로 변환해 화면 메시지 분기를 단순화합니다.
  SoiApiException _mapFirebaseAuthException(FirebaseAuthException error) {
    switch (error.code) {
      case 'missing-phone-number':
      case 'invalid-phone-number':
        return const BadRequestException(message: '전화번호 형식을 확인해주세요.');
      case 'app-not-authorized':
        return const SoiApiException(
          message: '현재 iOS 앱 설정으로는 전화번호 인증을 사용할 수 없습니다. Firebase iOS 설정과 번들 ID를 확인해주세요.',
        );
      case 'app-not-verified':
        return const SoiApiException(
          message: '앱 검증에 실패했습니다. Safari reCAPTCHA가 열리고 완료되는지 확인해주세요.',
        );
      case 'captcha-check-failed':
        return const SoiApiException(
          message: 'reCAPTCHA 검증에 실패했습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
        );
      case 'web-context-cancelled':
        return const SoiApiException(
          message: 'reCAPTCHA 인증이 취소되었습니다. Safari 인증을 끝까지 완료해주세요.',
        );
      case 'web-network-request-failed':
        return const NetworkException(
          message: 'reCAPTCHA 인증 중 네트워크 오류가 발생했습니다. 다시 시도해주세요.',
        );
      case 'missing-app-token':
      case 'invalid-app-credential':
      case 'missing-app-credential':
      case 'notification-not-forwarded':
        return const SoiApiException(
          message: 'iOS 푸시 기반 앱 검증에 실패했습니다. 앱을 완전히 종료한 뒤 다시 시도해주세요.',
        );
      case 'invalid-verification-code':
        return const BadRequestException(message: '인증번호가 올바르지 않습니다.');
      case 'session-expired':
        return const BadRequestException(message: '인증번호가 만료되었습니다. 다시 요청해주세요.');
      case 'quota-exceeded':
      case 'too-many-requests':
        return const SoiApiException(message: '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.');
      case 'network-request-failed':
        return const NetworkException();
      default:
        final message = error.message?.trim();
        if (message != null && message.isNotEmpty) {
          return SoiApiException(message: message, originalException: error);
        }
        return SoiApiException(
          message: '전화번호 인증 처리 중 오류가 발생했습니다.',
          originalException: error,
        );
    }
  }
}
