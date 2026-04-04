import 'package:flutter_test/flutter_test.dart';
import 'package:soi/views/common_widget/comment/comment_save_payload.dart';

void main() {
  group('CommentSavePayload', () {
    test(
      'toFallbackComment encodes waveform data with the shared CSV codec',
      () {
        const payload = CommentSavePayload(
          postId: 1,
          userId: 2,
          kind: CommentDraftKind.audio,
          audioPath: '/tmp/audio.m4a',
          waveformData: <double>[0.12344, 0.56789],
          duration: 3,
        );

        final comment = payload.toFallbackComment();

        expect(comment.waveformData, '0.1234,0.5679');
      },
    );
  });
}
