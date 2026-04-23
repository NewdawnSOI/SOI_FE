import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagging_flutter/tagging_flutter.dart';

void main() {
  test('clamps tip anchors inside the media viewport', () {
    final clamped = TagGeometryService.clampTagAnchor(
      const Offset(-20, 999),
      const Size(200, 100),
      TagProfileTagSpec.avatarSize,
    );

    expect(clamped.dx, greaterThanOrEqualTo(0));
    expect(clamped.dx, lessThanOrEqualTo(200));
    expect(clamped.dy, greaterThanOrEqualTo(0));
    expect(clamped.dy, lessThanOrEqualTo(100));
  });

  test('converts a tip anchor into the expected top-left position', () {
    const tipAnchor = Offset(50, 60);
    final topLeft = TagGeometryService.tagTopLeftFromTipAnchor(
      tipAnchor,
      TagProfileTagSpec.avatarSize,
    );

    expect(topLeft.dx, lessThan(tipAnchor.dx));
    expect(topLeft.dy, lessThan(tipAnchor.dy));
  });
}
