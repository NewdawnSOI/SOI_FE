import 'package:flutter/widgets.dart';

/// Global route observer used for widgets that need to react to
/// navigation visibility changes (e.g., pausing media when covered).
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
