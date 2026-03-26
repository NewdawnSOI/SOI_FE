library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soi/api/controller/comment_controller.dart';
import 'package:soi/api/controller/friend_controller.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/controller/post_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/comment.dart';
import 'package:soi/api/models/friend.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/comment_service.dart';
import 'package:soi/api/services/friend_service.dart';
import 'package:soi/api/services/media_service.dart';
import 'package:soi/api/services/post_service.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi/views/about_feed/manager/feed_data_manager.dart';
import 'package:soi/views/about_profile/profile_page.dart';
import 'package:soi/views/about_profile/widgets/profile_main_tab_views.dart';
import 'package:soi_api_client/api.dart';

class _InMemoryAssetLoader extends AssetLoader {
  const _InMemoryAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    return {
      'profile': {
        'main': {
          'friends_count': '친구 {count}',
          'tabs': {'media': '미디어', 'text': '텍스트', 'comments': '댓글'},
          'empty_media': '아직 미디어 게시물이 없습니다.',
          'empty_text': '아직 텍스트 게시물이 없습니다.',
          'empty_comments': '아직 댓글이 없습니다.',
          'load_failed': '콘텐츠를 불러오지 못했습니다.',
        },
      },
      'common': {
        'retry': '다시 시도',
        'login_required': '로그인이 필요합니다.',
        'user_info_unavailable': '사용자 정보를 불러올 수 없습니다.',
        'unknown': '알 수 없음',
        'block_success': '차단되었습니다.',
        'block_failed': '차단에 실패했습니다.',
        'report': '신고',
        'block': '차단',
      },
      'comments': {
        'reply_action': '답장 달기',
        'view_more_replies': '+ 답글 {count}개 더 보기',
        'hide_replies': '답글 숨기기',
        'add_comment': '댓글을 입력하세요',
        'save_failed': '댓글 저장에 실패했습니다.',
      },
    };
  }
}

class _NoopAuthApi extends AuthControllerApi {}

class _NoopUserApi extends UserAPIApi {}

class _NoopPostApi extends PostAPIApi {}

class _NoopCommentApi extends CommentAPIApi {}

class _NoopFriendApi extends FriendAPIApi {}

class _NoopMediaApi extends APIApi {}

class _FakePostController extends PostController {
  _FakePostController({required this.posts, this.overrideErrorMessage})
    : super(postService: PostService(postApi: _NoopPostApi()));

  final List<Post> posts;
  final String? overrideErrorMessage;

  @override
  String? get errorMessage => overrideErrorMessage;

  @override
  Future<({List<Post> posts, bool hasMore})> getMediaByUserId({
    required int userId,
    required PostType postType,
    int page = 0,
  }) async {
    final filtered = posts
        .where((post) => post.postType == postType)
        .toList(growable: false);
    return (posts: filtered, hasMore: false);
  }
}

class _FakeCommentController extends CommentController {
  _FakeCommentController({
    required this.comments,
    this.childCommentsByParentId = const <int, List<Comment>>{},
    this.overrideErrorMessage,
  }) : super(commentService: CommentService(commentApi: _NoopCommentApi()));

  final List<Comment> comments;
  final Map<int, List<Comment>> childCommentsByParentId;
  final String? overrideErrorMessage;

  @override
  String? get errorMessage => overrideErrorMessage;

  @override
  Future<({List<Comment> comments, bool hasMore})> getCommentsByUserId({
    required int userId,
    int page = 0,
  }) async => (comments: comments, hasMore: false);

  /// 프로필 댓글 탭이 부모 댓글별 대댓글을 다시 조회할 수 있도록 고정 응답을 제공합니다.
  @override
  Future<({List<Comment> comments, bool hasMore})> getChildComments({
    required int parentCommentId,
    int page = 0,
  }) async => (
    comments: childCommentsByParentId[parentCommentId] ?? const <Comment>[],
    hasMore: false,
  );
}

class _FakeUserController extends UserController {
  _FakeUserController({User? currentUser, this.loadedUser})
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

