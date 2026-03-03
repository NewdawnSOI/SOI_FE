import 'package:flutter/material.dart';

import 'app_constants.dart';

/// 앱 컨테이너 빌더 함수
Widget buildAppContainer(BuildContext context, Widget child) {
  final mediaQuery = MediaQuery.of(context);
  final clampedScale = mediaQuery.textScaler
      .scale(AppConstant.textScaleMin)
      .clamp(AppConstant.textScaleMin, AppConstant.textScaleMax);
  final scaledChild = MediaQuery(
    data: mediaQuery.copyWith(textScaler: TextScaler.linear(clampedScale)),
    child: child,
  );

  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < AppConstant.wideLayoutBreakpoint) {
        return scaledChild;
      }

      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppConstant.wideLayoutMaxWidth,
            ),
            child: scaledChild,
          ),
        ),
      );
    },
  );
}
