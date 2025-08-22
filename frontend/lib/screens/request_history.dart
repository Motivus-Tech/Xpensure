import 'package:flutter/material.dart';

class RequestHistoryScreen extends StatelessWidget {
  final String employeeName;
  final String requestTitle;
  final List<Map<String, dynamic>> payments;

  const RequestHistoryScreen({
    super.key,
    required this.employeeName,
    required this.requestTitle,
    required this.payments,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F222B),
        title: Text(requestTitle, style: const TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              "Employee: $employeeName",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ...payments.asMap().entries.map((entry) {
              final index = entry.key;
              final payment = entry.value;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F222B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Payment #${index + 1}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Payment Date: ${payment['paymentDate'] != null ? "${payment['paymentDate'].day}-${payment['paymentDate'].month}-${payment['paymentDate'].year}" : "Not selected"}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Amount: ₹${payment['amount'] ?? 0}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Claim Type: ${payment['claimType'] ?? "-"}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Description: ${payment['description'] ?? "-"}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "User: ${payment['user'] ?? "-"}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    if (payment['attachment'] != null)
                      Text(
                        "Attachment: ${payment['attachment'].split('/').last}",
                        style: const TextStyle(color: Colors.white70),
                      )
                    else
                      const Text(
                        "No attachment",
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
