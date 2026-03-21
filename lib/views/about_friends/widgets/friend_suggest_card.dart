import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/contact_controller.dart';
import 'package:soi/utils/snackbar_utils.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../api/controller/friend_controller.dart';
import '../../../api/controller/user_controller.dart';

/// 친구 추천 카드
/// 연락처 동기화가 활성화된 경우, 연락처 목록에서 SOI 사용자들을 추천합니다.
class FriendSuggestCard extends StatefulWidget {
  final double scale;
  final bool isInitializing;
  final List<Contact> contacts;

  const FriendSuggestCard({
    super.key,
    required this.scale,
    required this.isInitializing,
    required this.contacts,
  });

  @override
  State<FriendSuggestCard> createState() => _FriendSuggestCardState();
}

class _FriendSuggestCardState extends State<FriendSuggestCard> {
  /// 상태 로드 요청을 배치로 처리하기 위한 디바운스 시간
  /// 디바운스 시간이란, 특정 이벤트가 연속적으로 발생할 때, 마지막 이벤트가 발생한 후 일정 시간 동안 추가 이벤트가 발생하지 않을 때까지 기다렸다가 하나의 작업을 수행하는 기법입니다.
  /// 이를 통해 불필요한 작업 수행을 줄이고 성능을 향상시킬 수 있습니다.
  static const int _batchDebounceMs = 100;
  static const int _initialStatusWarmupCount = 10; // 초기 로드 시 상태를 미리 확인할 연락처 수
  static const int _maxStatusBatchSize = 10; // 한 번에 상태를 확인할 최대 전화번호 수
  static const int _maxVisibleTileCount = 8; // 최대 표시할 연락처 항목 수 (카드 높이 제한)

  /// 전화번호 -> 친구 상태 매핑
  /// 상태값: 'none', 'pending', 'accepted', 'blocked', 'loading'
  final Map<String, String> _friendshipStatuses = <String, String>{};

  /// 상태 로드 대기 중인 전화번호 목록
  final Set<String> _pendingPhoneNumbers = <String>{};

  List<_FriendSuggestContactEntry> _preparedContacts =
      const <_FriendSuggestContactEntry>[];
  List<_FriendSuggestContactEntry> _displayContacts =
      const <_FriendSuggestContactEntry>[];

  /// 현재 로드 중인지 여부
  bool _isLoadingBatch = false;

  /// Debounce 타이머
  Timer? _debounceTimer;

  UserController? _userController;
  FriendController? _friendController;

  @override
  void initState() {
    super.initState();
    _rebuildContactEntries();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userController ??= Provider.of<UserController>(context, listen: false);
    _friendController ??= Provider.of<FriendController>(context, listen: false);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(FriendSuggestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contacts != widget.contacts) {
      _resetContactState();
    }
  }

  void _resetContactState() {
    _debounceTimer?.cancel();
    _pendingPhoneNumbers.clear();
    _friendshipStatuses.clear();
    _isLoadingBatch = false;
    _rebuildContactEntries(notify: true);
  }

  void _rebuildContactEntries({bool notify = false}) {
    final nextPreparedContacts = _prepareContacts(widget.contacts);
    final nextDisplayContacts = _buildDisplayContacts(
      contacts: nextPreparedContacts,
    );

    if (notify && mounted) {
      setState(() {
        _preparedContacts = nextPreparedContacts;
        _displayContacts = nextDisplayContacts;
      });
    } else {
      _preparedContacts = nextPreparedContacts;
      _displayContacts = nextDisplayContacts;
    }

    _scheduleInitialStatusWarmup();
  }

  List<_FriendSuggestContactEntry> _prepareContacts(List<Contact> contacts) {
    final seenPhoneNumbers = <String>{};
    final preparedContacts = <_FriendSuggestContactEntry>[];

    for (final contact in contacts) {
      final phoneNumber = _extractPrimaryPhoneNumber(contact);
      if (phoneNumber == null) {
        continue;
      }

      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      if (normalizedPhone.isEmpty || !seenPhoneNumbers.add(normalizedPhone)) {
        continue;
      }

      final displayName = contact.displayName.trim();
      preparedContacts.add(
        _FriendSuggestContactEntry(
          normalizedPhone: normalizedPhone,
          phoneNumber: phoneNumber,
          displayName: displayName,
        ),
      );
    }

    return List<_FriendSuggestContactEntry>.unmodifiable(preparedContacts);
  }

  String? _extractPrimaryPhoneNumber(Contact contact) {
    for (final phone in contact.phones) {
      final trimmedNumber = phone.number.trim();
      if (trimmedNumber.isNotEmpty) {
        return trimmedNumber;
      }
    }
    return null;
  }

