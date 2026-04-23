import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagging_core/tagging_core.dart';
import 'package:tagging_flutter/tagging_flutter.dart';

/// 드롭 이후 mutation port에 전달된 저장 요청을 기록해 drag handle 계약을 검증합니다.
class _RecordingMutationPort implements TagMutationPort {
  TagSaveRequest? lastRequest;

  @override
  Future<TagMutationResult> save({
    required TagSaveRequest request,
    void Function(double progress)? onProgress,
  }) async {
    lastRequest = request;
    onProgress?.call(1.0);
    return TagMutationResult(
      entry: TagEntry(
        id: '1',
        scopeId: request.scopeId,
        actorId: request.actorId,
        anchor: request.anchor,
        content: request.content,
      ),
    );
  }
}

void main() {
  testWidgets('saves the dropped request with the resolved relative position', (
    tester,
  ) async {
    final port = _RecordingMutationPort();
    TagEntry? savedEntry;

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
                child: TagDragHandle(
                  request: const TagSaveRequest(
                    scopeId: 'post:1',
                    actorId: '7',
                    content: TagContent.text('hello'),
                  ),
                  mutationPort: port,
                  handleBuilder: (context, request, size) {
                    return SizedBox(width: size, height: size);
                  },
                  resolveDropRelativePosition: () =>
                      const TagPosition(x: 0.25, y: 0.75),
                  onSaveSuccess: (entry) {
                    savedEntry = entry;
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

    expect(port.lastRequest?.anchor?.x, 0.25);
    expect(port.lastRequest?.anchor?.y, 0.75);
    expect(savedEntry?.anchor?.x, 0.25);
    expect(savedEntry?.anchor?.y, 0.75);
  });
}
