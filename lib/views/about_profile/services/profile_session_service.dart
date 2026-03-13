import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../api/controller/user_controller.dart';
import '../../about_feed/manager/feed_data_manager.dart';

/// 이 도우미는 로그아웃과 회원탈퇴처럼 큰 정리를 맡아요.
/// 화면은 버튼을 누르고, 실제 정리는 이곳이 해줘요.
class ProfileSessionService {
  const ProfileSessionService();

  /// 이 메서드는 로그인 정보를 지우고 피드도 비워줘요.
  /// 다른 사람이 들어와도 예전 내용이 섞이지 않게 해줘요.
  Future<void> logout({
    required UserController userController,
    required FeedDataManager feedDataManager,
  }) async {
    await userController.logout();
    feedDataManager.reset();
  }

  /// 이 메서드는 회원탈퇴를 시작하고 남은 데이터를 정리해요.
  /// 화면이 빨리 이동해도 삭제가 뒤에서 계속 되게 도와줘요.
  Future<void> beginDeleteAccount({
    required UserController userController,
    required FeedDataManager feedDataManager,
  }) async {
    final currentUser = userController.currentUser;
    if (currentUser == null) {
      throw StateError('No authenticated user for account deletion.');
    }

    final deletion = userController.deleteUser(currentUser.id);
    feedDataManager.reset();

    unawaited(
      deletion.catchError((Object error, StackTrace stackTrace) {
        debugPrint('계정 삭제 백그라운드 오류: $error');
        return null;
      }),
    );
  }
}
