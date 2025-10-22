import 'dart:convert';
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'login_screen.dart';
import 'background_sync_service.dart'; // ✅ new
import 'scan_attendance_page.dart'; // your home page

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Start background sync service
  BackgroundSyncService().start();
  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();


  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GMPL App',
      debugShowCheckedModeBanner: false,
      home: const StartupPage(),
    );
  }
}


class StartupPage extends StatefulWidget {
  const StartupPage({super.key});
  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('isLoggedIn') ?? false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
            loggedIn ? HomePage() : const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

