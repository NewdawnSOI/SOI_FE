import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/models/category.dart';
import 'package:soi/views/about_archiving/widgets/archive_card_widget/archive_card_models.dart';

void main() {
  group('ArchiveCardViewData', () {
    test('treats identical category fields as equal view data', () {
      final category = Category(
        id: 1,
        name: 'Travel',
        photoUrl: 'photos/travel.jpg',
        isNew: true,
        totalUserCount: 3,
        usersProfileUrl: const ['https://example.com/a.jpg'],
        usersProfileKey: const ['a.jpg', 'b.jpg'],
      );

      final first = ArchiveCardViewData.fromCategory(category);
      final second = ArchiveCardViewData.fromCategory(category);

      expect(first, second);
      expect(first.profileRowData.totalUserCount, 3);
      expect(first.profileRowData.profileImageUrls, const [
        'https://example.com/a.jpg',
      ]);
      expect(first.profileRowData.profileImageKeys, const ['a.jpg', 'b.jpg']);
    });

    test('detects meaningful card field changes', () {
      final base = ArchiveCardViewData.fromCategory(
        const Category(
          id: 1,
          name: 'Travel',
          photoUrl: 'photos/travel.jpg',
          totalUserCount: 2,
          usersProfileUrl: ['https://example.com/a.jpg'],
          usersProfileKey: ['a.jpg'],
        ),
      );
      final changed = ArchiveCardViewData.fromCategory(
        const Category(
          id: 1,
          name: 'Travel',
          photoUrl: 'photos/updated.jpg',
          totalUserCount: 4,
          usersProfileUrl: [
            'https://example.com/a.jpg',
            'https://example.com/b.jpg',
          ],
          usersProfileKey: ['a.jpg', 'b.jpg'],
        ),
      );

      expect(base, isNot(changed));
      expect(changed.profileRowData.totalUserCount, 4);
    });
  });
}
