import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagging_flutter/tagging_flutter.dart';

/// 드롭 이후 delegate에 전달된 payload를 기록해 저장 계약을 검증합니다.
class _RecordingSaveDelegate implements TaggingSaveDelegate {
  TagSavePayload? lastPayload;

  @override
  Future<TagSaveResult> save({
    required TagSavePayload payload,
    void Function(double progress)? onProgress,
  }) async {
    lastPayload = payload;
    onProgress?.call(1.0);
    return TagSaveResult(
      comment: TagComment(
        id: '1',
        userId: payload.userId,
        locationX: payload.locationX,
        locationY: payload.locationY,
        kind: TagCommentKind.text,
      ),
    );
  }
}

void main() {
  testWidgets('saves the dropped payload with the resolved relative position', (
    tester,
  ) async {
    final delegate = _RecordingSaveDelegate();
    TagComment? savedComment;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 120,
                top: 420,
                child: DragTarget<String>(
                  key: const ValueKey('drop-zone'),
                  onWillAcceptWithDetails: (_) => true,
                  onAcceptWithDetails: (_) {},
                  builder: (context, candidateData, rejectedData) {
                    return const SizedBox(width: 120, height: 120);
                  },
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: TagProfileDragWidget(
                  payload: const TagSavePayload(
                    scopeId: 'post:1',
                    userId: '7',
                    kind: TagDraftKind.text,
                    text: 'hello',
                  ),
                  saveDelegate: delegate,
                  avatarBuilder: (context, payload, size) {
                    return SizedBox(width: size, height: size);
                  },
                  resolveDropRelativePosition: () =>
                      const TagPosition(x: 0.25, y: 0.75),
                  onSaveSuccess: (comment) {
                    savedComment = comment;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final bubbleFinder = find.byType(TagBubble);
    final gesture = await tester.startGesture(tester.getCenter(bubbleFinder));
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('drop-zone'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(delegate.lastPayload?.locationX, 0.25);
    expect(delegate.lastPayload?.locationY, 0.75);
    expect(savedComment?.locationX, 0.25);
    expect(savedComment?.locationY, 0.75);
  });
}
