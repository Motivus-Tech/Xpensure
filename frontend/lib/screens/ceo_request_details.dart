import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';

class CeoRequestDetails extends StatefulWidget {
  final dynamic request;
  final Map<String, dynamic>? requestData;
  final String authToken;

  const CeoRequestDetails({
    super.key,
    this.request,
    this.requestData,
    required this.authToken,
  }) : assert(request != null || requestData != null,
            'Either request or requestData must be provided');

  dynamic getRequestData(String key) {
    if (requestData != null) {
      return requestData![key];
    } else {
      switch (key) {
        case 'id':
          return request.id;
        case 'employeeName':
          return request.employeeName;
        case 'employeeId':
          return request.employeeId;
        case 'amount':
          return request.amount;
        case 'date':
          return request.date;
        case 'submitted_date':
          return request.submittedDate;
        case 'description':
          return request.description;
        case 'status':
          return request.status;
        case 'type':
          return request.type;
        case 'requestType':
          return request.requestType;
        case 'payments':
          return request.payments;
        case 'attachments':
          return request.attachments;
        case 'employeeAvatar':
          return request.employeeAvatar;
        case 'project_id':
          return request.projectId;
        case 'project_name':
          return request.projectName;
        case 'reimbursement_date':
          return request.reimbursementDate;
        case 'request_date':
          return request.requestDate;
        case 'project_date':
          return request.projectDate;
        case 'approved_by':
          return request.approvedBy;
        case 'approval_date':
          return request.approvalDate;
        case 'payment_date':
          return request.paymentDate;
        case 'rejection_reason':
          return request.rejectionReason;
        case 'rawData':
          return request.rawData;
        case 'claimType':
          return request.claimType;
        case 'particulars':
          return request.particulars;
        case 'project_code':
          return request.projectCode;
        case 'projectCode':
          return request.projectCode;
        default:
          return null;
      }
    }
  }

  int get requestId => getRequestData('id');
  String get requestType => (getRequestData('requestType') ?? 'reimbursement')
      .toString()
      .toLowerCase();

  @override
  State<CeoRequestDetails> createState() => _CeoRequestDetailsState();
}

class _CeoRequestDetailsState extends State<CeoRequestDetails> {
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

