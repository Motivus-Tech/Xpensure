import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart'; // fixed import
import 'dart:io';

class RequestDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> requestData;
  final String requestType; // "Reimbursement" or "Advance"

  const RequestDetailsScreen({
    super.key,
    required this.requestData,
    required this.requestType,
  });

  Widget _buildPaymentCard(Map<String, dynamic> payment, int index) {
    return Card(
      color: const Color(0xFF1F1F1F),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Payment ${index + 1}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            if (requestType == "Reimbursement") ...[
              Text(
                "Payment Date: ${payment['paymentDate'] != null ? payment['paymentDate'].toString().split(' ')[0] : '-'}",
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                "Claim Type: ${payment['claimType'] ?? '-'}",
                style: const TextStyle(color: Colors.white70),
              ),
            ] else if (requestType == "Advance") ...[
              Text(
                "Request Date: ${payment['requestDate'] != null ? payment['requestDate'].toString().split(' ')[0] : '-'}",
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                "Project Date: ${payment['projectDate'] != null ? payment['projectDate'].toString().split(' ')[0] : '-'}",
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              "Amount: ${payment['amount'] ?? '-'}",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              requestType == "Reimbursement"
                  ? "Description: ${payment['description'] ?? '-'}"
                  : "Particulars: ${payment['particulars'] ?? '-'}",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            if (payment['attachmentPath'] != null) ...[
              InkWell(
                onTap: () async {
                  final path = payment['attachmentPath'];
                  if (path != null) await launchUrlString(path);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Open Attachment",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ] else
              const Text(
                "No Attachment",
                style: TextStyle(color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List payments = requestData['payments'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        title: Text("$requestType Details"),
        backgroundColor: const Color.fromARGB(255, 148, 99, 233),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Project ID: ${requestData['projectId'] ?? '-'}",
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (requestType == "Reimbursement")
            Text(
              "Reimbursement Date: ${requestData['reimbursementDate'] != null ? requestData['reimbursementDate'].toString().split(' ')[0] : '-'}",
              style: const TextStyle(color: Colors.white70),
            ),
          const SizedBox(height: 8),
          Text(
            "Status: ${requestData['status'] ?? '-'}",
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(
            payments.length,
            (index) => _buildPaymentCard(
              payments[index] as Map<String, dynamic>,
              index,
            ),
          ),
        ],
      ),
    );
  }
}
