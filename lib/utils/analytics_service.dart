import 'package:flutter/foundation.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

/// 앱에서 Mixpanel을 사용한 분석 기능을 담당하는 서비스 클래스입니다.
/// Mixpanel SDK의 초기화, 사용자 식별, 이벤트 추적 등의 기능을 제공합니다.
class AnalyticsService {
  final Mixpanel _mixpanel;

  AnalyticsService._(this._mixpanel);

  /// AnalyticsService의 인스턴스를 생성하는 팩토리 메서드입니다.
  /// Mixpanel SDK를 초기화하고, 앱의 플랫폼과 빌드 모드에 대한 슈퍼 프로퍼티를 등록합니다.
  static Future<AnalyticsService> create({required String token}) async {
    // Mixpanel SDK 초기화 시 자동 이벤트 추적을 비활성화합니다.
    final mixpanel = await Mixpanel.init(token, trackAutomaticEvents: false);

    // Mixpanel SDK의 로깅을 디버그 모드에서만 활성화합니다.
    mixpanel.setLoggingEnabled(kDebugMode);

    // 앱의 플랫폼과 빌드 모드에 대한 슈퍼 프로퍼티를 등록합니다.
    await mixpanel.registerSuperProperties({
      'platform': defaultTargetPlatform.name,
      'build_mode': kReleaseMode ? 'release' : 'debug',
    });

    // AnalyticsService 인스턴스를 생성해서 반환합니다.
    return AnalyticsService._(mixpanel);
  }

  /// 사용자를 식별하는 함수입니다. 사용자 ID를 Mixpanel에 전달해서 사용자를 식별합니다.
  Future<void> identify({required int userId}) {
    return _mixpanel.identify(userId.toString());
  }

  /// 이벤트를 추적하는 함수입니다.
  /// 이벤트 이름과 선택적으로 이벤트 속성을 전달해서 Mixpanel에 이벤트를 기록합니다.
  Future<void> track(String eventName, {Map<String, dynamic>? properties}) {
    return _mixpanel.track(eventName, properties: properties);
  }

  /// Mixpanel의 이벤트 큐를 서버로 전송하는 함수입니다.
  /// 일반적으로 앱이 백그라운드로 전환되거나 종료될 때 호출됩니다.
  void flush() {
    _mixpanel.flush();
  }

  /// 사용자 식별 정보를 초기화하는 함수입니다.
  /// 사용자가 로그아웃할 때 호출해서 Mixpanel의 사용자 식별 정보를 초기화합니다.
  Future<void> reset() {
    return _mixpanel.reset();
  }
}
