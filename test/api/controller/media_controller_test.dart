import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/services/media_service.dart';
import 'package:soi_api_client/api.dart';

class _NoopMediaApi extends APIApi {}

class _FakeMediaService extends MediaService {
  _FakeMediaService({required this.onGetPresignedUrls})
    : super(mediaApi: _NoopMediaApi());

  final Future<List<String>> Function(List<String> keys) onGetPresignedUrls;

  @override
  Future<List<String>> getPresignedUrls(List<String> keys) {
    return onGetPresignedUrls(keys);
  }
}

void main() {
  group('MediaController presigned URLs', () {
    test('reuses cached urls and fetches only missing keys', () async {
      var currentTime = DateTime(2026, 3, 21, 12);
      final requestedBatches = <List<String>>[];

      final controller = MediaController(
        mediaService: _FakeMediaService(
          onGetPresignedUrls: (keys) async {
            requestedBatches.add(List<String>.from(keys));
            final batchIndex = requestedBatches.length;
            return keys
                .map((key) => 'https://cdn.test/$key?batch=$batchIndex')
                .toList(growable: false);
          },
        ),
        now: () => currentTime,
      );

      final firstUrls = await controller.getPresignedUrls([
        'image/a.jpg',
        'audio/b.m4a',
      ]);
      final secondUrls = await controller.getPresignedUrls([
        'audio/b.m4a',
        'video/c.mp4',
      ]);

      expect(firstUrls, [
        'https://cdn.test/image/a.jpg?batch=1',
        'https://cdn.test/audio/b.m4a?batch=1',
      ]);
      expect(secondUrls, [
        'https://cdn.test/audio/b.m4a?batch=1',
        'https://cdn.test/video/c.mp4?batch=2',
      ]);
      expect(requestedBatches, [
        ['image/a.jpg', 'audio/b.m4a'],
        ['video/c.mp4'],
      ]);
      expect(
        controller.peekPresignedUrl('audio/b.m4a'),
        'https://cdn.test/audio/b.m4a?batch=1',
      );
    });

    test('dedupes in-flight requests and refetches after ttl expiry', () async {
      var currentTime = DateTime(2026, 3, 21, 12);
      final firstBatchCompleter = Completer<List<String>>();
      var callCount = 0;

      final controller = MediaController(
        mediaService: _FakeMediaService(
          onGetPresignedUrls: (keys) {
            callCount++;
            expect(keys, ['profile/image.png']);

            if (callCount == 1) {
              return firstBatchCompleter.future;
            }

            return Future.value([
              'https://cdn.test/profile/image.png?refresh=$callCount',
            ]);
          },
        ),
        now: () => currentTime,
      );

      final first = controller.getPresignedUrl('profile/image.png');
      final second = controller.getPresignedUrl('profile/image.png');

      firstBatchCompleter.complete([
        'https://cdn.test/profile/image.png?refresh=1',
      ]);

      expect(await first, 'https://cdn.test/profile/image.png?refresh=1');
      expect(await second, 'https://cdn.test/profile/image.png?refresh=1');
      expect(callCount, 1);
      expect(
        controller.peekPresignedUrl('profile/image.png'),
        'https://cdn.test/profile/image.png?refresh=1',
      );

      currentTime = currentTime.add(const Duration(minutes: 56));

      expect(controller.peekPresignedUrl('profile/image.png'), isNull);
      expect(
        await controller.getPresignedUrl('profile/image.png'),
        'https://cdn.test/profile/image.png?refresh=2',
      );
      expect(callCount, 2);
    });
  });
}
