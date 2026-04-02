import 'package:flutter/material.dart';
import 'package:saiyome/screens/welcome_page.dart';
import 'package:saiyome/screens/home_page.dart';
import 'package:saiyome/models/isar_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const initializationSettings = InitializationSettings(
    android: androidSettings,
    iOS: darwinSettings,
    macOS: darwinSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );
  await initSupabase();
  await IsarService.init();
  runApp(const SaiyomeApp());
}

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: 'https://jiukghmczjaeqhvcocos.supabase.co',
    anonKey: 'sb_publishable_yZkcbxLEzOpok9nfRay8Cg_BNcnRnLr',
  );
}

Future<void> signInAnonymouslyIfNeeded() async {
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession != null) return;

  debugPrint('[RevenueCatDebug] No current session. Signing in anonymously...');
  await auth.signInAnonymously();
  final signedInUser = auth.currentUser;
  debugPrint(
    '[RevenueCatDebug] Anonymous sign-in completed. userId=${signedInUser?.id}, isAnonymous=${signedInUser?.isAnonymous}',
  );
}

Future<void> ensureProfileExists() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return;

  await client.from('profiles').upsert({
    'id': user.id,
    'updated_at': DateTime.now().toIso8601String(),
  });
}

Future<void> initRevenueCat() async {
  // RevenueCatのiOS Public SDK Key
  const iosApiKey = 'appl_fWfmyhRwBvLnYUArWEdrKtyyFkB';
  // const androidApiKey = 'goog_your_android_public_sdk_key';

  final configuration = PurchasesConfiguration(
    iosApiKey,
  );

  debugPrint('[RevenueCatDebug] Configuring RevenueCat...');
  await Purchases.configure(configuration);
  debugPrint('[RevenueCatDebug] RevenueCat configured.');

  final supabaseUser = Supabase.instance.client.auth.currentUser;
  debugPrint(
    '[RevenueCatDebug] Current Supabase user before Purchases.logIn: userId=${supabaseUser?.id}, isAnonymous=${supabaseUser?.isAnonymous}',
  );

  if (supabaseUser != null) {
    debugPrint(
      '[RevenueCatDebug] Calling Purchases.logIn with userId=${supabaseUser.id}',
    );
    final loginResult = await Purchases.logIn(supabaseUser.id);
    debugPrint(
      '[RevenueCatDebug] Purchases.logIn completed. created=${loginResult.created}, appUserId=${loginResult.customerInfo.originalAppUserId}',
    );
    final customerInfo = loginResult.customerInfo;
    final isPremium = customerInfo.entitlements.active.containsKey('premium');
    debugPrint(
      '[RevenueCatDebug] Subscription status after logIn: isPremium=$isPremium, activeEntitlements=${customerInfo.entitlements.active.keys.toList()}',
    );
  } else {
    debugPrint('[RevenueCatDebug] Skipped Purchases.logIn because Supabase user is null.');
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium = customerInfo.entitlements.active.containsKey('premium');
      debugPrint(
        '[RevenueCatDebug] Subscription status without logIn: isPremium=$isPremium, appUserId=${customerInfo.originalAppUserId}, activeEntitlements=${customerInfo.entitlements.active.keys.toList()}',
      );
    } catch (e) {
      debugPrint('[RevenueCatDebug] Failed to fetch subscription status without logIn: $e');
    }
  }

  try {
    final customerInfo = await Purchases.getCustomerInfo();
    final isPremium = customerInfo.entitlements.active.containsKey('premium');
    debugPrint(
      '[RevenueCatDebug] Final subscription status: isPremium=$isPremium, appUserId=${customerInfo.originalAppUserId}, activeEntitlements=${customerInfo.entitlements.active.keys.toList()}',
    );
  } catch (e) {
    debugPrint('[RevenueCatDebug] Failed to fetch final subscription status: $e');
  }
  // デバッグログ（必要なら）
  await Purchases.setLogLevel(LogLevel.debug);
}

class SaiyomeApp extends StatefulWidget {
  const SaiyomeApp({super.key});

  @override
  State<SaiyomeApp> createState() => _SaiyomeAppState();
}

class _SaiyomeAppState extends State<SaiyomeApp> {
  String? _initializedUserId;
  Future<void>? _setupFuture;

  Future<void> _ensureUserSetup(User user) {
    if (_initializedUserId == user.id && _setupFuture != null) {
      return _setupFuture!;
    }

    _initializedUserId = user.id;
    debugPrint('[AppStart] User already logged in → init & HomePage');

    _setupFuture = () async {
      await ensureProfileExists();
      await initRevenueCat();
    }();

    return _setupFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '財布の余命',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF8A65)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF8F4),
      ),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        initialData: AuthState(
          AuthChangeEvent.initialSession,
          Supabase.instance.client.auth.currentSession,
        ),
        builder: (context, snapshot) {
          final session = snapshot.data?.session;
          final user = session?.user;

          if (user == null) {
            _initializedUserId = null;
            _setupFuture = null;
            debugPrint('[AppStart] No user → WelcomePage');
            return const WelcomePage();
          }

          return FutureBuilder<void>(
            future: _ensureUserSetup(user),
            builder: (context, setupSnapshot) {
              if (setupSnapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (setupSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '初期化に失敗しました。アプリを再起動してください。\n${setupSnapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }

              return const HomePage();
            },
          );
        },
      ),
    );
  }
}
