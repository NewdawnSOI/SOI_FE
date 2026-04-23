import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagging_core/tagging_core.dart';
import 'package:tagging_flutter/tagging_flutter.dart';

void main() {
  testWidgets(
    'places persisted tags from normalized coordinates inside the viewport',
    (tester) async {
      const imageSize = Size(200, 100);
      const comment = TagEntry(
        id: '1',
        scopeId: 'post:1',
        actorId: '4',
        anchor: TagPosition(x: 0.5, y: 0.1),
        content: TagContent.text('hello'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: imageSize.width,
              height: imageSize.height,
              child: TagOverlay(
                comments: [comment],
                pendingMarker: null,
                isShowingComments: true,
                showActionOverlay: false,
                selectedCommentKey: null,
                expandedMediaTagKey: null,
                imageSize: imageSize,
                commentAvatarBuilder: _buildCommentAvatar,
                pendingAvatarBuilder: _buildPendingAvatar,
                onCommentTap: _noopTap,
                onCommentLongPress: _noopLongPress,
              ),
            ),
          ),
        ),
      );

      final bubbleFinder = find.byType(TagBubble);
      expect(bubbleFinder, findsOneWidget);

      final topLeft = tester.getTopLeft(bubbleFinder);
      final expectedTip = TagGeometryService.clampTagAnchor(
        Offset(imageSize.width * 0.5, imageSize.height * 0.1),
        imageSize,
        TagProfileTagSpec.avatarSize,
      );
      final expectedTopLeft = TagGeometryService.tagTopLeftFromTipAnchor(
        expectedTip,
        TagProfileTagSpec.avatarSize,
      );

      expect(topLeft.dx, moreOrLessEquals(expectedTopLeft.dx, epsilon: 0.01));
      expect(topLeft.dy, moreOrLessEquals(expectedTopLeft.dy, epsilon: 0.01));
    },
  );
}

Widget _buildCommentAvatar(
  BuildContext context,
  TagEntry comment,
  double size,
  bool isSelected,
) {
  return SizedBox(width: size, height: size);
}

Widget _buildPendingAvatar(
  BuildContext context,
  TagPendingMarker marker,
  double size,
  double? progress,
) {
  return SizedBox(width: size, height: size);
}

Future<void> _noopTap({
  required TagEntry comment,
  required String key,
  required Offset tipAnchor,
}) async {}

void _noopLongPress({
  required String key,
  required TagEntityId? commentId,
  required Offset position,
}) {}
