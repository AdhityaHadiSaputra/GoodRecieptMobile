import 'package:flutter/material.dart';
import 'package:metrox_po/main_layout.dart';
import 'package:metrox_po/models/db_helper.dart';
import 'package:metrox_po/screens/dashboard.dart';
import 'package:device_info_plus/device_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensures Flutter is fully initialized
  final DatabaseHelper db = DatabaseHelper(); // Initialize DatabaseHelper

  // Perform any database setup or checks if needed
  await db.checkTable(); // Ensure the table is created if not exists

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const Authpage(), // Ensure `AuthPage` is defined
        '/main': (context) => const MainLayout(), // Ensure `MainLayout` is defined
      },
    );
  } 
}
