import 'package:tagging_core/tagging_core.dart';
import 'package:test/test.dart';

void main() {
  group('TagPositionMath', () {
    test('normalizes and clamps absolute coordinates into unit space', () {
      final relative = TagPositionMath.normalizeAbsolutePosition(
        absolutePosition: const TagPosition(x: 600, y: -20),
        viewportSize: const TagViewportSize(width: 300, height: 400),
      );

      expect(relative, const TagPosition(x: 1.0, y: 0.0));
    });

    test('denormalizes relative coordinates into viewport pixels', () {
      final absolute = TagPositionMath.denormalizeRelativePosition(
        relativePosition: const TagPosition(x: 0.25, y: 0.5),
        viewportSize: const TagViewportSize(width: 320, height: 500),
      );

      expect(absolute, const TagPosition(x: 80, y: 250));
    });
  });
}
