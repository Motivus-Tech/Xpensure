import 'package:flutter/material.dart';

class RequestHistoryScreen extends StatelessWidget {
  final String employeeName;
  final String requestTitle;
  final int amount;
  final String description;

  const RequestHistoryScreen({
    super.key,
    required this.employeeName,
    required this.requestTitle,
    required this.amount,
    required this.description,
  });

  Widget _infoCard(String label, String value, {Gradient? gradient}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: gradient,
        color: gradient == null ? const Color(0xFF2C2F38) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F222B),
        elevation: 0,
        title: Text(
          requestTitle,
          style: TextStyle(
            color: Colors.grey[300],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _infoCard(
            "Employee",
            employeeName,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFC196CC), Color(0xFF849CFC)],
            ),
          ),
          _infoCard(
            "Amount",
            "₹$amount",
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7E57C2), Color(0xFFE1BEE7)],
            ),
          ),
          _infoCard(
            "Description",
            description,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF26A69A), Color(0xFFA5D6A7)],
            ),
          ),
          _infoCard(
            "Status",
            "Pending", // You can update dynamically based on type
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE57373), Color(0xFFFFB74D)],
            ),
          ),
        ],
      ),
    );
  }
}