  final User? loadedUser;

  @override
  Future<User?> getUser(int id) async => loadedUser ?? currentUser;
}

class _FakeFriendController extends FriendController {
  _FakeFriendController({this.friends = const <User>[]})
    : super(friendService: FriendService(friendApi: _NoopFriendApi()));

  final List<User> friends;

  @override
  Future<List<User>> getAllFriends({
    required int userId,
    FriendStatus status = FriendStatus.accepted,
    bool forceRefresh = false,
  }) async => friends;
}

class _FakeMediaController extends MediaController {
  _FakeMediaController({Map<String, String?> urls = const <String, String?>{}})
    : _urls = urls,
      super(mediaService: MediaService(mediaApi: _NoopMediaApi()));

  final Map<String, String?> _urls;

  @override
  String? peekPresignedUrl(String key) => _urls[key];

  @override
  Future<String?> getPresignedUrl(String key) async => _urls[key];
}

class _NoopMediaController extends _FakeMediaController {}

const _fakeUserId = 99;
const _fakeUserIdStr = 'testuser';

final _fakeUser = User(
  id: _fakeUserId,
  userId: _fakeUserIdStr,
  name: '테스트 유저',
  phoneNumber: '01099999999',
);

final _fakeFriends = [
  const User(
    id: 201,
    userId: 'friend_1',
    name: '친구 1',
    phoneNumber: '01011111111',
  ),
  const User(
    id: 202,
    userId: 'friend_2',
    name: '친구 2',
    phoneNumber: '01022222222',
  ),
];

final _fakeMediaPosts = [
  Post(
    id: 1,
    nickName: _fakeUserIdStr,
    postFileKey: 'media/photo1.jpg',
    postFileUrl: 'https://example.com/photo1.jpg',
    postType: PostType.multiMedia,
    createdAt: DateTime(2025, 1, 1),
    commentCount: 3,
  ),
  Post(
    id: 2,
    nickName: _fakeUserIdStr,
    postFileKey: 'media/photo2.jpg',
    postFileUrl: 'https://example.com/photo2.jpg',
    postType: PostType.multiMedia,
    createdAt: DateTime(2025, 1, 2),
    commentCount: 0,
  ),
];

final _fakeTextPosts = [
  Post(
    id: 10,
    nickName: _fakeUserIdStr,
    content: '안녕하세요! 오늘은 정말 좋은 날씨입니다.',
    postType: PostType.textOnly,
    createdAt: DateTime(2025, 2, 1),
    commentCount: 1,
  ),
  Post(
    id: 11,
    nickName: _fakeUserIdStr,
    content: '짧은 텍스트',
    postType: PostType.textOnly,
    createdAt: DateTime(2025, 2, 2),
    commentCount: 0,
  ),
  Post(
    id: 12,
    nickName: _fakeUserIdStr,
    content:
        '긴 텍스트 게시물입니다. 여러 줄에 걸쳐 내용이 이어지고, '
        '카드의 높이가 텍스트 길이에 따라 달라지는 지 확인합니다. '
        '잘 렌더링되는지 확인해 보세요.',
    postType: PostType.textOnly,
    createdAt: DateTime(2025, 2, 3),
    commentCount: 5,
  ),
];

final _fakeComments = [
  Comment(
    id: 100,
    userId: _fakeUserId,
    nickname: _fakeUserIdStr,
    text: '정말 멋진 사진이네요!',
    type: CommentType.text,
    createdAt: DateTime(2025, 3, 1),
  ),
  Comment(
    id: 101,
    userId: _fakeUserId,
    nickname: _fakeUserIdStr,
    text: '두 번째 댓글입니다.',
    type: CommentType.text,
    createdAt: DateTime(2025, 3, 2),
  ),
  Comment(
    id: 102,
    userId: _fakeUserId,
    nickname: _fakeUserIdStr,
    text: '대댓글도 확인합니다.',
    type: CommentType.reply,
    createdAt: DateTime(2025, 3, 3),
  ),
];

