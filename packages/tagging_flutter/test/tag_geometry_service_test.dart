import 'package:flutter_test/flutter_test.dart';
import 'package:tagging_flutter/tagging_flutter.dart';

void main() {
  test('can expand image and video comments with media refs', () {
    expect(
      TagGeometryService.canExpandMediaComment(
        const TagComment(kind: TagCommentKind.image, fileKey: 'image.jpg'),
      ),
      isTrue,
    );
    expect(
      TagGeometryService.canExpandMediaComment(
        const TagComment(kind: TagCommentKind.video, fileUrl: 'video.mp4'),
      ),
      isTrue,
    );
    expect(
      TagGeometryService.canExpandMediaComment(
        const TagComment(kind: TagCommentKind.text),
      ),
      isFalse,
    );
  });
}