  // ENHANCED PROJECT INFORMATION EXTRACTION - FIXED FOR REIMBURSEMENT AND ADVANCE
  Map<String, dynamic> _getProjectInfo() {
    Map<String, dynamic> projectInfo = {};

    // Try multiple possible keys for project information
    final possibleProjectIdKeys = [
      'project_id',
      'projectId',
      'project_code',
      'projectCode',
      'projectID',
      'projectid'
    ];

    final possibleProjectNameKeys = [
      'project_name',
      'projectName',
      'project_title',
      'projectTitle',
      'projectname'
    ];

    // Extract project ID - CHECK BOTH REQUEST DATA AND RAW DATA
    for (String key in possibleProjectIdKeys) {
      final value = widget.getRequestData(key);
      if (value != null && value.toString().isNotEmpty) {
        projectInfo['id'] = value.toString();
        break;
      }
    }

    // Extract project name - CHECK BOTH REQUEST DATA AND RAW DATA
    for (String key in possibleProjectNameKeys) {
      final value = widget.getRequestData(key);
      if (value != null && value.toString().isNotEmpty) {
        projectInfo['name'] = value.toString();
        break;
      }
    }

    // CRITICAL FIX: Also check in raw data if available (this is where project data often is)
    final rawData = widget.getRequestData('rawData');
    if (rawData != null && rawData is Map) {
      print("🔍 Checking rawData for project info: $rawData");

      for (String key in possibleProjectIdKeys) {
        if (rawData.containsKey(key) &&
            rawData[key] != null &&
            rawData[key].toString().isNotEmpty) {
          projectInfo['id'] = rawData[key].toString();
          print("✅ Found project ID in rawData: ${rawData[key]}");
          break;
        }
      }
      for (String key in possibleProjectNameKeys) {
        if (rawData.containsKey(key) &&
            rawData[key] != null &&
            rawData[key].toString().isNotEmpty) {
          projectInfo['name'] = rawData[key].toString();
          print("✅ Found project name in rawData: ${rawData[key]}");
          break;
        }
      }
    }

    // Check payments array for project info
    final payments = widget.getRequestData('payments');
    if (payments != null && payments is List && payments.isNotEmpty) {
      for (var payment in payments) {
        if (payment is Map) {
          for (String key in possibleProjectIdKeys) {
            if (payment.containsKey(key) &&
                payment[key] != null &&
                payment[key].toString().isNotEmpty) {
              projectInfo['id'] = payment[key].toString();
              break;
            }
          }
          for (String key in possibleProjectNameKeys) {
            if (payment.containsKey(key) &&
                payment[key] != null &&
                payment[key].toString().isNotEmpty) {
              projectInfo['name'] = payment[key].toString();
              break;
            }
          }
        }
      }
    }

    print("📊 Final project info extracted: $projectInfo");
    return projectInfo;
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
            backgroundColor: const Color.fromARGB(255, 136, 218, 138),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File location: $filePath'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

            // Image preview for images
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
                              return Container(
                                color: Colors.grey[800],
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.grey, size: 40),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Failed to load image',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        : Image.file(File(attachmentPath), fit: BoxFit.cover),
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
  Widget _buildDetailCard(String title, IconData icon, List<Widget> children,
      {Color? headerColor}) {
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
                color: headerColor ?? const Color(0xFF252525),
                border: Border(
                  bottom: BorderSide(color: Colors.grey[700]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (headerColor ?? Colors.blue).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(icon, size: 18, color: headerColor ?? Colors.blue),
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
  Widget _detailItem(String label, String value,
      {bool isImportant = false, Color? valueColor}) {
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
                color: valueColor ??
                    (isImportant ? const Color(0xFF00E5FF) : Colors.white),
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

  // ENHANCED STATUS BADGE
  Widget _buildStatusBadge() {
    final status =
        widget.getRequestData('status')?.toString().toLowerCase() ?? 'pending';
    final rejectionReason = widget.getRequestData('rejection_reason');

    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.pending_actions;
    String statusText = 'PENDING CEO APPROVAL';
    String description = 'Waiting for CEO approval';

    if (status.contains('paid')) {
      statusColor = Colors.green;
      statusIcon = Icons.verified;
      statusText = 'PAID';
      description = 'Payment has been processed successfully';
    } else if (status.contains('approved') || status.contains('ceo_approved')) {
      statusColor = Colors.blue;
      statusIcon = Icons.assignment_turned_in;
      statusText = 'APPROVED BY CEO';
      description = 'Ready for payment processing';
    } else if (status.contains('finance_approved')) {
      statusColor = Colors.teal;
      statusIcon = Icons.verified_user;
      statusText = 'APPROVED BY FINANCE';
      description = 'Waiting for CEO approval';
    } else if (status.contains('rejected') || rejectionReason != null) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = 'REJECTED';
      description = 'Request has been rejected';
    }

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
                if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Reason: $rejectionReason',
                    style: TextStyle(
                      color: statusColor.withOpacity(0.8),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // UPDATED QUICK SUMMARY CARD
  Widget _buildQuickSummary() {
    final isReimbursement =
        widget.requestType.toLowerCase().contains('reimbursement');
    final projectInfo = _getProjectInfo();

    return _buildDetailCard(
      'Quick Summary',
      Icons.description,
      [
        _buildSummaryItem('Request Type', widget.requestType.toUpperCase(),
            Icons.category, Colors.purple),
        _buildSummaryItem(
            'Employee',
            widget.getRequestData('employeeName') ?? 'Unknown',
            Icons.person,
            Colors.blue),
        _buildSummaryItem(
            'Amount',
            '₹${_formatAmount(widget.getRequestData('amount'))}',
            Icons.attach_money,
            Colors.green),
        if (projectInfo['id'] != null)
          _buildSummaryItem(
              'Project Code', projectInfo['id']!, Icons.code, Colors.orange),
        if (projectInfo['name'] != null)
          _buildSummaryItem('Project Name', projectInfo['name']!,
              Icons.business, Colors.teal),
        if (isReimbursement &&
            widget.getRequestData('reimbursement_date') != null)
          _buildSummaryItem(
              'Reimbursement Date',
              DateFormatter.formatBackendDate(
                  widget.getRequestData('reimbursement_date')),
              Icons.calendar_today,
              Colors.teal),
      ],
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
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
            style: TextStyle(
              color: color,
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
    final paymentsData = widget.getRequestData('payments');

    return _buildDetailCard(
      'Payment Breakdown',
      Icons.payment,
      [
        if (paymentsData != null &&
            (paymentsData is List && paymentsData.isNotEmpty ||
                paymentsData is Map))
          ..._buildPaymentItemsList()
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

  List<Widget> _buildPaymentItemsList() {
    final paymentsData = widget.getRequestData('payments');
    List<dynamic> payments = [];

    // Convert payments to list
    if (paymentsData is List) {
      payments = paymentsData;
    } else if (paymentsData is Map) {
      payments = [paymentsData];
    }

    return payments.asMap().entries.map((entry) {
      final index = entry.key;
      final payment = entry.value;
      return _buildPaymentItemWithAttachments(payment, index);
    }).toList();
  }

  // UPDATED PAYMENT ITEM WITH ATTACHMENTS INCLUDED
  Widget _buildPaymentItemWithAttachments(dynamic payment, int index) {
    Map<String, dynamic> paymentData = {};
    if (payment is Map<String, dynamic>) {
      paymentData = payment;
    } else if (payment is String) {
      try {
        paymentData = json.decode(payment);
      } catch (e) {
        paymentData = {'amount': 0, 'description': 'Invalid payment data'};
      }
    }

    final amount = paymentData['amount'] ?? 0;
    final parsedAmount = _parseAmount(amount);
    final description = paymentData['description'] ??
        paymentData['particulars'] ??
        'No description';
    final claimType = paymentData['claimType'] ?? 'Not specified';
    final paymentDate = paymentData['date'] ?? paymentData['paymentDate'];
    final requestDate = paymentData['requestDate'];
    final projectDate = paymentData['projectDate'];
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
                          'Payment Entry',
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
                const SizedBox(height: 12),

                // Payment details in a structured way
                _buildPaymentDetailRow('Description:', description),
                if (claimType != 'Not specified')
                  _buildPaymentDetailRow('Claim Type:', claimType),
                if (paymentDate != null)
                  _buildPaymentDetailRow('Payment Date:',
                      DateFormatter.formatBackendDate(paymentDate.toString())),
                if (requestDate != null)
                  _buildPaymentDetailRow('Request Date:',
                      DateFormatter.formatBackendDate(requestDate.toString())),
                if (projectDate != null)
                  _buildPaymentDetailRow('Project Date:',
                      DateFormatter.formatBackendDate(projectDate.toString())),
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

  Widget _buildPaymentDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ENHANCED ACTION BUTTONS
  Widget _buildActionButtons() {
    final status =
        widget.getRequestData('status')?.toString().toLowerCase() ?? '';

    // Don't show action buttons if already approved or rejected
    if (status.contains('approved') ||
        status.contains('rejected') ||
        status.contains('paid')) {
      return Container();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[700]!),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.withOpacity(0.1),
            Colors.blue.withOpacity(0.1),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.quickreply, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'CEO Actions',
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
            'Review and take action on this request:',
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
                  _isProcessing ? null : _approveRequest,
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

  // APPROVE/REJECT METHODS
  Future<void> _approveRequest() async {
    setState(() => _isProcessing = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ceo-approval/approve/'),
        headers: {
          'Authorization': 'Token ${widget.authToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'request_id': widget.requestId,
          'request_type': widget.requestType,
        }),
      );

      setState(() => _isProcessing = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request Approved by CEO'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        final errorData = json.decode(response.body);
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
              _ceoRejectRequest(reason);
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

  Future<void> _ceoRejectRequest(String reason) async {
    setState(() => _isProcessing = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ceo-approval/reject/'),
        headers: {
          'Authorization': 'Token ${widget.authToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'request_id': widget.requestId,
          'request_type': widget.requestType,
          'reason': reason,
        }),
      );

      setState(() => _isProcessing = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request Rejected by CEO'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context, true);
      } else {
        final errorData = json.decode(response.body);
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

  // ENHANCED PROJECT INFORMATION SECTION
  Widget _buildProjectInformation() {
    final projectInfo = _getProjectInfo();

    // Only show if we have at least one piece of project information
    if (projectInfo.isEmpty) {
      return Container();
    }

    List<Widget> projectDetails = [];

    if (projectInfo['id'] != null) {
      projectDetails.add(
          _detailItem('Project Code', projectInfo['id']!, isImportant: true));
    }

    if (projectInfo['name'] != null) {
      projectDetails.add(_detailItem('Project Name', projectInfo['name']!));
    }

    return _buildDetailCard(
      'Project Information',
      Icons.business_center,
      projectDetails,
      headerColor: Colors.orange,
    );
  }

  // REIMBURSEMENT SPECIFIC DETAILS
  Widget _buildReimbursementDetails() {
    final isReimbursement =
        widget.requestType.toLowerCase().contains('reimbursement');
    if (!isReimbursement) return Container();

    List<Widget> reimbursementDetails = [];

    if (widget.getRequestData('reimbursement_date') != null)
      reimbursementDetails.add(_detailItemWithDate(
          'Reimbursement Date', widget.getRequestData('reimbursement_date'),
          isImportant: true));

    if (widget.getRequestData('payment_date') != null)
      reimbursementDetails.add(_detailItemWithDate(
          'Payment Date', widget.getRequestData('payment_date')));

    return reimbursementDetails.isNotEmpty
        ? _buildDetailCard(
            'Reimbursement Details',
            Icons.receipt_long,
            reimbursementDetails,
            headerColor: Colors.green,
          )
        : Container();
  }

  // ADVANCE SPECIFIC DETAILS
  Widget _buildAdvanceDetails() {
    final isAdvance = widget.requestType.toLowerCase().contains('advance');
    if (!isAdvance) return Container();

    List<Widget> advanceDetails = [];

    if (widget.getRequestData('request_date') != null)
      advanceDetails.add(_detailItemWithDate(
          'Request Date', widget.getRequestData('request_date'),
          isImportant: true));

    if (widget.getRequestData('project_date') != null)
      advanceDetails.add(_detailItemWithDate(
          'Project Date', widget.getRequestData('project_date')));

    if (widget.getRequestData('payment_date') != null)
      advanceDetails.add(_detailItemWithDate(
          'Payment Date', widget.getRequestData('payment_date')));

    return advanceDetails.isNotEmpty
        ? _buildDetailCard(
            'Advance Details',
            Icons.forward,
            advanceDetails,
            headerColor: Colors.purple,
          )
        : Container();
  }

  // APPROVAL HISTORY SECTION
  Widget _buildApprovalHistory() {
    final approvedBy = widget.getRequestData('approved_by');
    final approvalDate = widget.getRequestData('approval_date');

    if (approvedBy == null && approvalDate == null) {
      return Container();
    }

    List<Widget> approvalDetails = [];

    if (approvedBy != null)
      approvalDetails.add(
          _detailItem('Approved By', approvedBy.toString(), isImportant: true));

    if (approvalDate != null)
      approvalDetails.add(_detailItemWithDate('Approval Date', approvalDate));

    return _buildDetailCard(
      'Approval History',
      Icons.verified_user,
      approvalDetails,
      headerColor: Colors.blue,
    );
  }

  // REJECTION DETAILS SECTION
  Widget _buildRejectionDetails() {
    final rejectionReason = widget.getRequestData('rejection_reason');

    if (rejectionReason == null || rejectionReason.toString().isEmpty) {
      return Container();
    }

    return _buildDetailCard(
      'Rejection Details',
      Icons.warning,
      [
        _detailItem(
          'Rejection Reason',
          rejectionReason.toString(),
          isImportant: true,
          valueColor: Colors.red,
        ),
      ],
      headerColor: Colors.red,
    );
  }

  // MAIN BUILD METHOD - COMPLETELY UPDATED
  @override
  Widget build(BuildContext context) {
    final projectInfo = _getProjectInfo();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          '${widget.requestType.toUpperCase()} Details',
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
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              final projectInfo = _getProjectInfo();
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text('Request Information',
                      style: TextStyle(color: Colors.white)),
                  content: Text(
                    'Request ID: ${widget.requestId}\n'
                    'Type: ${widget.requestType}\n'
                    'Status: ${widget.getRequestData('status') ?? 'Unknown'}\n'
                    'Total Amount: ₹${_formatAmount(widget.getRequestData('amount'))}\n'
                    'Project Code: ${projectInfo['id'] ?? 'Not specified'}\n'
                    'Project Name: ${projectInfo['name'] ?? 'Not specified'}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
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
                  // Enhanced Status Badge
                  _buildStatusBadge(),

                  // Quick Summary (now includes project code and name)
                  _buildQuickSummary(),

                  // 1. BASIC INFORMATION
                  _buildDetailCard(
                    'Basic Information',
                    Icons.person,
                    [
                      _detailItem('Employee Name',
                          widget.getRequestData('employeeName') ?? 'Unknown',
                          isImportant: true),
                      _detailItem('Employee ID',
                          widget.getRequestData('employeeId') ?? 'Unknown'),
                      _detailItemWithDate(
                          'Submission Date',
                          widget.getRequestData('submitted_date') ??
                              widget.getRequestData('date')),
                      _detailItem(
                          'Request Type', widget.requestType.toUpperCase(),
                          isImportant: true),
                      _detailItem('Total Amount',
                          '₹${_formatAmount(widget.getRequestData('amount'))}',
                          isImportant: true),
                    ],
                  ),

                  // 2. PROJECT INFORMATION (ENHANCED) - NOW SHOWS BOTH CODE AND NAME
                  _buildProjectInformation(),

                  // 3. TYPE-SPECIFIC DETAILS
                  _buildReimbursementDetails(),
                  _buildAdvanceDetails(),

                  // 4. PAYMENT BREAKDOWN WITH ATTACHMENTS (ATTACHMENTS SHOWN PER PAYMENT)
                  _buildPaymentBreakdown(),

                  // 5. APPROVAL INFORMATION
                  _buildApprovalHistory(),

                  // 6. REJECTION INFORMATION
                  _buildRejectionDetails(),

                  // 7. ACTION BUTTONS
                  _buildActionButtons(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
