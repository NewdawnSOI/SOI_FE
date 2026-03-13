import 'package:flutter/widgets.dart';

/// 앱의 라우트 변경을 감지하기 위한 RouteObserver 인스턴스입니다.
/// 이 옵저버는 앱 내에서 라우트가 변경될 때마다 알림을 받을 수 있도록 해줍니다.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
