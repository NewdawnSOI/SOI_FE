import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagging_flutter/tagging_flutter.dart';

class _FakeSaveDelegate implements TaggingSaveDelegate {
  const _FakeSaveDelegate();

  @override
  Future<TagSaveResult> save({
    required TagSavePayload payload,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(1.0);
    return const TagSaveResult(
      comment: TagComment(
        id: '1',
        userId: '7',
        locationX: 0.5,
        locationY: 0.5,
        kind: TagCommentKind.text,
      ),
    );
  }
}

void main() {
  testWidgets('switches to placing mode after text draft submission', (
    tester,
  ) async {
    final drafts = <TagScopeId, TagDraft>{};

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: TagComposerWidget(
              scopeId: 'post:1',
              pendingDrafts: drafts,
              saveDelegate: const _FakeSaveDelegate(),
              avatarBuilder: (_, __, ___) => const SizedBox.shrink(),
              resolveDropRelativePosition: (_) =>
                  const TagPosition(x: 0.5, y: 0.5),
              onTextDraftSubmitted: (scopeId, text) async {
                drafts[scopeId] = const TagDraft(
                  kind: TagDraftKind.text,
                  text: 'hello',
                  recorderUserId: '7',
                );
              },
              basePlaceholderText: 'add',
              textInputHintText: 'hint',
              cameraIcon: const Icon(Icons.camera_alt),
              micIcon: const Icon(Icons.mic),
              onCommentSaveProgress: (_, __) {},
              onCommentSaveSuccess: (_, __) {},
              onCommentSaveFailure: (_, __) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('add'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(TagProfileDragWidget), findsOneWidget);
  });
}
