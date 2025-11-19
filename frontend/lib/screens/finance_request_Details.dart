import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../models/finance_request.dart';
import '../utils/date_formatter.dart';

class FinanceRequestDetails extends StatefulWidget {
  final FinanceRequest request;
  final String authToken;
  final bool isPaymentTab;

  const FinanceRequestDetails({
    super.key,
    required this.request,
    required this.authToken,
    required this.isPaymentTab,
  });

  @override
  State<FinanceRequestDetails> createState() => _FinanceRequestDetailsState();
}

class _FinanceRequestDetailsState extends State<FinanceRequestDetails> {
  final ApiService apiService = ApiService();
  bool _isProcessing = false;
  final String baseUrl = "http://10.0.2.2:8000";

  // Helper methods for amount handling
  double _parseAmount(dynamic amount) {
    if (amount is double) return amount;
    if (amount is int) return amount.toDouble();
    if (amount is String) return double.tryParse(amount) ?? 0.0;
    return 0.0;
  }

  String _formatAmount(dynamic amount) {
    final parsedAmount = _parseAmount(amount);
    return parsedAmount.toStringAsFixed(2);
  }

  // Helper methods for attachments
  String _getFileName(String path) {
    try {
      return path.split('/').last;
    } catch (e) {
      return 'Unknown file';
    }
  }

  bool _isImageFile(String path) {
    final ext = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  }

  bool _isPdfFile(String path) {
    return path.toLowerCase().endsWith('.pdf');
  }

  // ENHANCED ATTACHMENT EXTRACTION
  List<String> _getAttachmentPaths(Map<String, dynamic> payment) {
    List<String> attachmentPaths = [];

    // Priority 1: Check attachmentPaths array
    if (payment['attachmentPaths'] is List) {
      final paths = payment['attachmentPaths'] as List;
      for (var path in paths) {
        if (path is String && path.isNotEmpty) {
          attachmentPaths.add(path);
        }
      }
    }

    // Priority 2: Check for single attachmentPath
    if (payment['attachmentPath'] is String &&
        payment['attachmentPath'].toString().isNotEmpty) {
      attachmentPaths.add(payment['attachmentPath'].toString());
    }

    // Priority 3: Check direct attachment fields
    final directFields = ['attachment', 'file', 'receipt', 'document'];
    for (String field in directFields) {
      if (payment[field] is String && payment[field].toString().isNotEmpty) {
        attachmentPaths.add(payment[field].toString());
        break;
      }
    }

    // Priority 4: Check for any URLs or file paths
    if (attachmentPaths.isEmpty) {
      payment.forEach((key, value) {
        if (value is String && value.isNotEmpty) {
          if (value.startsWith('http') ||
              value.startsWith('/') ||
              value.contains('.jpg') ||
              value.contains('.png') ||
              value.contains('.pdf')) {
            attachmentPaths.add(value);
          }
        }
      });
    }

    return attachmentPaths;
  }

