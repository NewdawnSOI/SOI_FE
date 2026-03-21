import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/controller/contact_controller.dart';
import 'package:soi/api/services/contact_repository.dart';
import 'package:soi/api/services/contact_service.dart';

class _FakeContactRepository extends ContactRepository {
  _FakeContactRepository({
    this.onLoadContactSyncSetting,
    this.onSaveContactSyncSetting,
    this.onRequestContactPermission,
    this.onGetContacts,
  });

  final Future<bool> Function()? onLoadContactSyncSetting;
  final Future<void> Function(bool value)? onSaveContactSyncSetting;
  final Future<bool> Function({bool readonly})? onRequestContactPermission;
  final Future<List<Contact>> Function()? onGetContacts;

  @override
  Future<bool> loadContactSyncSetting() async {
    return onLoadContactSyncSetting?.call() ?? false;
  }

  @override
  Future<void> saveContactSyncSetting(bool value) async {
    final handler = onSaveContactSyncSetting;
    if (handler == null) {
      return;
    }

    await handler(value);
  }

  @override
  Future<bool> requestContactPermission({bool readonly = true}) async {
    final handler = onRequestContactPermission;
    if (handler == null) {
      return false;
    }

    return handler(readonly: readonly);
  }

  @override
  Future<List<Contact>> getContacts() async {
    final handler = onGetContacts;
    if (handler == null) {
      throw UnimplementedError('onGetContacts is not configured');
    }

    return handler();
  }
}

void main() {
  group('ContactController', () {
    test(
      'updates sync state and returns contacts from injected service',
      () async {
        final contacts = [
          Contact(
            id: '1',
            displayName: 'Alice',
            phones: [Phone('010-1234-5678')],
          ),
        ];
        var notifyCount = 0;

        final controller = ContactController(
          contactService: ContactService(
            repository: _FakeContactRepository(
              onRequestContactPermission: ({bool readonly = true}) async =>
                  true,
              onGetContacts: () async => contacts,
            ),
          ),
        );
        controller.addListener(() {
          notifyCount++;
        });

        final initResult = await controller.initializeContactPermission();
        final loadedContacts = await controller.getContacts();

        expect(initResult.isEnabled, isTrue);
        expect(controller.contactSyncEnabled, isTrue);
        expect(controller.isLoading, isFalse);
        expect(loadedContacts, hasLength(1));
        expect(loadedContacts.single.displayName, 'Alice');
        expect(notifyCount, greaterThanOrEqualTo(2));
      },
    );
  });
}
