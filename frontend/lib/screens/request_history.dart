import 'package:flutter/material.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class RequestHistoryScreen extends StatelessWidget {
  final String employeeName;
  final String requestTitle;
  final List<Map<String, dynamic>> payments;
  final int currentStep;

  const RequestHistoryScreen({
    super.key,
    required this.employeeName,
    required this.requestTitle,
    required this.payments,
    this.currentStep = 0,
  });

  double get totalAmount {
    double sum = 0;
    for (var p in payments) {
      sum += double.tryParse(p["amount"]?.toString() ?? "0") ?? 0;
    }
    return sum;
  }

  String get earliestRequestDate {
    if (payments.isEmpty) return "-";
    List<DateTime> dates = payments.map((p) {
      final d = p["requestDate"];
      if (d is DateTime) return d;
      if (d is String) {
        try {
          return DateTime.parse(d);
        } catch (_) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }).toList();
    dates.sort((a, b) => a.compareTo(b));
    DateTime earliest = dates.first;
    return "${earliest.year}-${earliest.month.toString().padLeft(2, '0')}-${earliest.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    List<String> steps = [
      "RM",
      "NOH",
      "COO",
      "Account Verification",
      "CEO",
      "Account Disbursement",
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F222B),
        title: Text(requestTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stepper Card
          Card(
            color: const Color(0xFF1F1F1F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Request Progress",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Stepper(
                    physics: const ClampingScrollPhysics(),
                    currentStep: currentStep,
                    controlsBuilder: (_, __) => const SizedBox.shrink(),
                    steps: steps.map((s) {
                      int index = steps.indexOf(s);
                      return Step(
                        title: Text(
                          s,
                          style: TextStyle(
                            color: index <= currentStep
                                ? Colors.greenAccent
                                : Colors.white70,
                            fontWeight: index == currentStep
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        content: const SizedBox.shrink(),
                        isActive: index <= currentStep,
                        state: index < currentStep
                            ? StepState.complete
                            : index == currentStep
                            ? StepState.editing
                            : StepState.indexed,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Summary Card
          Card(
            color: const Color(0xFF1F1F1F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Request Summary",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _summaryRow("Employee", employeeName),
                  _summaryRow("Total Payments", "${payments.length}"),
                  _summaryRow(
                    "Total Amount",
                    "₹${totalAmount.toStringAsFixed(2)}",
                  ),
                  _summaryRow("Earliest Date", earliestRequestDate),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Payment Details
          ...payments.map((payment) {
            final requestDate = _parseDate(payment["requestDate"]);
            final projectDate = _parseDate(payment["projectDate"]);
            final amountStr = payment["amount"]?.toString() ?? "0";
            final particularsStr =
                payment["description"] ?? payment["particulars"] ?? "-";
            final attachmentPath = payment["attachmentPath"]?.toString();

            return Card(
              color: const Color(0xFF1F1F1F),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Payment Details",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _detailText(
                            "Request Date",
                            "${requestDate.year}-${requestDate.month.toString().padLeft(2, '0')}-${requestDate.day.toString().padLeft(2, '0')}",
                          ),
                        ),
                        Expanded(
                          child: _detailText(
                            "Project Date",
                            "${projectDate.year}-${projectDate.month.toString().padLeft(2, '0')}-${projectDate.day.toString().padLeft(2, '0')}",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _detailText("Amount", "₹$amountStr"),
                    const SizedBox(height: 6),
                    _detailText("Particulars", particularsStr),
                    if (attachmentPath != null && attachmentPath.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: InkWell(
                          onTap: () async {
                            final file = File(attachmentPath);
                            if (await file.exists()) {
                              await launchUrl(Uri.file(file.path));
                            }
                          },
                          child: Row(
                            children: const [
                              Icon(
                                Icons.attach_file,
                                color: Colors.white70,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "View Attachment",
                                style: TextStyle(
                                  color: Colors.white70,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _summaryRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "$title:",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailText(String label, String value) {
    return Text(
      "$label: $value",
      style: const TextStyle(color: Colors.white70, fontSize: 14),
    );
  }

  DateTime _parseDate(dynamic d) {
    if (d is DateTime) return d;
    if (d is String) {
      try {
        return DateTime.parse(d);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }
}
