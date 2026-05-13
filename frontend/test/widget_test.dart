// Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

import 'package:flutter_test/flutter_test.dart';

import 'package:tt_match_manager/main.dart';
import 'package:tt_match_manager/services/api_client.dart';
import 'package:tt_match_manager/services/auth_state.dart';

void main() {
  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    final api = ApiClient();
    final auth = AuthState(api);

    await tester.pumpWidget(TtMatchManagerApp(api: api, auth: auth));

    expect(find.text('TT-Match-Manager'), findsOneWidget);
    expect(find.text('Anmelden'), findsOneWidget);
  });
}
