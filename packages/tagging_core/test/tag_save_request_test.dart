import 'package:tagging_core/tagging_core.dart';
import 'package:test/test.dart';

void main() {
  group('TagSaveRequest', () {
    test('returns missing text for empty text content', () {
      const request = TagSaveRequest(
        scopeId: 'post:1',
        actorId: '7',
        content: TagContent.text(''),
        anchor: TagPosition(x: 0.5, y: 0.5),
      );

      expect(request.validateForSave(), TagValidationError.missingText);
    });

    test('returns missing anchor when media request has no anchor', () {
      const request = TagSaveRequest(
        scopeId: 'post:1',
        actorId: '7',
        content: TagContent.image(reference: '/tmp/photo.jpg'),
      );

      expect(request.validateForSave(), TagValidationError.missingAnchor);
    });

    test('accepts anchored audio request', () {
      const request = TagSaveRequest(
        scopeId: 'post:1',
        actorId: '7',
        content: TagContent.audio(
          reference: '/tmp/audio.m4a',
          waveformSamples: <double>[0.1, 0.2],
          durationMs: 1200,
        ),
        anchor: TagPosition(x: 0.4, y: 0.6),
      );

      expect(request.validateForSave(), isNull);
    });
  });
}
