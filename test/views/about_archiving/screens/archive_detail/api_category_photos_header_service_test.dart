import 'package:flutter_test/flutter_test.dart';
import 'package:soi/views/about_archiving/screens/archive_detail/services/category_photos_header_service.dart';

/// 헤더 디자인 상수를 테스트에서 재사용할 기본 토큰 묶음입니다.
const CategoryPhotosHeaderTokens _tokens = CategoryPhotosHeaderTokens(
  expandedHorizontalPadding: 20,
  collapsedHorizontalPadding: 16,
  expandedTitleBottomInset: 96,
  compactTitleVerticalOffset: 12,
  toolbarItemVerticalOffset: 20,
  collapsedTitleScale: 0.86,
  titleFontSize: 26,
);

void main() {
  group('CategoryPhotosHeaderLayoutResolver', () {
    test(
      'expanded state keeps title in expanded position and hero enabled',
      () {
        final layout = CategoryPhotosHeaderLayoutResolver.resolve(
          minExtent: 100,
          maxExtent: 260,
          shrinkOffset: 0,
          viewportWidth: 360,
          devicePixelRatio: 2,
          tokens: _tokens,
        );

        expect(layout.progress, 0);
        expect(layout.backgroundOpacity, 1);
        expect(layout.expandedInfoOpacity, 1);
        expect(layout.compactTitleOpacity, 0);
        expect(layout.toolbarOverlayOpacity, 0);
        expect(layout.horizontalPadding, 20);
        expect(layout.titleTop, 164);
        expect(layout.largeTitleScale, 1);
        expect(layout.topBarItemTop, 52);
        expect(layout.heroEnabled, isTrue);
        expect(layout.decodeWidth, 720);
      },
    );

    test('collapsed state moves title to toolbar line and disables hero', () {
      final layout = CategoryPhotosHeaderLayoutResolver.resolve(
        minExtent: 100,
        maxExtent: 260,
        shrinkOffset: 160,
        viewportWidth: 360,
        devicePixelRatio: 2,
        tokens: _tokens,
      );

      expect(layout.progress, 1);
      expect(layout.backgroundOpacity, 0);
      expect(layout.expandedInfoOpacity, 0);
      expect(layout.compactTitleOpacity, 1);
      expect(layout.toolbarOverlayOpacity, 0.94);
      expect(layout.horizontalPadding, 16);
      expect(layout.titleTop, 60);
      expect(layout.largeTitleScale, 0.86);
      expect(layout.topBarItemTop, 52);
      expect(layout.heroEnabled, isFalse);
    });

    test(
      'mid scroll uses eased interpolation and clamps oversized offsets',
      () {
        final midLayout = CategoryPhotosHeaderLayoutResolver.resolve(
          minExtent: 100,
          maxExtent: 260,
          shrinkOffset: 80,
          viewportWidth: 0.2,
          devicePixelRatio: 0.2,
          tokens: _tokens,
        );
        final clampedLayout = CategoryPhotosHeaderLayoutResolver.resolve(
          minExtent: 100,
          maxExtent: 260,
          shrinkOffset: 999,
          viewportWidth: 0.2,
          devicePixelRatio: 0.2,
          tokens: _tokens,
        );

        expect(midLayout.progress, 0.5);
        expect(midLayout.horizontalPadding, closeTo(17.93, 0.01));
        expect(midLayout.titleTop, closeTo(110.245, 0.01));
        expect(midLayout.largeTitleScale, closeTo(0.928, 0.001));
        expect(midLayout.heroEnabled, isTrue);
        expect(midLayout.decodeWidth, 1);

        expect(clampedLayout.progress, 1);
        expect(clampedLayout.heroEnabled, isFalse);
        expect(clampedLayout.decodeWidth, 1);
      },
    );
  });
}
