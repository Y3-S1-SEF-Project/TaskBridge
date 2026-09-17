import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/auth/data/auth_api.dart';
import 'package:mobile_app/auth/data/auth_models.dart';
import 'package:mobile_app/auth/pages/login_page.dart';
import 'package:mobile_app/auth/widgets/auth_input.dart';
import 'package:mobile_app/core/theme/app_palette.dart';
import 'package:mobile_app/core/widgets/design_system.dart';
import 'package:mobile_app/home/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthApi extends AuthApi {
  int logins = 0;

  @override
  Future<({bool isNewUser, AuthUser user})> login(String identifier, String password) async {
    logins++;
    return (
      isNewUser: false,
      user: const AuthUser(
        id: 'test-id',
        fullName: 'Kavindu Alwis',
        email: 'kavindu@example.com',
        phone: '0771234567',
      ),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Phone validation accepts local/international numbers and rejects landlines', () {
    expect(AuthValidation.phone('077 123 4567'), isNull);
    expect(AuthValidation.phone('+94 77 123 4567'), isNull);
    expect(AuthValidation.phone('0111234567'), isNotNull);
    expect(AuthValidation.phone(''), isNotNull);
  });

  test('Password validation enforces length and both character classes', () {
    expect(AuthValidation.password('LongPassword7'), isNull);
    expect(AuthValidation.password('Pass1234'), isNull);
    expect(AuthValidation.password('short7'), isNotNull);
    expect(AuthValidation.password('abcdefghijk'), isNotNull);
    expect(AuthValidation.password('12345678901'), isNotNull);
  });

  test('Email validation accepts valid emails and rejects invalid formats', () {
    expect(AuthValidation.email('user@example.com'), isNull);
    expect(AuthValidation.email('test.user@domain.co'), isNull);
    expect(AuthValidation.email('invalid-email'), isNotNull);
    expect(AuthValidation.email(''), isNotNull);
  });

  testWidgets('Invalid login never calls the API; valid login navigates to HomePage', (tester) async {
    final api = FakeAuthApi();
    addTearDown(api.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [AppPalette.light]),
      home: LoginPage(api: api),
    ));

    await tester.ensureVisible(find.widgetWithText(AppButton, 'Login'));
    await tester.tap(find.widgetWithText(AppButton, 'Login'));
    await tester.pump();
    expect(api.logins, 0);

    await tester.enterText(find.byType(TextFormField).at(0), 'kavindu@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'LongPassword7');
    await tester.ensureVisible(find.widgetWithText(AppButton, 'Login'));
    await tester.tap(find.widgetWithText(AppButton, 'Login'));
    await tester.pumpAndSettle();

    expect(api.logins, 1);
    expect(find.byType(HomePage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
