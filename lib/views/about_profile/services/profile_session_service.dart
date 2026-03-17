import '../../../api/controller/user_controller.dart';
import '../../../app/push/app_push_coordinator.dart';
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
    await AppPushCoordinator.instance.deleteCurrentDeviceToken();
    await userController.logout();
    AppPushCoordinator.instance.clearLocalState();
    feedDataManager.reset();
  }

  /// 이 메서드는 회원탈퇴를 시작하고 남은 데이터를 정리해요.
  /// 삭제가 끝나면 로컬 로그인 상태와 캐시도 함께 정리해요.
  Future<void> beginDeleteAccount({
    required UserController userController,
    required FeedDataManager feedDataManager,
  }) async {
    final currentUser = userController.currentUser;
    if (currentUser == null) {
      throw StateError('No authenticated user for account deletion.');
    }

    await AppPushCoordinator.instance.deleteCurrentDeviceToken();
    final deletedUser = await userController.deleteUser(currentUser.id);
    if (deletedUser == null) {
      throw StateError('Account deletion failed.');
    }

    AppPushCoordinator.instance.clearLocalState();
    feedDataManager.reset();
  }
}
