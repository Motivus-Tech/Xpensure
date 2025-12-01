import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http; // ADD THIS IMPORT
import 'dart:io';
import 'package:url_launcher/url_launcher_string.dart';

class RequestDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> requestData;
  final String requestType; // "Reimbursement" or "Advance"

  const RequestDetailsScreen({
    super.key,
    required this.requestData,
    required this.requestType,
  });

  // Function to handle file opening
  Future<void> _openAttachment(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await OpenFile.open(file.path);
      } else if (filePath.startsWith('http')) {
        // If it's a URL (for remote files)
        await _downloadAndOpenRemoteFile(filePath);
      } else {
        print('File not found: $filePath');
      }
    } catch (e) {
      print('Error opening file: $e');
    }
  }

  // Function to download and open remote files
  Future<void> _downloadAndOpenRemoteFile(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      final appDocDir = await getApplicationDocumentsDirectory();
      final fileName = url.split('/').last;
      final localFile = File('${appDocDir.path}/$fileName');
      await localFile.writeAsBytes(response.bodyBytes);
      await OpenFile.open(localFile.path);
    } catch (e) {
      print('Error downloading file: $e');
      // Try to open URL directly if download fails
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
      }
    }
  }

  // Updated _buildPaymentCard with better attachment handling
  Widget _buildPaymentCard(Map<String, dynamic> payment, int index) {
    // Get attachment paths
    List<String> attachmentPaths = [];
    if (payment['attachmentPaths'] is List) {
      attachmentPaths = List<String>.from(payment['attachmentPaths'] ?? []);
    } else if (payment['attachmentPath'] is String &&
        payment['attachmentPath'].toString().isNotEmpty) {
      attachmentPaths = [payment['attachmentPath'].toString()];
    }

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

            // Attachments Section
            if (attachmentPaths.isNotEmpty) ...[
              Text(
                "Attachments:",
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: attachmentPaths.map((path) {
                  return _buildAttachmentPreview(path);
                }).toList(),
              ),
              const SizedBox(height: 8),
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

  // Widget to build attachment preview
  Widget _buildAttachmentPreview(String path) {
    final fileName = path.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();

    return InkWell(
      onTap: () => _openAttachment(path),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getFileColor(ext),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getFileIcon(ext),
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 100),
              child: Text(
                fileName.length > 15
                    ? '${fileName.substring(0, 15)}...'
                    : fileName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getFileColor(String ext) {
    switch (ext) {
      case 'pdf':
        return Colors.red.withOpacity(0.8);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.green.withOpacity(0.8);
      case 'doc':
      case 'docx':
        return Colors.blue.withOpacity(0.8);
      case 'xls':
      case 'xlsx':
        return Colors.green.withOpacity(0.8);
      case 'txt':
        return Colors.grey.withOpacity(0.8);
      default:
        return Colors.purple.withOpacity(0.8);
    }
  }

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
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
