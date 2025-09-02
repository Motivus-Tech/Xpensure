import 'package:flutter/material.dart';

class CEODashboard extends StatelessWidget {
  const CEODashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CEO Dashboard"),
        backgroundColor: const Color(0xFF1A237E),
      ),
      body: const Center(
        child: Text(
          "Welcome CEO!",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
