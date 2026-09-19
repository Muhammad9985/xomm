import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization exception (fallback to local mode): $e');
  }
  runApp(const XommApp());
}

class XommApp extends StatelessWidget {
  const XommApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xomm - HD Video Meetings',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