  // ATTACHMENT DIALOG
  void _showImageDialog(String imagePath) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 3.0,
              child: Center(
                child: imagePath.startsWith('http')
                    ? Image.network(imagePath, fit: BoxFit.contain)
                    : Image.file(File(imagePath), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: ElevatedButton.icon(
                onPressed: () => _downloadFile(imagePath),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPdf(String pdfPath) async {
    try {
      final url = pdfPath.startsWith('http') ? pdfPath : 'file://$pdfPath';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot open PDF file'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadFile(String filePath) async {
    try {
      if (filePath.startsWith('http')) {
        final response = await http.get(Uri.parse(filePath));
        final documentsDir = await getApplicationDocumentsDirectory();
        final fileName = _getFileName(filePath);
        final file = File('${documentsDir.path}/$fileName');

        await file.writeAsBytes(response.bodyBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File downloaded to: ${file.path}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // For local files, show a message instead of trying to download
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File is already available locally'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accessing file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper methods for file handling
  Future<bool> _checkFileExists(String path) async {
    try {
      final file = File(path);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  Widget _buildErrorContainer(String message) {
    return Container(
      color: Colors.grey[800],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.grey, size: 40),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingContainer() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: CircularProgressIndicator(color: Colors.tealAccent),
      ),
    );
  }

  // ENHANCED ATTACHMENT PREVIEW WIDGET
  Widget _buildSingleAttachmentPreview(String attachmentPath) {
    final isImage = _isImageFile(attachmentPath);
    final isPdf = _isPdfFile(attachmentPath);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File info row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isImage
                        ? Colors.amber.withOpacity(0.2)
                        : isPdf
                            ? Colors.red.withOpacity(0.2)
                            : Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isImage
                        ? Icons.image
                        : isPdf
                            ? Icons.picture_as_pdf
                            : Icons.insert_drive_file,
                    color: isImage
                        ? Colors.amber
                        : isPdf
                            ? Colors.red
                            : Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getFileName(attachmentPath),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isImage
                            ? 'Image File'
                            : isPdf
                                ? 'PDF Document'
                                : 'Document',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Image preview for images - with error handling
            if (isImage)
              GestureDetector(
                onTap: () => _showImageDialog(attachmentPath),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[600]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: attachmentPath.startsWith('http')
                        ? Image.network(
                            attachmentPath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildErrorContainer(
                                  'Failed to load image');
                            },
                          )
                        : FutureBuilder<bool>(
                            future: _checkFileExists(attachmentPath),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return _buildLoadingContainer();
                              }
                              if (snapshot.hasData && snapshot.data!) {
                                return Image.file(File(attachmentPath),
                                    fit: BoxFit.cover);
                              } else {
                                return _buildErrorContainer('Image not found');
                              }
                            },
                          ),
                  ),
                ),
              ),

            if (isImage) const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                if (isImage)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showImageDialog(attachmentPath),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber,
                        side: const BorderSide(color: Colors.amber),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.fullscreen, size: 16),
                      label: const Text('Full Screen'),
                    ),
                  ),
                if (isImage) const SizedBox(width: 8),
                if (isPdf)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openPdf(attachmentPath),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Open PDF'),
                    ),
                  ),
                if (isPdf) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _downloadFile(attachmentPath),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ENHANCED DETAIL CARD
  Widget _buildDetailCard(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF252525),
                border: Border(
                  bottom: BorderSide(color: Colors.grey[700]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ENHANCED DETAIL ITEM
  Widget _detailItem(String label, String value, {bool isImportant = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isImportant ? const Color(0xFF00E5FF) : Colors.white,
                fontWeight: isImportant ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // DATE FIELD HANDLING
  Widget _detailItemWithDate(String label, String? backendDate,
      {bool isImportant = false}) {
    String displayDate = 'Not specified';

    if (backendDate != null && backendDate.isNotEmpty) {
      displayDate = DateFormatter.formatBackendDate(backendDate);
    }

    return _detailItem(label, displayDate, isImportant: isImportant);
  }

  // ✅ FIXED: DYNAMIC STATUS BADGE BASED ON CONTEXT
  Widget _buildStatusBadge() {
    final request = widget.request;

    // ✅ DIFFERENT LOGIC FOR PAYMENT DASHBOARD
    if (widget.isPaymentTab) {
      // For Finance Payment Dashboard
      if (request.isPaid) {
        return _buildStatusBadgeContent(
          Colors.green,
          Icons.verified,
          'PAYMENT COMPLETED',
          'Payment has been processed successfully',
        );
      } else if (request.approvedByCeo) {
        return _buildStatusBadgeContent(
          Colors.blue,
          Icons.payment,
          'READY FOR PAYMENT',
          'Approved by CEO - Ready for payment processing',
        );
      } else if (request.approvedByFinance) {
        return _buildStatusBadgeContent(
          Colors.teal,
          Icons.verified_user,
          'APPROVED BY FINANCE',
          'Waiting for CEO approval',
        );
      } else {
        return _buildStatusBadgeContent(
          Colors.orange,
          Icons.pending_actions,
          'PAYMENT TO BE PROCESSED',
          'Waiting',
        );
      }
    } else {
      // For Finance Verification Dashboard
      if (request.isPaid) {
        return _buildStatusBadgeContent(
          Colors.green,
          Icons.verified,
          'PAID',
          'Payment has been processed successfully',
        );
      } else if (request.approvedByCeo) {
        return _buildStatusBadgeContent(
          Colors.blue,
          Icons.assignment_turned_in,
          'APPROVED BY CEO',
          'Ready for payment processing',
        );
      } else if (request.approvedByFinance) {
        return _buildStatusBadgeContent(
          Colors.teal,
          Icons.verified_user,
          'APPROVED BY FINANCE',
          'Waiting for CEO approval',
        );
      } else if (request.rejectionReason != null &&
          request.rejectionReason!.isNotEmpty) {
        return _buildStatusBadgeContent(
          Colors.red,
          Icons.cancel,
          'REJECTED',
          'Request has been rejected',
        );
      } else {
        return _buildStatusBadgeContent(
          Colors.orange,
          Icons.pending_actions,
          'PENDING FINANCE VERIFICATION',
          'Waiting for finance team verification',
        );
      }
    }
  }

  Widget _buildStatusBadgeContent(Color statusColor, IconData statusIcon,
      String statusText, String description) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            statusColor.withOpacity(0.15),
            statusColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: statusColor.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // UPDATED QUICK SUMMARY CARD - REMOVED PRIORITY
  Widget _buildQuickSummary() {
    final request = widget.request;
    final isReimbursement =
        request.requestType.toLowerCase().contains('reimbursement');

    return _buildDetailCard(
      'Quick Summary',
      Icons.description,
      [
        _buildSummaryItem(
            'Request Type', request.requestType.toUpperCase(), Icons.category),
        _buildSummaryItem('Employee', request.employeeName, Icons.person),
        _buildSummaryItem(
            'Amount', '₹${_formatAmount(request.amount)}', Icons.attach_money),
        if (isReimbursement && request.reimbursementDate != null)
          _buildSummaryItem(
              'Reimbursement Date',
              DateFormatter.formatBackendDate(request.reimbursementDate!),
              Icons.calendar_today),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ENHANCED PAYMENT BREAKDOWN CARD WITH ATTACHMENTS
  Widget _buildPaymentBreakdown() {
    final request = widget.request;

    return _buildDetailCard(
      'Payment Breakdown',
      Icons.payment,
      [
        if (request.payments.isNotEmpty)
          ...request.payments.asMap().entries.map((entry) {
            final index = entry.key;
            final payment = entry.value;
            return _buildPaymentItemWithAttachments(payment, index);
          }).toList()
        else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No payment details available',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
      ],
    );
  }

  // UPDATED PAYMENT ITEM WITH ATTACHMENTS INCLUDED
  Widget _buildPaymentItemWithAttachments(dynamic payment, int index) {
    Map<String, dynamic> paymentData = {};
    if (payment is Map<String, dynamic>) {
      paymentData = payment;
    } else if (payment is String) {
      try {
        paymentData = jsonDecode(payment);
      } catch (e) {
        paymentData = {'amount': 0, 'description': 'Invalid payment data'};
      }
    }

    final amount = paymentData['amount'] ?? 0;
    final parsedAmount = _parseAmount(amount);
    final description = paymentData['description'] ??
        paymentData['particulars'] ??
        'No description';
    final attachmentPaths = _getAttachmentPaths(paymentData);

    return Container(
      margin: EdgeInsets.only(top: index > 0 ? 16 : 0),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment header and basic info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Payment',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₹${parsedAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description.toString(),
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Attachments section for this payment
          if (attachmentPaths.isNotEmpty) ...[
            const Divider(color: Colors.grey, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.attachment,
                            size: 14, color: Colors.blue),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Payment Attachments:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${attachmentPaths.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...attachmentPaths
                      .map((path) => _buildSingleAttachmentPreview(path))
                      .toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ENHANCED ACTION BUTTONS
  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.quickreply, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Verify this request:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Approve',
                  Icons.check_circle,
                  Colors.green,
                  _isProcessing ? null : _financeApproveRequest,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Reject',
                  Icons.cancel,
                  Colors.redAccent,
                  _isProcessing ? null : _showRejectDialog,
                ),
              ),
            ],
          ),
          if (_isProcessing) ...[
            const SizedBox(height: 16),
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Colors.tealAccent),
                  SizedBox(height: 8),
                  Text(
                    'Processing your request...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String text, IconData icon, Color color, VoidCallback? onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.9),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

// MAIN BUILD METHOD
  @override
  Widget build(BuildContext context) {
    final request = widget.request;

    final isReimbursement =
        request.requestType.toLowerCase().contains('reimbursement');
    final isAdvance = request.requestType.toLowerCase().contains('advance');

    // ✅ FIXED: PROPERLY CAPITALIZED TITLE FUNCTION
    String getCapitalizedTitle() {
      String requestType = request.requestType.toLowerCase();
      if (requestType.contains('reimbursement')) {
        return 'Reimbursement Details';
      } else if (requestType.contains('advance')) {
        return 'Advance Details';
      } else {
        // Fallback: Capitalize first letter of each word
        List<String> words = requestType.split(' ');
        for (int i = 0; i < words.length; i++) {
          if (words[i].isNotEmpty) {
            words[i] = words[i][0].toUpperCase() + words[i].substring(1);
          }
        }
        return words.join(' ') + ' Details';
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          getCapitalizedTitle(), // ✅ USE THE FIXED FUNCTION INSTEAD OF DIRECT requestType
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline,
                color: Colors.white), // ✅ ADD WHITE COLOR TO ICON
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text('Request Information',
                      style: TextStyle(color: Colors.white)),
                  content: Text(
                    'Request ID: ${request.id}\n'
                    'Type: ${getCapitalizedTitle().replaceAll(' Details', '')}\n' // ✅ FIXED TYPE DISPLAY
                    'Status: ${request.displayStatus}\n'
                    'Total Amount: ₹${_formatAmount(request.amount)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close',
                          style:
                              TextStyle(color: Colors.white)), // ✅ WHITE TEXT
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.tealAccent),
                  SizedBox(height: 16),
                  Text(
                    'Processing...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ FIXED: Dynamic Status Badge based on context
                  _buildStatusBadge(),

                  // Quick Summary (without priority)
                  _buildQuickSummary(),

                  // 1. BASIC INFORMATION
                  _buildDetailCard(
                    'Basic Information',
                    Icons.person,
                    [
                      _detailItem('Employee Name', request.employeeName,
                          isImportant: true),
                      _detailItem('Employee ID', request.employeeId),
                      _detailItemWithDate(
                          'Submission Date', request.submissionDate),
                      _detailItem(
                          'Request Type', request.requestType.toUpperCase(),
                          isImportant: true),
                      _detailItem(
                          'Total Amount', '₹${_formatAmount(request.amount)}',
                          isImportant: true),
                    ],
                  ),

                  // 2. PROJECT INFORMATION
                  if ((request.projectId != null &&
                          request.projectId!.isNotEmpty) ||
                      (request.projectName != null &&
                          request.projectName!.isNotEmpty))
                    _buildDetailCard(
                      'Project Information',
                      Icons.business_center,
                      [
                        if (request.projectId != null &&
                            request.projectId!.isNotEmpty)
                          _detailItem('Project Code', request.projectId!),
                        if (request.projectName != null &&
                            request.projectName!.isNotEmpty)
                          _detailItem('Project Name', request.projectName!),
                      ],
                    ),

                  // 3. TYPE-SPECIFIC DATES - FIXED VERSION
                  if (isReimbursement)
                    _buildDetailCard(
                      'Reimbursement Details',
                      Icons.calendar_today,
                      [
                        if (request.reimbursementDate != null)
                          _detailItemWithDate(
                              'Reimbursement Date', request.reimbursementDate),
                        if (request.paymentDate !=
                            null) // ✅ SHOW PAYMENT DATE FOR REIMBURSEMENT
                          _detailItemWithDate(
                              'Payment Date', request.paymentDate,
                              isImportant: true),
                      ],
                    ),

                  if (isAdvance)
                    _buildDetailCard(
                      'Advance Details',
                      Icons.date_range,
                      [
                        if (request.requestDate != null)
                          _detailItemWithDate(
                              'Request Date', request.requestDate),
                        if (request.projectDate != null)
                          _detailItemWithDate(
                              'Project Date', request.projectDate,
                              isImportant: true),
                        if (request.paymentDate !=
                            null) // ✅ SHOW PAYMENT DATE FOR ADVANCE
                          _detailItemWithDate(
                              'Payment Date', request.paymentDate,
                              isImportant: true),
                      ],
                    ),

                  // 4. PAYMENT BREAKDOWN WITH ATTACHMENTS
                  _buildPaymentBreakdown(),

                  // 5. APPROVAL INFORMATION
                  if (request.approvedBy != null ||
                      request.approvalDate != null)
                    _buildDetailCard(
                      'Approval History',
                      Icons.verified_user,
                      [
                        if (request.approvedBy != null)
                          _detailItem('Approved By', request.approvedBy!),
                        if (request.approvalDate != null)
                          _detailItemWithDate(
                              'Approval Date', request.approvalDate),
                      ],
                    ),

                  // 6. REJECTION INFORMATION
                  if (request.rejectionReason != null &&
                      request.rejectionReason!.isNotEmpty)
                    _buildDetailCard(
                      'Rejection Details',
                      Icons.warning,
                      [
                        _detailItem(
                            'Rejection Reason', request.rejectionReason!,
                            isImportant: true),
                      ],
                    ),

                  // 7. PAYMENT INFORMATION - SHOW FOR ALL TYPES
                  if (request.paymentDate != null)
                    _buildDetailCard(
                      'Payment Details',
                      Icons.payment,
                      [
                        _detailItemWithDate('Payment Date', request.paymentDate,
                            isImportant: true),
                        if (request.isPaid)
                          _detailItem('Payment Status', 'COMPLETED',
                              isImportant: true),
                      ],
                    ),

                  // ✅ FIXED: ACTION BUTTONS - Only show for finance verification tab
                  if (!widget.isPaymentTab) _buildActionButtons(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // REST OF YOUR EXISTING METHODS (APPROVE/REJECT ETC.)
  Future<void> _financeApproveRequest() async {
    setState(() => _isProcessing = true);

    try {
      final response = await http.post(
        Uri.parse(
            '$baseUrl/api/finance-verification/approve/'), // ✅ CORRECTED ENDPOINT
        headers: {
          'Authorization':
              'Token ${widget.authToken}', // ✅ CORRECTED TOKEN FORMAT
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'request_id': widget.request.id,
          'request_type': widget.request.requestType,
        }),
      );

      setState(() => _isProcessing = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request Approved by Finance'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to approve request: ${errorData['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRejectDialog() {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reject Request', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason for rejection:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a rejection reason'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _financeRejectRequest(reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _financeRejectRequest(String reason) async {
    setState(() => _isProcessing = true);

    try {
      final response = await http.post(
        Uri.parse(
            '$baseUrl/api/finance-verification/reject/'), // ✅ CORRECTED ENDPOINT
        headers: {
          'Authorization':
              'Token ${widget.authToken}', // ✅ CORRECTED TOKEN FORMAT
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'request_id': widget.request.id,
          'request_type': widget.request.requestType,
          'reason': reason,
        }),
      );

      setState(() => _isProcessing = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request Rejected by Finance'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context, true);
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to reject request: ${errorData['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