  List<_FriendSuggestContactEntry> _buildDisplayContacts({
    List<_FriendSuggestContactEntry>? contacts,
  }) {
    final sourceContacts = contacts ?? _preparedContacts;
    return sourceContacts
        .where((contact) {
          final status = _friendshipStatuses[contact.normalizedPhone];
          return status != 'accepted' && status != 'blocked';
        })
        .toList(growable: false);
  }

  void _scheduleInitialStatusWarmup() {
    if (_displayContacts.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final warmupCount = math.min(
        _displayContacts.length,
        _initialStatusWarmupCount,
      );

      for (final contact in _displayContacts.take(warmupCount)) {
        _requestStatusLoad(contact.normalizedPhone);
      }
    });
  }

  /// 특정 전화번호의 상태 로드 요청
  void _requestStatusLoad(String phoneNumber) {
    if (_friendshipStatuses.containsKey(phoneNumber) ||
        _pendingPhoneNumbers.contains(phoneNumber)) {
      return;
    }

    _pendingPhoneNumbers.add(phoneNumber);

    _debounceTimer?.cancel();

    // 디바운스 타이머를 설정하여 일정 시간 동안 추가 요청이 없으면 상태 로드를 수행합니다.
    _debounceTimer = Timer(
      const Duration(milliseconds: _batchDebounceMs),
      _flushPendingStatusLoad,
    );
  }

  /// 대기 중인 전화번호들의 상태를 배치로 로드
  Future<void> _flushPendingStatusLoad() async {
    if (_pendingPhoneNumbers.isEmpty || _isLoadingBatch) {
      return;
    }

    final phoneNumbersToLoad = _takePendingPhoneNumbers(_maxStatusBatchSize);
    if (phoneNumbersToLoad.isEmpty) {
      return;
    }

    _isLoadingBatch = true;

    if (mounted) {
      setState(() {
        for (final phone in phoneNumbersToLoad) {
          _friendshipStatuses[phone] = 'loading';
        }
      });
    }

    try {
      final currentUserId = _userController?.currentUser?.id;
      final friendController = _friendController;
      if (currentUserId == null || friendController == null) {
        _applyFriendshipStatuses(phoneNumbersToLoad, const <String, String>{});
        return;
      }

      final relations = await friendController.checkFriendRelations(
        userId: currentUserId,
        phoneNumbers: phoneNumbersToLoad,
      );

      final nextStatuses = <String, String>{};
      for (final relation in relations) {
        final normalizedPhone = _normalizePhoneNumber(relation.phoneNumber);
        if (normalizedPhone.isEmpty) {
          continue;
        }
        nextStatuses[normalizedPhone] = relation.statusString;
      }

      _applyFriendshipStatuses(phoneNumbersToLoad, nextStatuses);
    } catch (e) {
      debugPrint('친구 관계 확인 실패: $e');
      _applyFriendshipStatuses(phoneNumbersToLoad, const <String, String>{});
    } finally {
      _isLoadingBatch = false;

      if (_pendingPhoneNumbers.isNotEmpty) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(
          const Duration(milliseconds: _batchDebounceMs),
          _flushPendingStatusLoad,
        );
      }
    }
  }

  List<String> _takePendingPhoneNumbers(int count) {
    final selectedPhoneNumbers = <String>[];
    for (final phoneNumber in _pendingPhoneNumbers) {
      selectedPhoneNumbers.add(phoneNumber);
      if (selectedPhoneNumbers.length >= count) {
        break;
      }
    }

    for (final phoneNumber in selectedPhoneNumbers) {
      _pendingPhoneNumbers.remove(phoneNumber);
    }

    return selectedPhoneNumbers;
  }

  void _applyFriendshipStatuses(
    List<String> requestedPhoneNumbers,
    Map<String, String> nextStatuses,
  ) {
    if (!mounted) {
      return;
    }

    setState(() {
      for (final phoneNumber in requestedPhoneNumbers) {
        _friendshipStatuses[phoneNumber] = nextStatuses[phoneNumber] ?? 'none';
      }
      _displayContacts = _buildDisplayContacts();
    });
  }

  /// 전화번호 정규화 (공백, 하이픈 제거)
  String _normalizePhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  String _statusForContact(_FriendSuggestContactEntry contact) {
    final status = _friendshipStatuses[contact.normalizedPhone];
    if (status == null) {
      _requestStatusLoad(contact.normalizedPhone);
      return 'loading';
    }
    return status;
  }

  void _refreshFriendshipStatuses() {
    if (!mounted) {
      return;
    }

    setState(() {
      _friendshipStatuses.clear();
      _pendingPhoneNumbers.clear();
      _displayContacts = _buildDisplayContacts();
    });

    _scheduleInitialStatusWarmup();
  }

  /// 친구 추가 처리 (API 사용)
  ///
  /// FriendController.addFriend를 호출하여 친구 추가 요청을 보냅니다.
  /// - 성공 시: 친구 요청이 전송됨 (status: PENDING)
  /// - 실패 시 (null 반환): 상대방이 SOI 사용자가 아님 → SMS로 앱 설치 안내
  Future<void> _handleAddFriend(_FriendSuggestContactEntry contact) async {
    final currentUserId = _userController?.currentUser?.id;
    final friendController = _friendController;
    if (currentUserId == null || friendController == null) {
      debugPrint('로그인된 사용자가 없습니다.');
      return;
    }

    final result = await friendController.addFriend(
      requesterId: currentUserId,
      receiverPhoneNum: contact.phoneNumber,
    );

    if (result == null) {
      await _sendAppInviteSms(contact);
    } else {
      debugPrint('친구 요청 성공: ${result.id}');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          tr(
            'friends.suggest.request_sent',
            context: context,
            namedArgs: {'name': contact.displayName},
          ),
        );
      }
    }

    _refreshFriendshipStatuses();
  }

  /// SMS로 앱 설치 안내 전송
  Future<void> _sendAppInviteSms(_FriendSuggestContactEntry contact) async {
    const appInstallLink = 'https://soi-sns.web.app';
    final user = _userController?.currentUser;
    final link = user == null
        ? appInstallLink
        : Uri.parse(appInstallLink)
              .replace(
                queryParameters: {
                  'refUserId': user.id.toString(),
                  'refNickname': user.userId,
                },
              )
              .toString();
    final message = tr(
      'friends.suggest.sms_message',
      context: context,
      namedArgs: {'link': link},
    );

    final encodedMessage = Uri.encodeComponent(message);
    final uri = Uri.parse('sms:${contact.phoneNumber}?body=$encodedMessage');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            tr(
              'friends.suggest.invite_sms_sent',
              context: context,
              namedArgs: {'name': contact.displayName},
            ),
          );
        }
      } else {
        debugPrint('SMS 앱을 열 수 없습니다.');
      }
    } catch (e) {
      debugPrint('SMS 전송 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Selector + 고정 높이 ListView.separated로 가상화 했다.
    // 그래서 카드가 처음부터 모든 ListTile을 다 만들지 않고,
    // 실제 보이는 구간 위주로만 빌드하면서 스크롤할 때 다음 항목을 처리하게 된다.
    return Selector<ContactController, bool>(
      selector: (_, contactController) => contactController.contactSyncEnabled,
      builder: (context, contactSyncEnabled, child) {
        return SizedBox(
          width: 354.w,

          child: Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            color: const Color(0xff1c1c1c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildContent(context, contactSyncEnabled),
          ),
        );
      },
    );
  }

  Widget? _buildFriendButton(
    _FriendSuggestContactEntry contact,
    String status,
  ) {
    switch (status) {
      case 'loading':
        return SizedBox(
          width: 20.w,
          height: 20.h,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xff666666),
          ),
        );
      case 'pending':
        return _buildButton(
          text: tr('friends.suggest.pending', context: context),
          isEnabled: false,
          backgroundColor: const Color(0xff666666),
          textColor: const Color(0xffd9d9d9),
          onPressed: null,
        );
      case 'accepted':
      case 'blocked':
        return null;
      case 'none':
      default:
        return _buildButton(
          text: tr('friends.suggest.add', context: context),
          isEnabled: true,
          backgroundColor: const Color(0xfff9f9f9),
          textColor: const Color(0xff1c1c1c),
          onPressed: () async {
            await _handleAddFriend(contact);
          },
        );
    }
  }

  Widget _buildButton({
    required String text,
    required bool isEnabled,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: isEnabled ? onPressed : null,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(backgroundColor),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        alignment: Alignment.center,
      ),
      clipBehavior: Clip.none,
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.visible,
        softWrap: false,
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 카드 콘텐츠 빌드
  /// - 연락처 동기화가 활성화된 경우: 연락처 목록에서 SOI 사용자들을 추천하는 리스트를 보여줍니다.
  /// - 연락처 동기화가 비활성화된 경우: 연락처 동기화 활성화를 유도하는 메시지를 보여줍니다.
  /// - 초기 로딩 중인 경우: 로딩 인디케이터와 함께 "로딩 중" 메시지를 보여줍니다
  Widget _buildContent(BuildContext context, bool contactSyncEnabled) {
    if (widget.isInitializing) {
      return Container(
        padding: EdgeInsets.all(40.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 로딩 인디케이터
            SizedBox(
              width: 24.w,
              height: 24.h,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xfff9f9f9),
              ),
            ),
            SizedBox(height: 16.h), // 로딩 인디케이터와 텍스트 사이의 간격
            // 로딩 텍스트
            Text(
              tr('friends.suggest.loading', context: context),
              style: TextStyle(color: const Color(0xff666666), fontSize: 14.sp),
            ),
          ],
        ),
      );
    }

    if (contactSyncEnabled && _displayContacts.isNotEmpty) {
      // 연락처 동기화가 활성화되어 있고, 추천할 연락처가 있는 경우 연락처 리스트를 보여줍니다.
      return _buildVirtualizedContactList(context);
    }

    // 연락처 동기화가 비활성화되어 있거나, 추천할 연락처가 없는 경우에는 안내 메시지를 보여줍니다.
    return Container(
      padding: EdgeInsets.all(20.sp),
      child: Center(
        child: Text(
          contactSyncEnabled
              ? tr('friends.suggest.no_contacts', context: context)
              : tr('friends.suggest.enable_sync', context: context),
          style: TextStyle(color: const Color(0xff666666), fontSize: 14.sp),
        ),
      ),
    );
  }

  /// 연락처 리스트를 가상화하여 빌드하는 위젯
  /// - ListView.separated를 사용하여 스크롤 가능한 리스트를 만들고, 실제로 보이는 항목들만 빌드하도록 최적화합니다.
  /// - 각 항목은 연락처 정보와 친구 추가 버튼을 포함하는 ListTile로 구성됩니다.
  ///
  /// Parameter:
  /// - [context]: 빌드 컨텍스트
  ///
  /// Returns:
  /// - [Widget]: 연락처 리스트를 가상화하여 빌드한 위젯
  Widget _buildVirtualizedContactList(BuildContext context) {
    final visibleTileCount = math.min(
      _displayContacts.length,
      _maxVisibleTileCount,
    );
    final listHeight = visibleTileCount <= 0
        ? 120.h
        : (visibleTileCount * 72).h + 16.h;

    return SizedBox(
      height: listHeight,
      child: ListView.separated(
        key: const ValueKey('friend_suggest_list'),
        primary: false,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        physics: const ClampingScrollPhysics(),
        cacheExtent: 0,
        itemCount: _displayContacts.length,
        separatorBuilder: (_, __) => Divider(
          height: 1.h,
          color: const Color(0xff2a2a2a),
          indent: 68.w,
          endIndent: 16.w,
        ),
        itemBuilder: (context, index) {
          final contact = _displayContacts[index];
          final status = _statusForContact(contact);
          return _buildContactTile(context, contact, status);
        },
      ),
    );
  }

  /// 연락처 항목을 빌드하는 위젯
  /// - 연락처의 이름, 전화번호, 친구 상태에 따른 버튼을 포함하는 ListTile을 반환합니다.
  /// - 친구 상태에 따라 버튼의 텍스트와 활성화 여부가 달라집니다.
  /// - 친구 상태가 'accepted' 또는 'blocked'인 경우에는 버튼이 표시되지 않습니다.
  /// - 친구 상태가 'loading'인 경우에는 로딩 인디케이터가 표시됩니다.
  /// - 친구 상태가 'pending'인 경우에는 "요청 중" 버튼이 비활성화되어 표시됩니다.
  /// - 친구 상태가 'none'인 경우에는 "추가" 버튼이 활성화되어 표시됩니다.
  ///
  /// Parameter:
  /// - [context]: 빌드 컨텍스트
  /// - [contact]: 연락처 정보가 담긴 _FriendSuggestContactEntry 객체
  /// - [status]: 해당 연락처의 친구 상태 ('none', 'pending', 'accepted', 'blocked', 'loading')
  ///
  /// Returns:
  /// - [Widget]: 연락처 항목을 빌드한 ListTile 위젯
  Widget _buildContactTile(
    BuildContext context,
    _FriendSuggestContactEntry contact,
    String status,
  ) {
    return ListTile(
      key: ValueKey(contact.normalizedPhone),
      minLeadingWidth: 0,
      leading: CircleAvatar(
        backgroundColor: const Color(0xff323232),
        child: Text(
          contact.initial,
          style: TextStyle(
            color: const Color(0xfff9f9f9),
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        contact.displayName.isNotEmpty
            ? contact.displayName
            : tr('friends.suggest.no_name', context: context),
        style: const TextStyle(
          color: Color(0xFFD9D9D9),
          fontSize: 16,
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w400,
        ),
      ),
      subtitle: Text(
        contact.phoneNumber,
        style: const TextStyle(
          color: Color(0xFFD9D9D9),
          fontSize: 10,
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w300,
        ),
      ),
      trailing: SizedBox(
        width: 84.w,
        height: 29.h,
        child: _buildFriendButton(contact, status),
      ),
    );
  }
}

class _FriendSuggestContactEntry {
  const _FriendSuggestContactEntry({
    required this.normalizedPhone,
    required this.phoneNumber,
    required this.displayName,
  });

  final String normalizedPhone;
  final String phoneNumber;
  final String displayName;

  String get initial =>
      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
}
