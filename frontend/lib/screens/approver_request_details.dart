import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'common_dashboard.dart';

class ApproverRequestDetails extends StatefulWidget {
  final Request request;
  final String authToken;

  const ApproverRequestDetails({
    super.key,
    required this.request,
    required this.authToken,
  });

  @override
  State<ApproverRequestDetails> createState() => _ApproverRequestDetailsState();
}

class _ApproverRequestDetailsState extends State<ApproverRequestDetails> {
  final ApiService apiService = ApiService();
  bool _isProcessing = false;

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

  // Get all attachment paths from a payment (handles both single and multiple)
  List<String> _getAttachmentPaths(Map<String, dynamic> payment) {
    // First check for multiple attachmentPaths
    if (payment["attachmentPaths"] is List) {
      return List<String>.from(payment["attachmentPaths"] ?? []);
    }
    // Fallback to single attachmentPath
    else if (payment["attachmentPath"] is String &&
        payment["attachmentPath"].toString().isNotEmpty) {
      return [payment["attachmentPath"].toString()];
    }
    return [];
  }

  void _showImageDialog(String imagePath) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color.fromARGB(255, 28, 28, 28),
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
            backgroundColor: const Color(0xFF1E8C3E),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File location: $filePath'),
            backgroundColor: const Color(0xFF1A237E),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading file: $e'),
          backgroundColor: const Color(0xFFB71C1C),
        ),
      );
    }
  }

  Widget _buildSingleAttachmentPreview(String attachmentPath) {
    final isImage = _isImageFile(attachmentPath);
    final isPdf = _isPdfFile(attachmentPath);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFF0D0D0D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[800]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isImage
                      ? Icons.image
                      : isPdf
                          ? Icons.picture_as_pdf
                          : Icons.insert_drive_file,
                  color: isImage
                      ? Colors.amber
                      : isPdf
                          ? Colors.red
                          : Colors.grey[400],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getFileName(attachmentPath),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isImage)
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: attachmentPath.startsWith('http')
                      ? Image.network(attachmentPath, fit: BoxFit.cover)
                      : Image.file(File(attachmentPath), fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (isImage)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showImageDialog(attachmentPath),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B1FA2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View'),
                    ),
                  ),
                if (isImage) const SizedBox(width: 8),
                if (isPdf)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openPdf(attachmentPath),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC62828),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open PDF'),
                    ),
                  ),
                if (isPdf) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _downloadFile(attachmentPath),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1976D2),
                      side: const BorderSide(color: Color(0xFF1976D2)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.download, size: 18),
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

  Widget _buildAttachmentsSection(List<String> attachmentPaths) {
    if (attachmentPaths.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'No attachments',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Attachments:',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ...attachmentPaths
            .map((path) => _buildSingleAttachmentPreview(path))
            .toList(),
      ],
    );
  }

  void _approveRequest() async {
    setState(() => _isProcessing = true);

    final success = await apiService.approveRequest(
      authToken: widget.authToken,
      requestId: widget.request.id,
      requestType: widget.request.requestType.toLowerCase(),
    );

    setState(() => _isProcessing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Request Approved Successfully'),
          backgroundColor: const Color(0xFF1E8C3E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to approve request'),
          backgroundColor: const Color(0xFFB71C1C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _rejectRequest() {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Reject Request',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason for rejection:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
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
              setState(() => _isProcessing = true);

              final success = await apiService.rejectRequest(
                authToken: widget.authToken,
                requestId: widget.request.id,
                requestType: widget.request.requestType.toLowerCase(),
                reason: reason,
              );

              setState(() => _isProcessing = false);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Request Rejected'),
                    backgroundColor: const Color(0xFFB71C1C),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF0D0D0D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[800]!, width: 1),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value, {bool isImportant = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isImportant ? const Color(0xFF00E5FF) : Colors.white,
                fontWeight: isImportant ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final isReimbursement =
        request.requestType.toLowerCase().contains("reimbursement");

    // Better project info detection
    bool hasProjectInfo = false;
    String? projectId;
    String? projectName;

    if (request.payments.isNotEmpty) {
      final firstPayment = request.payments[0];

      // Try different field names for project ID
      projectId = firstPayment['projectId'] ??
          firstPayment['project_id'] ??
          firstPayment['projectID'];

      // Try different field names for project name
      projectName = firstPayment['projectName'] ?? firstPayment['project_name'];

      hasProjectInfo = projectId != null || projectName != null;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Request Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0D0D0D),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00E5FF)),
                  SizedBox(height: 16),
                  Text(
                    'Processing...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Request Overview Card
                  _buildDetailCard('Request Overview', [
                    _detailItem('Employee', request.employeeName,
                        isImportant: true),
                    _detailItem('Request Type', request.requestType),
                    _detailItem('Date', request.submissionDate),
                    _detailItem(
                        'Amount', '₹${request.amount.toStringAsFixed(2)}',
                        isImportant: true),
                  ]),

                  // Project Information Card with flexible field detection
                  if (hasProjectInfo)
                    _buildDetailCard('Project Information', [
                      if (projectId != null)
                        _detailItem('Project ID', projectId!),
                      if (!isReimbursement && projectName != null)
                        _detailItem('Project Name', projectName!),
                    ]),

                  // Payment Details Card
                  _buildDetailCard('Payment Details', [
                    if (request.payments.isNotEmpty)
                      ...request.payments.asMap().entries.map((entry) {
                        final index = entry.key;
                        final payment = entry.value;
                        final attachmentPaths = _getAttachmentPaths(payment);

                        return Container(
                          margin: EdgeInsets.only(top: index > 0 ? 12 : 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[800]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment ${index + 1}',
                                style: const TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Common fields for both types
                              _detailItem(
                                  'Amount', '₹${payment['amount'] ?? '0'}'),

                              // REIMBURSEMENT SPECIFIC FIELDS
                              if (isReimbursement) ...[
                                // Try multiple field names for payment date
                                if (_getFieldValue(payment, [
                                      'paymentDate',
                                      'payment_date',
                                      'date'
                                    ]) !=
                                    null)
                                  _detailItem(
                                      'Payment Date',
                                      _getFieldValue(payment, [
                                        'paymentDate',
                                        'payment_date',
                                        'date'
                                      ])!),

                                // Try multiple field names for claim type
                                if (_getFieldValue(payment,
                                        ['claimType', 'claim_type', 'type']) !=
                                    null)
                                  _detailItem(
                                      'Claim Type',
                                      _getFieldValue(payment, [
                                        'claimType',
                                        'claim_type',
                                        'type'
                                      ])!),

                                // Try multiple field names for description
                                if (_getFieldValue(payment, [
                                      'description',
                                      'Description',
                                      'desc'
                                    ]) !=
                                    null)
                                  _detailItem(
                                      'Description',
                                      _getFieldValue(payment, [
                                        'description',
                                        'Description',
                                        'desc'
                                      ])!),

                                // Custom Claim Type for "Other" category
                                if (_getFieldValue(payment, [
                                      'customClaimType',
                                      'custom_claim_type',
                                      'otherType'
                                    ]) !=
                                    null)
                                  _detailItem(
                                      'Custom Claim Type',
                                      _getFieldValue(payment, [
                                        'customClaimType',
                                        'custom_claim_type',
                                        'otherType'
                                      ])!),
                              ]
                              // ADVANCE REQUEST SPECIFIC FIELDS
                              else ...[
                                // Try multiple field names for request date
                                if (_getFieldValue(payment, [
                                      'requestDate',
                                      'request_date',
                                      'date'
                                    ]) !=
                                    null)
                                  _detailItem(
                                      'Request Date',
                                      _getFieldValue(payment, [
                                        'requestDate',
                                        'request_date',
                                        'date'
                                      ])!),

                                // Try multiple field names for project date
                                if (_getFieldValue(payment,
                                        ['projectDate', 'project_date']) !=
                                    null)
                                  _detailItem(
                                      'Project Date',
                                      _getFieldValue(payment,
                                          ['projectDate', 'project_date'])!),

                                // Try multiple field names for particulars
                                if (_getFieldValue(payment, [
                                      'particulars',
                                      'Particulars',
                                      'description'
                                    ]) !=
                                    null)
                                  _detailItem(
                                      'Particulars',
                                      _getFieldValue(payment, [
                                        'particulars',
                                        'Particulars',
                                        'description'
                                      ])!),
                              ],

                              // Attachments section
                              _buildAttachmentsSection(attachmentPaths),
                            ],
                          ),
                        );
                      }).toList()
                    else
                      const Text(
                        'No payment details available',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ]),

                  // Action Buttons
                  Card(
                    color: const Color.fromARGB(255, 24, 24, 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[800]!, width: 1),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Take Action',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isProcessing ? null : _approveRequest,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E8C3E),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text(
                                    'Approve',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isProcessing ? null : _rejectRequest,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFC62828),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(Icons.cancel),
                                  label: const Text(
                                    'Reject',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_isProcessing) ...[
                            const SizedBox(height: 16),
                            const CircularProgressIndicator(
                                color: Color(0xFF00E5FF)),
                            const SizedBox(height: 8),
                            const Text(
                              'Processing your request...',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // Helper method to get field value with multiple possible keys
  String? _getFieldValue(Map<String, dynamic> data, List<String> possibleKeys) {
    for (String key in possibleKeys) {
      if (data[key] != null && data[key].toString().isNotEmpty) {
        return data[key].toString();
      }
    }
    return null;
  }
}
