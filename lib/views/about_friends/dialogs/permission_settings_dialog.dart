import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class PermissionSettingsDialog {
  static void show(BuildContext context, VoidCallback onOpenSettings) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xff1c1c1c),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'friends.options.contact_sync_disabled_title'.tr(),
            style: TextStyle(
              color: Color(0xfff9f9f9),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'friends.options.contact_sync_disabled_description'.tr(),
            style: TextStyle(color: Color(0xffd9d9d9)),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'common.cancel'.tr(),
                style: TextStyle(color: Color(0xff666666)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                onOpenSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff404040),
                foregroundColor: Colors.white,
              ),
              child: Text('friends.options.open_settings'.tr()),
            ),
          ],
        );
      },
    );
  }
}
