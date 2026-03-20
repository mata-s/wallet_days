import 'package:flutter/material.dart';
import 'package:saiyome/screens/home_page.dart';
import 'package:saiyome/models/isar_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IsarService.init();
  runApp(const SaiyomeApp());
}

class SaiyomeApp extends StatelessWidget {
  const SaiyomeApp({super.key});

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
      home: const HomePage(),
    );
  }
}
