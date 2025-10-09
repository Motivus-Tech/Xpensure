import 'package:flutter/material.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

class RequestHistoryScreen extends StatelessWidget {
  final String employeeName;
  final String requestTitle;
  final List<Map<String, dynamic>> payments;
  final int currentStep;
  final String? status;
  final String? rejectionReason;

  const RequestHistoryScreen({
    super.key,
    required this.employeeName,
    required this.requestTitle,
    required this.payments,
    this.currentStep = 0,
    this.status,
    this.rejectionReason,
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
      final d = p["requestDate"] ?? p["Submittion Date"];
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
      "Account For Final Payment",
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

          // Rejection Reason
          if (status?.toLowerCase() == "rejected" &&
              rejectionReason != null &&
              rejectionReason!.isNotEmpty)
            Card(
              color: Colors.red.withOpacity(0.2),
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
                      "Rejection Reason",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rejectionReason!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (status?.toLowerCase() == "rejected" &&
              rejectionReason != null &&
              rejectionReason!.isNotEmpty)
            const SizedBox(height: 16),

          // Summary
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
                  _summaryRow("Total Payments", "${payments.length}"),
                  _summaryRow(
                    "Total Amount",
                    "₹${totalAmount.toStringAsFixed(2)}",
                  ),
                  _summaryRow("Date of Submission", earliestRequestDate),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Payment Details
          ...payments.map((payment) {
            final requestDate = _parseDate(
                payment["Submittion Date"] ?? payment["requestDate"]);
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

                    // Attachment preview
                    if (attachmentPath != null && attachmentPath.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _buildAttachmentPreview(context, attachmentPath),
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

  /// --- Helper Widgets ---
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

  Widget _buildAttachmentPreview(BuildContext context, String path) {
    final ext = path.split('.').last.toLowerCase();
    final file = File(path);

    // Image attachments
    if (["jpg", "jpeg", "png", "gif"].contains(ext)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Attachment Preview:",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullImageViewer(file: file),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                file,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Text(
                  "Error loading image",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ),
        ],
      );
    }
    // PDF attachments
    else if (ext == "pdf") {
      return InkWell(
        onTap: () async {
          if (await file.exists()) {
            await launchUrl(Uri.file(file.path));
          }
        },
        child: Row(
          children: const [
            Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            SizedBox(width: 6),
            Text(
              "Open PDF Attachment",
              style: TextStyle(
                color: Colors.white70,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      );
    }
    // Other files
    else {
      return InkWell(
        onTap: () async {
          if (await file.exists()) {
            await launchUrl(Uri.file(file.path));
          }
        },
        child: Row(
          children: const [
            Icon(Icons.insert_drive_file, color: Colors.white70),
            SizedBox(width: 6),
            Text(
              "Open Attachment",
              style: TextStyle(
                color: Colors.white70,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      );
    }
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

/// --- Full screen image viewer with download ---
class FullImageViewer extends StatelessWidget {
  final File file;

  const FullImageViewer({super.key, required this.file});

  Future<void> _downloadFile(BuildContext context) async {
    try {
      final downloadsDir = await getApplicationDocumentsDirectory();
      final newFile =
          await file.copy("${downloadsDir.path}/${file.uri.pathSegments.last}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Saved as ${newFile.uri.pathSegments.last}"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Download failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadFile(context),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text("Error loading image",
                style: TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
