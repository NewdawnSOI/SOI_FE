import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soi/api/controller/contact_controller.dart';
import 'package:soi/api/controller/friend_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/friend.dart';
import 'package:soi/api/models/friend_check.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/friend_service.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi/views/about_friends/widgets/friend_suggest_card.dart';
import 'package:soi_api_client/api.dart';

class _InMemoryAssetLoader extends AssetLoader {
  const _InMemoryAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    return {
      'friends': {
        'suggest': {
          'loading': '불러오는 중',
          'pending': '요청됨',
          'add': '추가',
          'empty': '추천할 친구가 없습니다.',
          'no_name': '이름 없음',
          'no_contacts': '연락처가 없습니다.',
          'enable_sync': '연락처 동기화를 활성화해주세요.',
          'request_sent': '{name}님에게 요청을 보냈습니다.',
          'invite_sms_sent': '{name}님에게 초대 문자를 보냈습니다.',
          'sms_message': '{link}',
        },
      },
    };
  }
}

class _NoopAuthApi extends AuthControllerApi {}

class _NoopUserApi extends UserAPIApi {}

class _NoopFriendApi extends FriendAPIApi {}

class _FakeContactController extends ContactController {
  _FakeContactController({required this.enabled});

  final bool enabled;

  @override
  bool get contactSyncEnabled => enabled;
}

class _FakeUserController extends UserController {
  _FakeUserController({User? currentUser})
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
  }) {
    requestedBatches.add(List<String>.from(phoneNumbers));
    return onCheckFriendRelations(userId: userId, phoneNumbers: phoneNumbers);
  }
}

Contact _buildContact({
  required String displayName,
  required List<String> phoneNumbers,
}) {
  return Contact(
    displayName: displayName,
    phones: phoneNumbers.map((phone) => Phone(phone)).toList(growable: false),
  );
}

Widget _buildTestApp({
  required List<Contact> contacts,
  required _FakeFriendController friendController,
  ContactController? contactController,
  UserController? userController,
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
              ChangeNotifierProvider<ContactController>.value(
                value:
                    contactController ?? _FakeContactController(enabled: true),
              ),
              ChangeNotifierProvider<FriendController>.value(
                value: friendController,
              ),
              ChangeNotifierProvider<UserController>.value(
                value:
                    userController ??
                    _FakeUserController(
                      currentUser: const User(
                        id: 7,
                        userId: 'tester',
                        name: '테스터',
                        phoneNumber: '01099999999',
                      ),
                    ),
              ),
            ],
            child: MaterialApp(
              locale: easyContext.locale,
              supportedLocales: easyContext.supportedLocales,
              localizationsDelegates: easyContext.localizationDelegates,
              home: Scaffold(
                body: Center(
                  child: FriendSuggestCard(
                    scale: 1,
                    isInitializing: false,
                    contacts: contacts,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('FriendSuggestCard', () {
    testWidgets(
      'dedupes contacts, skips empty phones, and hides accepted friends',
      (tester) async {
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
                    isFriend: true,
                    status: FriendStatus.accepted,
                  ),
                ];
              },
        );

        await tester.pumpWidget(
          _buildTestApp(
            contacts: [
              _buildContact(
                displayName: 'Alice',
                phoneNumbers: ['010-1111-2222'],
              ),
              _buildContact(
                displayName: 'Alice Clone',
                phoneNumbers: ['01011112222'],
              ),
              _buildContact(displayName: 'No Phone', phoneNumbers: const []),
              _buildContact(
                displayName: 'Bob',
                phoneNumbers: ['010-3333-4444'],
              ),
            ],
            friendController: friendController,
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(friendController.requestedBatches, hasLength(1));
        expect(friendController.requestedBatches.single, [
          '01011112222',
          '01033334444',
        ]);
        expect(find.text('Alice'), findsNothing);
        expect(find.text('Alice Clone'), findsNothing);
        expect(find.text('No Phone'), findsNothing);
        expect(find.text('Bob'), findsOneWidget);
      },
    );

    testWidgets('limits initial friend status loading to warmup batch size', (
      tester,
    ) async {
      final friendController = _FakeFriendController(
        onCheckFriendRelations:
            ({required int userId, required List<String> phoneNumbers}) async =>
                const <FriendCheck>[],
      );

      final contacts = List<Contact>.generate(20, (index) {
        final suffix = index.toString().padLeft(4, '0');
        return _buildContact(
          displayName: 'User $index',
          phoneNumbers: ['010-55$suffix-${suffix.substring(0, 4)}'],
        );
      });

      await tester.pumpWidget(
        _buildTestApp(contacts: contacts, friendController: friendController),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(friendController.requestedBatches, isNotEmpty);
      expect(friendController.requestedBatches.first.length, 12);
      expect(friendController.requestedBatches.first.length, lessThan(20));
    });
  });
}
