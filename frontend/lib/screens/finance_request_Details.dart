import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

// Finance ke liye alag Request class
class FinanceRequest {
  final int id;
  final String employeeId;
  final String employeeName;
  final String? avatarUrl;
  final String submissionDate;
  final double amount;
  final String description;
  final List<dynamic> payments;
  final String requestType;
  final String status;
  final String? approvedBy;
  final String? approvalDate;

  FinanceRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.submissionDate,
    required this.amount,
    required this.description,
    required this.payments,
    required this.requestType,
    required this.status,
    this.avatarUrl,
    this.approvedBy,
    this.approvalDate,
  });
}

class FinanceRequestDetails extends StatefulWidget {
  final FinanceRequest request;
  final String authToken;
  final bool
      isPaymentTab; // Yeh batayega ki payment tab se aa raha hai ya verification se

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

  Widget _buildAttachmentPreview(String attachmentPath) {
    final isImage = _isImageFile(attachmentPath);
    final isPdf = _isPdfFile(attachmentPath);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.grey[900],
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
                          : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getFileName(attachmentPath),
                    style: const TextStyle(
                      color: Colors.white70,
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
                  border: Border.all(color: Colors.white24),
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
                        backgroundColor:
                            const Color.fromARGB(255, 215, 135, 229),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.visibility),
                      label: const Text('View'),
                    ),
                  ),
                if (isImage) const SizedBox(width: 8),
                if (isPdf)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openPdf(attachmentPath),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open PDF'),
                    ),
                  ),
                if (isPdf) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _downloadFile(attachmentPath),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent),
                    ),
                    icon: const Icon(Icons.download),
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

  // Finance Approval - Verification Tab ke liye
  Future<void> _financeApproveRequest() async {
    setState(() => _isProcessing = true);

    final success = await apiService.financeApproveRequest(
      authToken: widget.authToken,
      requestId: widget.request.id,
      requestType: widget.request.requestType,
    );

    setState(() => _isProcessing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request Approved by Finance'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to approve request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Finance Reject - Verification Tab ke liye
  Future<void> _financeRejectRequest(String reason) async {
    setState(() => _isProcessing = true);

    final success = await apiService.financeRejectRequest(
      authToken: widget.authToken,
      requestId: widget.request.id,
      requestType: widget.request.requestType,
      reason: reason,
    );

    setState(() => _isProcessing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request Rejected by Finance'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to reject request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Mark as Paid - Payment Tab ke liye
  Future<void> _markAsPaid() async {
    setState(() => _isProcessing = true);

    final success = await apiService.markAsPaid(
      authToken: widget.authToken,
      requestId: widget.request.id,
      requestType: widget.request.requestType,
    );

    setState(() => _isProcessing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment Marked as Paid'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to mark as paid'),
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
            Icon(Icons.warning_amber, color: Color.fromARGB(255, 242, 119, 82)),
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

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF1E1E1E),
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
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.white70,
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
                color: isImportant ? Colors.tealAccent : Colors.white,
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

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          widget.isPaymentTab ? 'Payment Details' : 'Verification Details',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 179, 176, 176),
          ),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(
          color: Color.fromARGB(255, 179, 176, 176),
        ),
        elevation: 0,
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
                  // Status Badge
                  if (widget.isPaymentTab)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified, color: Colors.green[300]),
                          const SizedBox(width: 8),
                          Text(
                            'APPROVED BY CEO - READY FOR PAYMENT',
                            style: TextStyle(
                              color: Colors.green[300],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.pending, color: Colors.orange[300]),
                          const SizedBox(width: 8),
                          Text(
                            'PENDING FINANCE VERIFICATION',
                            style: TextStyle(
                              color: Colors.orange[300],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Request Overview Card
                  _buildDetailCard('Request Overview', [
                    _detailItem('Employee', request.employeeName,
                        isImportant: true),
                    _detailItem('Employee ID', request.employeeId),
                    _detailItem('Date', request.submissionDate),
                    _detailItem(
                        'Amount', '₹${request.amount.toStringAsFixed(2)}',
                        isImportant: true),
                    _detailItem('Type', request.requestType.toUpperCase()),
                    if (request.approvedBy != null)
                      _detailItem('Approved By', request.approvedBy!),
                    if (request.approvalDate != null)
                      _detailItem('Approval Date', request.approvalDate!),
                  ]),

                  // Description
                  if (request.description.isNotEmpty)
                    _buildDetailCard('Description', [
                      Text(
                        request.description,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ]),

                  // Payment Details Card
                  _buildDetailCard('Payment Details', [
                    if (request.payments.isNotEmpty)
                      ...request.payments.asMap().entries.map((entry) {
                        final index = entry.key;
                        final payment = entry.value;
                        return Container(
                          margin: EdgeInsets.only(top: index > 0 ? 12 : 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment ${index + 1}',
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _detailItem(
                                  'Amount', '₹${payment['amount'] ?? '0'}'),
                              if (payment['particulars'] != null &&
                                  payment['particulars']!.isNotEmpty)
                                _detailItem(
                                    'Particulars', payment['particulars']!)
                              else if (payment['description'] != null &&
                                  payment['description']!.isNotEmpty)
                                _detailItem(
                                    'Description', payment['description']!),
                              if (payment['claimType'] != null)
                                _detailItem(
                                    'Claim Type', payment['claimType']!),
                              if (payment['date'] != null)
                                _detailItem('Date', payment['date']!),
                              if (payment['attachmentPath'] != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Attachment:',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildAttachmentPreview(
                                        payment['attachmentPath']!),
                                  ],
                                )
                              else
                                _detailItem('Attachment', 'No attachment'),
                            ],
                          ),
                        );
                      }).toList()
                    else
                      const Text(
                        'No payment details available',
                        style: TextStyle(color: Colors.white70),
                      ),
                  ]),

                  // Action Buttons - Different for Verification vs Payment
                  Card(
                    color: const Color(0xFF1E1E1E),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            widget.isPaymentTab
                                ? 'Payment Action'
                                : 'Verification Action',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!widget.isPaymentTab)
                            // Verification Tab Actions
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isProcessing
                                        ? null
                                        : _financeApproveRequest,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(
                                          255, 113, 185, 115),
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
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isProcessing
                                        ? null
                                        : _showRejectDialog,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: const Color.fromARGB(
                                          255, 231, 226, 226),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: const Icon(Icons.cancel),
                                    label: const Text(
                                      'Reject',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            // Payment Tab Action
                            ElevatedButton.icon(
                              onPressed: _isProcessing ? null : _markAsPaid,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 15, horizontal: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.payment),
                              label: const Text(
                                'Mark as Paid',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          if (_isProcessing) ...[
                            const SizedBox(height: 16),
                            const CircularProgressIndicator(
                                color: Colors.tealAccent),
                            const SizedBox(height: 8),
                            const Text(
                              'Processing your request...',
                              style: TextStyle(color: Colors.white70),
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
}
