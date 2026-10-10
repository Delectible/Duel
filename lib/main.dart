import 'package:flutter/material.dart';

import 'core/app_info.dart';
import 'features/home/home_screen.dart';

void main() => runApp(const DuelApp());

class DuelApp extends StatelessWidget {
  const DuelApp({super.key});

  /// Card-table green.
  static const felt = Color(0xFF0B2E23);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: felt, brightness: Brightness.dark),
        scaffoldBackgroundColor: felt,
      ),
      home: const HomeScreen(),
    );
  }
}
