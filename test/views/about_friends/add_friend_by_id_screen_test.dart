import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soi/api/controller/friend_controller.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/friend.dart';
import 'package:soi/api/models/friend_check.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/friend_service.dart';
import 'package:soi/api/services/media_service.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi/views/about_friends/add_friend_by_id_screen.dart';
import 'package:soi_api_client/api.dart';

class _InMemoryAssetLoader extends AssetLoader {
  const _InMemoryAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    return {
      'friends': {
        'add_by_id': {
          'title': 'ID로 추가하기',
          'search_hint': '친구 아이디 찾기',
          'not_found': '없는 아이디 입니다. 다시 입력해주세요',
          'request_sent': '{name}님에게 친구 요청을 보냈습니다',
          'request_failed': '친구 요청 실패',
          'status_friend': '친구',
          'status_pending': '요청됨',
          'status_blocked': '차단됨',
          'status_add': '친구 추가',
        },
      },
    };
  }
}

class _NoopAuthApi extends AuthControllerApi {}

class _NoopUserApi extends UserAPIApi {}

class _NoopFriendApi extends FriendAPIApi {}

class _NoopMediaApi extends APIApi {}

class _FakeUserController extends UserController {
  _FakeUserController({required this.onFindUsersByKeyword, User? currentUser})
    : super(
        userService: UserService(
          authApi: _NoopAuthApi(),
          userApi: _NoopUserApi(),
          onAuthTokenIssued: (_) {},
          onAuthTokenCleared: () {},
        ),
      ) {
    setCurrentUser(currentUser);
  }

  final Future<List<User>> Function(String keyword) onFindUsersByKeyword;
  final List<String> searchQueries = <String>[];

  @override
  Future<List<User>> findUsersByKeyword(String keyword) {
    searchQueries.add(keyword);
    return onFindUsersByKeyword(keyword);
  }
}

class _FakeFriendController extends FriendController {
  _FakeFriendController({required this.onCheckFriendRelations})
    : super(friendService: FriendService(friendApi: _NoopFriendApi()));

  final Future<List<FriendCheck>> Function({
    required int userId,
    required List<String> phoneNumbers,
  })
  onCheckFriendRelations;

  final List<List<String>> requestedBatches = <List<String>>[];

  @override
  Future<List<FriendCheck>> checkFriendRelations({
    required int userId,
    required List<String> phoneNumbers,
    bool forceRefresh = false,
  }) {
    requestedBatches.add(List<String>.from(phoneNumbers));
    return onCheckFriendRelations(userId: userId, phoneNumbers: phoneNumbers);
  }
}

class _FakeMediaController extends MediaController {
  _FakeMediaController({this.onGetPresignedUrl})
    : super(mediaService: MediaService(mediaApi: _NoopMediaApi()));

  final Future<String?> Function(String key)? onGetPresignedUrl;
  final List<String> requestedKeys = <String>[];

  @override
  Future<String?> getPresignedUrl(String key) async {
    requestedKeys.add(key);
    final handler = onGetPresignedUrl;
    if (handler == null) {
      return null;
    }
    return handler(key);
  }
}

Widget _buildTestApp({
  required UserController userController,
  required FriendController friendController,
  MediaController? mediaController,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('ko')],
    path: 'unused',
    fallbackLocale: const Locale('ko'),
    assetLoader: const _InMemoryAssetLoader(),
    child: Builder(
      builder: (easyContext) {
        return ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, __) => MultiProvider(
            providers: [
              ChangeNotifierProvider<UserController>.value(
                value: userController,
              ),
              ChangeNotifierProvider<FriendController>.value(
                value: friendController,
              ),
              ChangeNotifierProvider<MediaController>.value(
                value: mediaController ?? _FakeMediaController(),
              ),
            ],
            child: MaterialApp(
              locale: easyContext.locale,
              supportedLocales: easyContext.supportedLocales,
              localizationsDelegates: easyContext.localizationDelegates,
              home: const AddFriendByIdScreen(),
            ),
          ),
        );
      },
    ),
  );
}

Future<void> _searchById(WidgetTester tester, String query) async {
  expect(find.byType(TextField), findsOneWidget);
  await tester.enterText(find.byType(TextField), query);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('AddFriendByIdScreen', () {
    testWidgets(
      'dedupes normalized phone numbers, excludes current user, and maps statuses',
      (tester) async {
        final userController = _FakeUserController(
          currentUser: const User(
            id: 7,
            userId: 'tester',
            name: '테스터',
            phoneNumber: '01099999999',
          ),
          onFindUsersByKeyword: (keyword) async {
            expect(keyword, 'alice');
            return const [
              User(
                id: 7,
                userId: 'tester',
                name: '테스터',
                phoneNumber: '01099999999',
              ),
              User(
                id: 11,
                userId: 'alice',
                name: 'Alice',
                phoneNumber: '010-1111-2222',
              ),
              User(
                id: 12,
                userId: 'alice_clone',
                name: 'Alice Clone',
                phoneNumber: '(010) 1111 2222',
              ),
              User(id: 13, userId: 'bob', name: 'Bob', phoneNumber: ''),
            ];
          },
        );
        final friendController = _FakeFriendController(
          onCheckFriendRelations:
              ({
                required int userId,
                required List<String> phoneNumbers,
              }) async {
                expect(userId, 7);
                return const [
                  FriendCheck(
                    phoneNumber: '01011112222',
                    isFriend: false,
                    status: FriendStatus.pending,
                  ),
                ];
              },
        );

        await tester.pumpWidget(
          _buildTestApp(
            userController: userController,
            friendController: friendController,
          ),
        );
        await tester.pumpAndSettle();

        await _searchById(tester, 'alice');

        expect(userController.searchQueries, ['alice']);
        expect(friendController.requestedBatches, [
          ['01011112222'],
        ]);
        expect(find.text('테스터'), findsNothing);
        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('Alice Clone'), findsOneWidget);
        expect(find.text('Bob'), findsOneWidget);
        expect(find.text('요청됨'), findsNWidgets(2));
        expect(find.text('친구 추가'), findsOneWidget);
      },
    );

    testWidgets('reuses cached search results for the same query', (
      tester,
    ) async {
      final userController = _FakeUserController(
        currentUser: const User(
          id: 7,
          userId: 'tester',
          name: '테스터',
          phoneNumber: '01099999999',
        ),
        onFindUsersByKeyword: (keyword) async {
          expect(keyword, 'chloe');
          return const [
            User(
              id: 20,
              userId: 'chloe',
              name: 'Chloe',
              phoneNumber: '01055556666',
            ),
          ];
        },
      );
      final friendController = _FakeFriendController(
        onCheckFriendRelations:
            ({required int userId, required List<String> phoneNumbers}) async {
              expect(userId, 7);
              return const [
                FriendCheck(
                  phoneNumber: '01055556666',
                  isFriend: true,
                  status: FriendStatus.accepted,
                ),
              ];
            },
      );

      await tester.pumpWidget(
        _buildTestApp(
          userController: userController,
          friendController: friendController,
        ),
      );
      await tester.pumpAndSettle();

      await _searchById(tester, 'chloe');
      expect(userController.searchQueries, ['chloe']);
      expect(friendController.requestedBatches, [
        ['01055556666'],
      ]);
      expect(find.text('Chloe'), findsOneWidget);
      expect(find.text('친구'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      await _searchById(tester, 'chloe');

      expect(userController.searchQueries, ['chloe']);
      expect(friendController.requestedBatches, [
        ['01055556666'],
      ]);
      expect(find.text('Chloe'), findsOneWidget);
      expect(find.text('친구'), findsOneWidget);
    });
  });
}
