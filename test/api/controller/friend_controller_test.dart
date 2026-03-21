import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/controller/friend_controller.dart';
import 'package:soi/api/models/friend.dart';
import 'package:soi/api/services/friend_service.dart';
import 'package:soi_api_client/api.dart';

class _FakeFriendApi extends FriendAPIApi {
  _FakeFriendApi({this.onGetAllFriend, this.onBlockFriend});

  final Future<ApiResponseDtoListUserFindRespDto?> Function(
    String friendStatus,
  )?
  onGetAllFriend;
  final Future<ApiResponseDtoBoolean?> Function(FriendReqDto dto)?
  onBlockFriend;

  @override
  Future<ApiResponseDtoListUserFindRespDto?> getAllFriend(
    String friendStatus,
  ) async {
    final handler = onGetAllFriend;
    if (handler == null) {
      throw UnimplementedError('onGetAllFriend is not configured');
    }
    return handler(friendStatus);
  }

  @override
  Future<ApiResponseDtoBoolean?> blockFriend(FriendReqDto friendReqDto) async {
    final handler = onBlockFriend;
    if (handler == null) {
      throw UnimplementedError('onBlockFriend is not configured');
    }
    return handler(friendReqDto);
  }
}

UserFindRespDto _userDto(int id, String nickname, String name) {
  return UserFindRespDto(id: id, nickname: nickname, name: name, active: true);
}

void main() {
  group('FriendController', () {
    test(
      'stores accepted snapshot and reuses fresh cache without extra API calls',
      () async {
        var getAllFriendCalls = 0;

        final controller = FriendController(
          friendService: FriendService(
            friendApi: _FakeFriendApi(
              onGetAllFriend: (friendStatus) async {
                getAllFriendCalls += 1;
                expect(friendStatus, 'ACCEPTED');
                return ApiResponseDtoListUserFindRespDto(
                  success: true,
                  data: <UserFindRespDto>[
                    _userDto(11, 'friend_11', '친구 11'),
                    _userDto(12, 'friend_12', '친구 12'),
                  ],
                );
              },
            ),
          ),
        );

        final friends = await controller.getAllFriends(userId: 7);
        expect(friends, hasLength(2));
        expect(controller.cachedFriendsUserId, 7);
        expect(controller.cachedFriends, hasLength(2));
        expect(controller.peekCachedFriendCount(userId: 7), 2);
        expect(controller.acceptedFriendsRevision, 1);
        expect(getAllFriendCalls, 1);

        final cachedFriends = await controller.getAllFriends(userId: 7);
        expect(cachedFriends, hasLength(2));
        expect(controller.acceptedFriendsRevision, 1);
        expect(getAllFriendCalls, 1);
      },
    );

    test(
      'blockFriend invalidates caches and prunes accepted snapshot',
      () async {
        var getAllFriendCalls = 0;

        final controller = FriendController(
          friendService: FriendService(
            friendApi: _FakeFriendApi(
              onGetAllFriend: (friendStatus) async {
                getAllFriendCalls += 1;
                return ApiResponseDtoListUserFindRespDto(
                  success: true,
                  data: <UserFindRespDto>[
                    _userDto(2, 'friend_2', '친구 2'),
                    _userDto(3, 'friend_3', '친구 3'),
                  ],
                );
              },
              onBlockFriend: (dto) async {
                expect(dto.requesterId, 7);
                expect(dto.receiverId, 2);
                return ApiResponseDtoBoolean(success: true, data: true);
              },
            ),
          ),
        );

        await controller.getAllFriends(userId: 7);
        final previousBlockedRevision = controller.blockedFriendsRevision;

        final result = await controller.blockFriend(
          requesterId: 7,
          receiverId: 2,
        );

        expect(result, isTrue);
        expect(controller.cachedFriends.map((friend) => friend.id), [3]);
        expect(controller.acceptedFriendsRevision, 2);
        expect(controller.blockedFriendsRevision, previousBlockedRevision + 1);

        await controller.getAllFriends(userId: 7);
        expect(getAllFriendCalls, 2);
      },
    );
  });
}
