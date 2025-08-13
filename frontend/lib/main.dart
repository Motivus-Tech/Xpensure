import 'package:flutter/material.dart';
import 'screens/role_selection.dart'; // Correct path

void main() {
  runApp(const XpensureApp());
}

class XpensureApp extends StatelessWidget {
  const XpensureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xpensure - Expense Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const RoleSelection(), // show role selection first
    );
  }
}
