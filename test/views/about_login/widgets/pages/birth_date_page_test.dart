import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soi/views/about_login_&_register/widgets/pages/birth_date_page.dart';

class _InMemoryAssetLoader extends AssetLoader {
  const _InMemoryAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    return {
      'register': {'birth_title': '생년월일', 'skip': '건너뛰기'},
    };
  }
}

Widget _buildTestApp({
  required TextEditingController monthController,
  required TextEditingController dayController,
  required TextEditingController yearController,
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
          builder: (_, __) => MaterialApp(
            locale: easyContext.locale,
            supportedLocales: easyContext.supportedLocales,
            localizationsDelegates: easyContext.localizationDelegates,
            home: Scaffold(
              body: BirthDatePage(
                monthController: monthController,
                dayController: dayController,
                yearController: yearController,
                pageController: PageController(),
                onChanged: () {},
                onSkip: () {},
              ),
            ),
          ),
        );
      },
    ),
  );
}

EditableText _editableTextAt(WidgetTester tester, int index) {
  return tester
      .widgetList<EditableText>(find.byType(EditableText))
      .elementAt(index);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('keeps focus within date fields while auto-advancing', (
    tester,
  ) async {
    final monthController = TextEditingController();
    final dayController = TextEditingController();
    final yearController = TextEditingController();

    addTearDown(monthController.dispose);
    addTearDown(dayController.dispose);
    addTearDown(yearController.dispose);

    await tester.pumpWidget(
      _buildTestApp(
        monthController: monthController,
        dayController: dayController,
        yearController: yearController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(_editableTextAt(tester, 0).focusNode.hasFocus, isTrue);

    await tester.enterText(find.byType(TextField).first, '12');
    await tester.pump();
    expect(_editableTextAt(tester, 1).focusNode.hasFocus, isTrue);

    await tester.enterText(find.byType(TextField).at(1), '25');
    await tester.pump();
    expect(_editableTextAt(tester, 2).focusNode.hasFocus, isTrue);
  });
}
