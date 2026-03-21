import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/controller/comment_audio_controller.dart';

class _FakeCommentAudioPlayer implements CommentAudioPlayer {
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<ap.PlayerState> _stateController =
      StreamController<ap.PlayerState>.broadcast();

  int playCallCount = 0;
  int pauseCallCount = 0;
  int stopCallCount = 0;
  int seekCallCount = 0;
  int resumeCallCount = 0;
  int disposeCallCount = 0;
  String? lastPlayedUrl;

  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;

  @override
  Stream<Duration> get onDurationChanged => _durationController.stream;

  @override
  Stream<ap.PlayerState> get onPlayerStateChanged => _stateController.stream;

  void emitPosition(Duration position) {
    _positionController.add(position);
  }

  @override
  Future<void> play(String audioUrl) async {
    playCallCount++;
    lastPlayedUrl = audioUrl;
  }

  @override
  Future<void> pause() async {
    pauseCallCount++;
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
  }

  @override
  Future<void> seek(Duration position) async {
    seekCallCount++;
  }

  @override
  Future<void> resume() async {
    resumeCallCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
  }
}

void main() {
  group('CommentAudioController', () {
    test(
      'toggle resumes an existing paused player instead of replaying',
      () async {
        late _FakeCommentAudioPlayer fakePlayer;
        final controller = CommentAudioController(
          playerFactory: () {
            fakePlayer = _FakeCommentAudioPlayer();
            return fakePlayer;
          },
        );

        await controller.playComment('c1', 'https://audio.test/file.m4a');
        await controller.pauseComment('c1');
        await controller.seekToPosition('c1', const Duration(seconds: 2));

        await controller.toggleComment('c1', 'https://audio.test/file.m4a');

        expect(fakePlayer.playCallCount, 1);
        expect(fakePlayer.resumeCallCount, 1);
      },
    );

    test('throttles rapid position updates', () async {
      late _FakeCommentAudioPlayer fakePlayer;
      final controller = CommentAudioController(
        playerFactory: () {
          fakePlayer = _FakeCommentAudioPlayer();
          return fakePlayer;
        },
      );

      await controller.playComment('c1', 'https://audio.test/file.m4a');

      var notifyCount = 0;
      controller.addListener(() {
        notifyCount++;
      });

      fakePlayer.emitPosition(const Duration(milliseconds: 10));
      await Future<void>.delayed(Duration.zero);
      notifyCount = 0;

      fakePlayer.emitPosition(const Duration(milliseconds: 50));
      fakePlayer.emitPosition(const Duration(milliseconds: 120));
      await Future<void>.delayed(Duration.zero);
      expect(notifyCount, 0);

      fakePlayer.emitPosition(const Duration(milliseconds: 260));
      await Future<void>.delayed(Duration.zero);
      expect(notifyCount, 1);
    });

    test(
      'disposeCommentPlayer clears player state and disposes subscriptions',
      () async {
        late _FakeCommentAudioPlayer fakePlayer;
        final controller = CommentAudioController(
          playerFactory: () {
            fakePlayer = _FakeCommentAudioPlayer();
            return fakePlayer;
          },
        );

        await controller.playComment('c1', 'https://audio.test/file.m4a');
        await controller.disposeCommentPlayer('c1');

        expect(controller.loadedCommentsCount, 0);
        expect(controller.getCommentAudioUrl('c1'), isNull);
        expect(fakePlayer.stopCallCount, 1);
        expect(fakePlayer.disposeCallCount, 1);
      },
    );
  });
}
