import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/models/friend.dart';
import 'package:soi/api/services/friend_service.dart';
import 'package:soi_api_client/api.dart';

class _FakeFriendApi extends FriendAPIApi {
  _FakeFriendApi({
    this.onGetAllFriend,
    this.onGetAllFriend1,
    this.onBlockFriend,
  });

  final Future<ApiResponseDtoListUserFindRespDto?> Function(
    String friendStatus,
  )?
  onGetAllFriend;
  final Future<ApiResponseDtoListFriendCheckRespDto?> Function(
    List<String> phoneNumbers,
  )?
  onGetAllFriend1;
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
  Future<ApiResponseDtoListFriendCheckRespDto?> getAllFriend1(
    List<String> friendPhoneNums,
  ) async {
    final handler = onGetAllFriend1;
    if (handler == null) {
      throw UnimplementedError('onGetAllFriend1 is not configured');
    }
    return handler(friendPhoneNums);
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
  group('FriendService caching', () {
    test(
      'dedupes in-flight friend list requests and refreshes after TTL',
      () async {
        var now = DateTime(2026, 3, 21, 12);
        var getAllFriendCalls = 0;
        final responseCompleter =
            Completer<ApiResponseDtoListUserFindRespDto?>();

        final service = FriendService(
          friendApi: _FakeFriendApi(
            onGetAllFriend: (friendStatus) {
              getAllFriendCalls += 1;
              expect(friendStatus, 'ACCEPTED');
              return responseCompleter.future;
            },
          ),
          now: () => now,
        );

        final firstRequest = service.getAllFriends(userId: 7);
        final secondRequest = service.getAllFriends(userId: 7);

        expect(getAllFriendCalls, 1);

        responseCompleter.complete(
          ApiResponseDtoListUserFindRespDto(
            success: true,
            data: <UserFindRespDto>[
              _userDto(1, 'friend_1', '친구 1'),
              _userDto(2, 'friend_2', '친구 2'),
            ],
          ),
        );

        final results = await Future.wait<List<dynamic>>([
          firstRequest,
          secondRequest,
        ]);
        expect(results[0], hasLength(2));
        expect(results[1], hasLength(2));

        final cachedFriends = await service.getAllFriends(userId: 7);
        expect(cachedFriends, hasLength(2));
        expect(getAllFriendCalls, 1);

        now = now.add(const Duration(seconds: 31));
        await service.getAllFriends(userId: 7);
        expect(getAllFriendCalls, 2);
      },
    );

    test(
      'reuses fresh relation cache and fetches only missing phone numbers',
      () async {
        var now = DateTime(2026, 3, 21, 12);
        final requestedBatches = <List<String>>[];

        final service = FriendService(
          friendApi: _FakeFriendApi(
            onGetAllFriend1: (phoneNumbers) async {
              requestedBatches.add(List<String>.from(phoneNumbers));
              return ApiResponseDtoListFriendCheckRespDto(
                success: true,
                data: <FriendCheckRespDto>[
                  FriendCheckRespDto(
                    phoneNum: '01011112222',
                    isFriend: true,
                    status: FriendCheckRespDtoStatusEnum.ACCEPTED,
                  ),
                ],
              );
            },
          ),
          now: () => now,
        );

        final firstRelations = await service.checkFriendRelations(
          userId: 99,
          phoneNumbers: const ['010-1111-2222', '01033334444'],
        );

        expect(requestedBatches, [
          ['01011112222', '01033334444'],
        ]);
        expect(firstRelations.map((relation) => relation.status).toList(), [
          FriendStatus.accepted,
          FriendStatus.none,
        ]);

        requestedBatches.clear();

        final secondRelations = await service.checkFriendRelations(
          userId: 99,
          phoneNumbers: const ['010 1111 2222', '010-5555-6666'],
        );

        expect(requestedBatches, [
          ['01055556666'],
        ]);
        expect(secondRelations.map((relation) => relation.status).toList(), [
          FriendStatus.accepted,
          FriendStatus.none,
        ]);

        now = now.add(const Duration(seconds: 31));
        await service.checkFriendRelations(
          userId: 99,
          phoneNumbers: const ['01011112222'],
        );
        expect(requestedBatches.last, ['01011112222']);
      },
    );
  });
}
