import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE', null);
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  final api = ApiClient(baseUrl: baseUrl);
  final auth = AuthState(api);
  await auth.init();

  runApp(TtMatchManagerApp(api: api, auth: auth));
}

class TtMatchManagerApp extends StatelessWidget {
  const TtMatchManagerApp({required this.api, required this.auth, super.key});

  final ApiClient api;
  final AuthState auth;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<AuthState>.value(value: auth),
      ],
      child: MaterialApp(
        title: 'TT-Match-Manager',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return auth.isLoggedIn ? const DashboardScreen() : const LoginScreen();
  }
}
