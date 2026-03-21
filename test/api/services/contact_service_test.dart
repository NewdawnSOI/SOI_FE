import 'dart:async';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/services/contact_repository.dart';
import 'package:soi/api/services/contact_service.dart';

class _FakeContactRepository extends ContactRepository {
  _FakeContactRepository({
    this.onLoadContactSyncSetting,
    this.onSaveContactSyncSetting,
    this.onRequestContactPermission,
    this.onGetContacts,
    this.onGetContact,
    this.onSearchContacts,
  });

  final Future<bool> Function()? onLoadContactSyncSetting;
  final Future<void> Function(bool value)? onSaveContactSyncSetting;
  final Future<bool> Function({bool readonly})? onRequestContactPermission;
  final Future<List<Contact>> Function()? onGetContacts;
  final Future<Contact?> Function(String id)? onGetContact;
  final Future<List<Contact>> Function(String query)? onSearchContacts;

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

  @override
  Future<Contact?> getContact(String id) async {
    final handler = onGetContact;
    if (handler == null) {
      throw UnimplementedError('onGetContact is not configured');
    }

    return handler(id);
  }

  @override
  Future<List<Contact>> searchContacts(String query) async {
    final handler = onSearchContacts;
    if (handler == null) {
      throw UnimplementedError('onSearchContacts is not configured');
    }

    return handler(query);
  }
}

Contact _buildContact({
  required String id,
  required String displayName,
  required List<String> phoneNumbers,
}) {
  return Contact(
    id: id,
    displayName: displayName,
    phones: phoneNumbers.map((phone) => Phone(phone)).toList(growable: false),
  );
}

void main() {
  group('ContactService', () {
    test(
      'dedupes in-flight contact loads and reuses cached contacts',
      () async {
        final contactsCompleter = Completer<List<Contact>>();
        var getContactsCallCount = 0;
        bool? capturedReadonly;

        final service = ContactService(
          repository: _FakeContactRepository(
            onRequestContactPermission: ({bool readonly = true}) async {
              capturedReadonly = readonly;
              return true;
            },
            onGetContacts: () {
              getContactsCallCount++;
              return contactsCompleter.future;
            },
          ),
        );

        final initResult = await service.initializeContactPermission();
        expect(initResult.isEnabled, isTrue);
        expect(capturedReadonly, isTrue);

        final firstLoad = service.getContacts();
        final secondLoad = service.getContacts();

        contactsCompleter.complete([
          _buildContact(
            id: '1',
            displayName: 'Alice',
            phoneNumbers: ['010-1111-2222'],
          ),
        ]);

        final firstContacts = await firstLoad;
        final secondContacts = await secondLoad;
        final cachedContacts = await service.getContacts();

        expect(getContactsCallCount, 1);
        expect(firstContacts, same(secondContacts));
        expect(cachedContacts, same(firstContacts));
        expect(firstContacts.single.displayName, 'Alice');
      },
    );

    test(
      'searches cached contacts and refreshes cache on forceRefresh',
      () async {
        var getContactsCallCount = 0;
        var repositorySearchCallCount = 0;

        final service = ContactService(
          repository: _FakeContactRepository(
            onRequestContactPermission: ({bool readonly = true}) async => true,
            onGetContacts: () async {
              getContactsCallCount++;
              if (getContactsCallCount == 1) {
                return [
                  _buildContact(
                    id: '1',
                    displayName: 'Alice',
                    phoneNumbers: ['010-1111-2222'],
                  ),
                ];
              }

              return [
                _buildContact(
                  id: '2',
                  displayName: 'Bob',
                  phoneNumbers: ['010-3333-4444'],
                ),
              ];
            },
            onSearchContacts: (query) async {
              repositorySearchCallCount++;
              return const <Contact>[];
            },
          ),
        );

        await service.initializeContactPermission();

        final initialSearch = await service.searchContacts('11112222');
        final refreshedContacts = await service.getContacts(forceRefresh: true);
        final refreshedSearch = await service.searchContacts('3333');

        expect(getContactsCallCount, 2);
        expect(repositorySearchCallCount, 0);
        expect(initialSearch.single.displayName, 'Alice');
        expect(refreshedContacts.single.displayName, 'Bob');
        expect(refreshedSearch.single.displayName, 'Bob');
      },
    );
  });
}
