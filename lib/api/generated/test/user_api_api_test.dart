import 'package:test/test.dart';
import 'package:soi_api/soi_api.dart';


/// tests for UserAPIApi
void main() {
  final instance = SoiApi().getUserAPIApi();

  group(UserAPIApi, () {
    // 전화번호 인증
    //
    // 사용자가 입력한 전화번호로 인증을 발송합니다.
    //
    //Future<bool> authSMS(String phone) async
    test('test authSMS', () async {
      // TODO
    });

    // 사용자 생성
    //
    // 새로운 사용자를 등록합니다.
    //
    //Future<ApiResponseDtoUserRespDto> createUser(UserCreateReqDto userCreateReqDto) async
    test('test createUser', () async {
      // TODO
    });

    // 유저 Id로 사용자 삭제
    //
    // id 로 사용자를 삭제합니다.
    //
    //Future<ApiResponseDtoUserRespDto> deleteUser(String userId) async
    test('test deleteUser', () async {
      // TODO
    });

    // 사용자 id 중복 체크
    //
    // 사용자 id 중복 체크합니다. 사용가능 : true, 사용불가(중복) : false
    //
    //Future<ApiResponseDtoBoolean> idCheck(String userId) async
    test('test idCheck', () async {
      // TODO
    });

    // 사용자 로그인(전화번호로)
    //
    // 인증이 완료된 전화번호로 로그인을 합니다.
    //
    //Future<ApiResponseDtoUserRespDto> login(String phone) async
    test('test login', () async {
      // TODO
    });

  });
}