Widget _buildHarness({
  required Widget child,
  UserController? userController,
  FriendController? friendController,
  MediaController? mediaController,
  PostController? postController,
  CommentController? commentController,
}) {
  final resolvedUserController =
      userController ??
      _FakeUserController(currentUser: _fakeUser, loadedUser: _fakeUser);
  final resolvedFriendController = friendController ?? _FakeFriendController();
  final resolvedMediaController = mediaController ?? _NoopMediaController();
  final resolvedPostController =
      postController ?? _FakePostController(posts: const <Post>[]);
  final resolvedCommentController =
      commentController ?? _FakeCommentController(comments: const <Comment>[]);

  return EasyLocalization(
    supportedLocales: const [Locale('ko')],
    path: 'assets/translations',
    fallbackLocale: const Locale('ko'),
    assetLoader: const _InMemoryAssetLoader(),
    child: Builder(
      builder: (easyCtx) => ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, __) => MultiProvider(
          providers: [
            ChangeNotifierProvider<UserController>.value(
              value: resolvedUserController,
            ),
            ChangeNotifierProvider<FriendController>.value(
              value: resolvedFriendController,
            ),
            ChangeNotifierProvider<MediaController>.value(
              value: resolvedMediaController,
            ),
            ChangeNotifierProvider<PostController>.value(
              value: resolvedPostController,
            ),
            ChangeNotifierProvider<CommentController>.value(
              value: resolvedCommentController,
            ),
            ChangeNotifierProvider<FeedDataManager>(
              create: (_) => FeedDataManager(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: easyCtx.localizationDelegates,
            supportedLocales: easyCtx.supportedLocales,
            locale: easyCtx.locale,
            home: Scaffold(backgroundColor: Colors.black, body: child),
          ),
        ),
      ),
    ),
  );
}

Finder _findBlackColoredBox() {
  return find.byWidgetPredicate(
    (widget) => widget is ColoredBox && widget.color == Colors.black,
    description: 'a black ColoredBox placeholder',
  );
}

