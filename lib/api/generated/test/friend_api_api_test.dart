import 'package:test/test.dart';
import 'package:soi_api/soi_api.dart';


/// tests for FriendAPIApi
void main() {
  final instance = SoiApi().getFriendAPIApi();

  group(FriendAPIApi, () {
    // 친구 추가
    //
    // 사용자 id를 통해 친구추가를 합니다.
    //
    //Future<ApiResponseDtoFriendRespDto> create(FriendReqDto friendReqDto) async
    test('test create', () async {
      // TODO
    });

    // 친구 상태 업데이트
    //
    // 친구 관계 id, 상태 : ACCEPTED, BLOCKED, CANCELLED 를 받아 상태를 업데이트합니다.
    //
    //Future<ApiResponseDtoFriendRespDto> update(FriendUpdateRespDto friendUpdateRespDto) async
    test('test update', () async {
      // TODO
    });

  });
}
