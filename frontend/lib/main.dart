import 'package:flutter/material.dart'; // Core Ui
import 'screens/role_selection.dart'; // role selection screen

void main() {
  runApp(const XpensureApp());
}

class XpensureApp extends StatelessWidget {
  const XpensureApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xpensure',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const RoleSelection(), // load your role selection screen
    );
  }
}
