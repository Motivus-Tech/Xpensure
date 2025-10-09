import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

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
        case 'employeeAvatar':
          return request.employeeAvatar;
        case 'rawData':
          return request.rawData;
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

  void _approveRequest() async {
    setState(() => _isProcessing = true);

    final success = await apiService.approveRequest(
      authToken: widget.authToken,
      requestId: widget.requestId,
      requestType: widget.requestType,
    );

    setState(() => _isProcessing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request Approved Successfully'),
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

  void _rejectRequest() {
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
                requestId: widget.requestId,
                requestType: widget.requestType,
                reason: reason,
              );

              setState(() => _isProcessing = false);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Request Rejected'),
                    backgroundColor: Colors.red,
                  ),
                );
                Navigator.pop(context, true);
              }
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

  Widget _detailItem(String label, dynamic value, {bool isImportant = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.toString(),
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

  // FIXED: Proper type handling for payments
  Widget _buildPaymentDetails() {
    final dynamic paymentsData = widget.getRequestData('payments');

    // Handle different possible types for payments
    if (paymentsData == null) {
      return const Text(
        'No payment details available',
        style: TextStyle(color: Colors.white70),
      );
    }

    List<dynamic> payments = [];

    // Convert payments to a list we can work with
    if (paymentsData is List) {
      payments = paymentsData;
    } else if (paymentsData is Map) {
      payments = [paymentsData];
    } else {
      return _detailItem('Payment Data',
          'Unexpected data format: ${paymentsData.runtimeType}');
    }

    if (payments.isEmpty) {
      return const Text(
        'No payment details available',
        style: TextStyle(color: Colors.white70),
      );
    }

    // Build payment widgets
    final paymentWidgets = <Widget>[];

    for (int index = 0; index < payments.length; index++) {
      final payment = payments[index];

      final paymentWidget = Container(
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
            // Safe payment data access
            ..._buildPaymentItems(payment),
          ],
        ),
      );

      paymentWidgets.add(paymentWidget);
    }

    return Column(
      children: paymentWidgets,
    );
  }

  // FIXED: Safe payment data access with proper type checking
  List<Widget> _buildPaymentItems(dynamic payment) {
    final items = <Widget>[];

    // Handle Map type payment
    if (payment is Map<String, dynamic>) {
      if (payment['amount'] != null) {
        items.add(_detailItem('Amount', '₹${payment['amount']}'));
      }

      if (payment['particulars'] != null &&
          payment['particulars'].toString().isNotEmpty) {
        items
            .add(_detailItem('Particulars', payment['particulars'].toString()));
      } else if (payment['description'] != null &&
          payment['description'].toString().isNotEmpty) {
        items
            .add(_detailItem('Description', payment['description'].toString()));
      }

      if (payment['claimType'] != null) {
        items.add(_detailItem('Claim Type', payment['claimType'].toString()));
      }

      if (payment['date'] != null) {
        items.add(_detailItem('Date', payment['date'].toString()));
      }

      // Handle attachment
      if (payment['attachmentPath'] != null &&
          payment['attachmentPath'].toString().isNotEmpty) {
        items.addAll([
          const SizedBox(height: 8),
          const Text(
            'Attachment:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildAttachmentPreview(payment['attachmentPath'].toString()),
        ]);
      } else {
        items.add(_detailItem('Attachment', 'No attachment'));
      }
    }
    // Handle other types (like String, int, etc.)
    else {
      items.add(_detailItem('Payment', payment.toString()));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Request Details',
          style: TextStyle(
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
                  // Request Overview Card
                  _buildDetailCard('Request Overview', [
                    _detailItem(
                        'Employee', widget.getRequestData('employeeName'),
                        isImportant: true),
                    _detailItem('Date', widget.getRequestData('date')),
                    _detailItem('Amount',
                        '₹${(widget.getRequestData('amount') ?? 0).toStringAsFixed(2)}',
                        isImportant: true),
                    _detailItem('Type', widget.getRequestData('type')),
                    _detailItem(
                        'Description', widget.getRequestData('description')),
                  ]),

                  // Payment Details Card
                  _buildDetailCard('Payment Details', [
                    _buildPaymentDetails(),
                  ]),

                  // Action Buttons
                  Card(
                    color: const Color(0xFF1E1E1E),
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