Future<void> _pumpWithImages(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpNoImages(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _setPhoneSurface(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(393, 852);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('ProfilePostTabView (미디어 탭)', () {
    testWidgets('게시물이 있으면 MasonryGridView가 렌더링된다', (tester) async {
      final postCtrl = _FakePostController(
        posts: [..._fakeMediaPosts, ..._fakeTextPosts],
      );

      await tester.pumpWidget(
        _buildHarness(
          postController: postCtrl,
          commentController: _FakeCommentController(
            comments: const <Comment>[],
          ),
          child: ProfilePostTabView(
            key: const ValueKey('media_tab'),
            userId: _fakeUserId,
            postType: PostType.multiMedia,
            isActive: true,
            detailTitle: '미디어',
            emptyMessageKey: 'profile.main.empty_media',
          ),
        ),
      );
      await _pumpWithImages(tester);

      expect(find.byType(MasonryGridView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('isActive=false이면 초기에 검정 배경만 표시된다', (tester) async {
      final postCtrl = _FakePostController(posts: _fakeMediaPosts);

      await tester.pumpWidget(
        _buildHarness(
          postController: postCtrl,
          commentController: _FakeCommentController(
            comments: const <Comment>[],
          ),
          child: const ProfilePostTabView(
            userId: _fakeUserId,
            postType: PostType.multiMedia,
            isActive: false,
            detailTitle: '미디어',
            emptyMessageKey: 'profile.main.empty_media',
          ),
        ),
      );
      await _pumpNoImages(tester);

      expect(find.byType(MasonryGridView), findsNothing);
      expect(_findBlackColoredBox(), findsOneWidget);
    });

    testWidgets('게시물이 없으면 RefreshIndicator가 렌더링된다', (tester) async {
      final postCtrl = _FakePostController(posts: const <Post>[]);

      await tester.pumpWidget(
        _buildHarness(
          postController: postCtrl,
          commentController: _FakeCommentController(
            comments: const <Comment>[],
          ),
          child: ProfilePostTabView(
            userId: _fakeUserId,
            postType: PostType.multiMedia,
            isActive: true,
            detailTitle: '미디어',
            emptyMessageKey: 'profile.main.empty_media',
          ),
        ),
      );
      await _pumpNoImages(tester);

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('불러오기에 실패하면 에러 상태와 재시도 버튼을 표시한다', (tester) async {
      final postCtrl = _FakePostController(
        posts: const <Post>[],
        overrideErrorMessage: '게시물 조회 실패',
      );

      await tester.pumpWidget(
        _buildHarness(
          postController: postCtrl,
          commentController: _FakeCommentController(
            comments: const <Comment>[],
          ),
          child: ProfilePostTabView(
            userId: _fakeUserId,
            postType: PostType.multiMedia,
            isActive: true,
            detailTitle: '미디어',
            emptyMessageKey: 'profile.main.empty_media',
          ),
        ),
      );
      await _pumpNoImages(tester);

      expect(find.text('콘텐츠를 불러오지 못했습니다.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('userId가 null이면 빈 상태 메시지를 표시한다', (tester) async {
      final postCtrl = _FakePostController(posts: _fakeMediaPosts);

      await tester.pumpWidget(
        _buildHarness(
          postController: postCtrl,
          commentController: _FakeCommentController(
            comments: const <Comment>[],
          ),
          child: ProfilePostTabView(
            userId: null,
            postType: PostType.multiMedia,
            isActive: true,
            detailTitle: '미디어',
            emptyMessageKey: 'profile.main.empty_media',
          ),
        ),
      );
      await _pumpNoImages(tester);

      expect(find.text('아직 미디어 게시물이 없습니다.'), findsOneWidget);
    });

    testWidgets('중복 게시물은 하나만 렌더링된다', (tester) async {
      final duplicatePost = Post(
        id: 1,
        nickName: _fakeUserIdStr,
        postFileKey: 'media/photo1_dup.jpg',
        postFileUrl: 'https://example.com/photo1_dup.jpg',
        postType: PostType.multiMedia,
        createdAt: DateTime(2025, 1, 1),
        commentCount: 0,
      );
      final postCtrl = _FakePostController(
        posts: [..._fakeMediaPosts, duplicatePost],
      );

      await tester.pumpWidget(
        _buildHarness(
          postController: postCtrl,
          commentController: _FakeCommentController(
            comments: const <Comment>[],
          ),
          child: ProfilePostTabView(
            key: const ValueKey('dedup_test'),
            userId: _fakeUserId,
            postType: PostType.multiMedia,
            isActive: true,
            detailTitle: '미디어',
            emptyMessageKey: 'profile.main.empty_media',
          ),
        ),
      );
      await _pumpWithImages(tester);

      expect(
        find.byKey(const ValueKey('profile_post_multiMedia_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('profile_post_multiMedia_2')),
        findsOneWidget,
      );
    });
  });

  group('ProfilePostTabView (텍스트 탭)', () {
    testWidgets('텍스트 게시물이 있으면 MasonryGridView가 렌더링된다', (tester) async {
      final postCtrl = _FakePostController(
        posts: [..._fakeMediaPosts, ..._fakeTextPosts],
      );

      await tester.pumpWidget(
        _buildHarness(
          postController: postCtrl,
          commentController: _FakeCommentController(
            comments: const <Comment>[],
          ),
          child: ProfilePostTabView(
            key: const ValueKey('text_tab'),
            userId: _fakeUserId,
            postType: PostType.textOnly,
            isActive: true,
            detailTitle: '텍스트',
            emptyMessageKey: 'profile.main.empty_text',
          ),
        ),
      );
      await _pumpNoImages(tester);

      expect(find.byType(MasonryGridView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('텍스트 길이가 다른 카드들이 예외 없이 렌더링된다', (tester) async {
      final postCtrl = _FakePostController(posts: _fakeTextPosts);

      await tester.pumpWidget(
        _buildHarness(
          postController: postCtrl,
          commentController: _FakeCommentController(
            comments: const <Comment>[],
          ),
          child: ProfilePostTabView(
            userId: _fakeUserId,
            postType: PostType.textOnly,
            isActive: true,
            detailTitle: '텍스트',
            emptyMessageKey: 'profile.main.empty_text',
          ),
        ),
      );
      await _pumpNoImages(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('텍스트 게시물이 없으면 빈 상태 메시지를 표시한다', (tester) async {
      final postCtrl = _FakePostController(posts: const <Post>[]);

      await tester.pumpWidget(
        _buildHarness(
          postController: postCtrl,
          commentController: _FakeCommentController(
            comments: const <Comment>[],
          ),
          child: ProfilePostTabView(
            userId: _fakeUserId,
            postType: PostType.textOnly,
            isActive: true,
            detailTitle: '텍스트',
            emptyMessageKey: 'profile.main.empty_text',
          ),
        ),
      );
      await _pumpNoImages(tester);

      expect(find.text('아직 텍스트 게시물이 없습니다.'), findsOneWidget);
    });
  });

  group('ProfileCommentTabView (댓글 탭)', () {
    testWidgets('댓글이 있으면 ListView가 렌더링된다', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          postController: _FakePostController(posts: const <Post>[]),
          commentController: _FakeCommentController(comments: _fakeComments),
          child: ProfileCommentTabView(
            key: const ValueKey('comment_tab'),
            userId: _fakeUserId,
            isActive: true,
            emptyMessageKey: 'profile.main.empty_comments',
          ),
        ),
      );
      await _pumpNoImages(tester);

      expect(find.byType(ListView), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('댓글 텍스트 내용이 화면에 표시된다', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          postController: _FakePostController(posts: const <Post>[]),
          commentController: _FakeCommentController(comments: _fakeComments),
          child: ProfileCommentTabView(
            userId: _fakeUserId,
            isActive: true,
            emptyMessageKey: 'profile.main.empty_comments',
          ),
        ),
      );
      await _pumpNoImages(tester);

      expect(find.text('정말 멋진 사진이네요!'), findsOneWidget);
      expect(find.text('두 번째 댓글입니다.'), findsOneWidget);
    });

    testWidgets('댓글이 없으면 RefreshIndicator가 렌더링된다', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          postController: _FakePostController(posts: const <Post>[]),
          commentController: _FakeCommentController(
            comments: const <Comment>[],
          ),
          child: ProfileCommentTabView(
            userId: _fakeUserId,
            isActive: true,
            emptyMessageKey: 'profile.main.empty_comments',
          ),
        ),
      );
      await _pumpNoImages(tester);

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('isActive=false이면 초기에 검정 배경만 표시된다', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          postController: _FakePostController(posts: const <Post>[]),
          commentController: _FakeCommentController(comments: _fakeComments),
          child: ProfileCommentTabView(
            userId: _fakeUserId,
            isActive: false,
            emptyMessageKey: 'profile.main.empty_comments',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ListView), findsNothing);
      expect(_findBlackColoredBox(), findsOneWidget);
    });

    testWidgets('불러오기에 실패하면 에러 상태와 재시도 버튼을 표시한다', (tester) async {
      final commentCtrl = _FakeCommentController(
        comments: const <Comment>[],
        overrideErrorMessage: '댓글 조회 실패',
      );

      await tester.pumpWidget(
        _buildHarness(
          postController: _FakePostController(posts: const <Post>[]),
          commentController: commentCtrl,
          child: ProfileCommentTabView(
            userId: _fakeUserId,
            isActive: true,
            emptyMessageKey: 'profile.main.empty_comments',
          ),
        ),
      );
      await _pumpNoImages(tester);

      expect(find.text('콘텐츠를 불러오지 못했습니다.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('userId가 null이면 빈 상태 메시지를 표시한다', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          postController: _FakePostController(posts: const <Post>[]),
          commentController: _FakeCommentController(comments: _fakeComments),
          child: ProfileCommentTabView(
            userId: null,
            isActive: true,
            emptyMessageKey: 'profile.main.empty_comments',
          ),
        ),
      );
      await _pumpNoImages(tester);

      expect(find.text('아직 댓글이 없습니다.'), findsOneWidget);
    });

    testWidgets('중복 댓글은 하나만 렌더링된다', (tester) async {
      final duplicateComments = [
        ..._fakeComments,
        Comment(
          id: 100,
          userId: _fakeUserId,
          nickname: _fakeUserIdStr,
          text: '정말 멋진 사진이네요!',
          type: CommentType.text,
          createdAt: DateTime(2025, 3, 1),
        ),
      ];

      await tester.pumpWidget(
        _buildHarness(
          postController: _FakePostController(posts: const <Post>[]),
          commentController: _FakeCommentController(
            comments: duplicateComments,
          ),
          child: ProfileCommentTabView(
            key: const ValueKey('comment_dedup_test'),
            userId: _fakeUserId,
            isActive: true,
            emptyMessageKey: 'profile.main.empty_comments',
          ),
        ),
      );
      await _pumpNoImages(tester);

      expect(find.text('정말 멋진 사진이네요!'), findsOneWidget);
    });

    testWidgets('원댓글과 대댓글을 부모-자식 스레드로 묶어 표시한다', (tester) async {
      final threadedCommentController = _FakeCommentController(
        comments: _fakeComments,
        childCommentsByParentId: {
          100: [
            Comment(
              id: 102,
              userId: _fakeUserId,
              nickname: _fakeUserIdStr,
              text: '대댓글도 확인합니다.',
              replyUserName: '원댓글 작성자',
              type: CommentType.reply,
              createdAt: DateTime(2025, 3, 3),
            ),
          ],
        },
      );

      await tester.pumpWidget(
        _buildHarness(
          postController: _FakePostController(posts: const <Post>[]),
          commentController: threadedCommentController,
          child: ProfileCommentTabView(
            userId: _fakeUserId,
            isActive: true,
            emptyMessageKey: 'profile.main.empty_comments',
          ),
        ),
      );
      await _pumpNoImages(tester);

      expect(find.text('정말 멋진 사진이네요!'), findsOneWidget);
      expect(find.text('대댓글도 확인합니다.'), findsOneWidget);
    });
  });

  group('ProfilePage', () {
    testWidgets('기본 미디어 탭을 표시하고 탭 전환 시 각 콘텐츠를 로드한다', (tester) async {
      await _setPhoneSurface(tester);
      await tester.pumpWidget(
        _buildHarness(
          userController: _FakeUserController(
            currentUser: _fakeUser,
            loadedUser: _fakeUser,
          ),
          friendController: _FakeFriendController(friends: _fakeFriends),
          mediaController: _NoopMediaController(),
          postController: _FakePostController(
            posts: [..._fakeMediaPosts, ..._fakeTextPosts],
          ),
          commentController: _FakeCommentController(comments: _fakeComments),
          child: const ProfilePage(),
        ),
      );
      await _pumpWithImages(tester);

      expect(find.text('@testuser'), findsOneWidget);
      expect(find.text('친구 2'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile_post_multiMedia_2')),
        findsOneWidget,
      );

      await tester.tap(find.text('텍스트'));
      await _pumpWithImages(tester);

      expect(
        find.byKey(const ValueKey('profile_post_textOnly_12')),
        findsOneWidget,
      );

      await tester.tap(find.text('댓글'));
      await _pumpWithImages(tester);

      expect(find.text('정말 멋진 사진이네요!'), findsOneWidget);
    });

    testWidgets('로그인 사용자가 없으면 로그인 필요 메시지를 표시한다', (tester) async {
      await _setPhoneSurface(tester);
      await tester.pumpWidget(
        _buildHarness(
          userController: _FakeUserController(
            currentUser: null,
            loadedUser: null,
          ),
          child: const ProfilePage(),
        ),
      );
      await _pumpNoImages(tester);

      expect(find.text('로그인이 필요합니다.'), findsOneWidget);
    });
  });
}
