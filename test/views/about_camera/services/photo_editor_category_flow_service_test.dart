import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/models/selected_friend_model.dart';
import 'package:soi/views/about_camera/models/add_category_draft.dart';
import 'package:soi/views/about_camera/services/photo_editor_category_flow_service.dart';

void main() {
  group('PhotoEditorCategoryFlowService.buildCategoryReceiverIds', () {
    test('returns empty when no friends were selected', () {
      final draft = AddCategoryDraft(
        requesterId: 7,
        categoryName: 'Solo',
        selectedFriends: const [],
      );

      expect(
        PhotoEditorCategoryFlowService.buildCategoryReceiverIds(draft),
        isEmpty,
      );
    });

    test('includes requester once and skips invalid or duplicate ids', () {
      final draft = AddCategoryDraft(
        requesterId: 7,
        categoryName: 'Friends',
        selectedFriends: const [
          SelectedFriendModel(uid: '11', name: 'Alice'),
          SelectedFriendModel(uid: '11', name: 'Alice Again'),
          SelectedFriendModel(uid: 'invalid', name: 'Broken'),
          SelectedFriendModel(uid: '42', name: 'Bob'),
        ],
      );

      expect(PhotoEditorCategoryFlowService.buildCategoryReceiverIds(draft), [
        7,
        11,
        42,
      ]);
    });
  });
}
