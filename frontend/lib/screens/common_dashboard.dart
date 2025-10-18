import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'approver_request_details.dart';

class Request {
  final int id;
  final String employeeId;
  final String employeeName;
  final String? avatarUrl;
  final String submissionDate;
  final double amount;
  final String description;
  final List<dynamic> payments;
  final String requestType;

  Request({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.submissionDate,
    required this.amount,
    required this.description,
    required this.payments,
    required this.requestType,
    this.avatarUrl,
  });
}

class CommonDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String authToken;

  const CommonDashboard({
    Key? key,
    required this.userData,
    required this.authToken,
  }) : super(key: key);

  @override
  State<CommonDashboard> createState() => _CommonDashboardState();
}

class _CommonDashboardState extends State<CommonDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService apiService = ApiService();

  List<Request> reimbursementRequests = [];
  List<Request> advanceRequests = [];

  // Filter states
  String _currentReimbursementFilter = 'latest';
  String _currentAdvanceFilter = 'latest';

  int approvedCount = 0;
  int rejectedCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeData();
  }

  Future<void> _initializeData() async {
    bool connected = await apiService.testConnection();
    if (!connected) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Connection Error'),
          content: const Text(
              'Cannot connect to server. Please check your network.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    await _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final pendingData =
          await apiService.getPendingApprovals(authToken: widget.authToken);

      // ✅ DEBUG: Print the entire API response structure
      debugPrint("=== FULL API RESPONSE ===");
      debugPrint(pendingData.toString());
      debugPrint("=========================");

      setState(() {
        reimbursementRequests =
            (pendingData['reimbursements_to_approve'] as List).map((r) {
          // ✅ DEBUG: Print each reimbursement structure
          debugPrint("=== REIMBURSEMENT ITEM ===");
          debugPrint("Keys: ${r.keys.toList()}");
          debugPrint("Payments type: ${r['payments']?.runtimeType}");
          if (r['payments'] is List) {
            debugPrint("Payments length: ${r['payments'].length}");
            if (r['payments'].isNotEmpty) {
              debugPrint(
                  "First payment keys: ${r['payments'][0].keys.toList()}");
            }
          }
          debugPrint("Project ID: ${r['projectId']}");
          debugPrint("=========================");

          return Request(
            id: r['id'],
            employeeId: r['employee_id'] ?? 'Unknown',
            employeeName: r['employee_name'] ?? 'Unknown',
            avatarUrl: r['employee_avatar'],
            submissionDate: r['date']?.toString() ?? '',
            amount: double.tryParse(r['amount'].toString()) ?? 0,
            description: r['description'] ?? '',
            payments: _parseReimbursementPayments(r),
            requestType: 'reimbursement',
          );
        }).toList();

        advanceRequests = (pendingData['advances_to_approve'] as List).map((r) {
          // ✅ DEBUG: Print each advance structure
          debugPrint("=== ADVANCE ITEM ===");
          debugPrint("Keys: ${r.keys.toList()}");
          debugPrint("Payments type: ${r['payments']?.runtimeType}");
          if (r['payments'] is List) {
            debugPrint("Payments length: ${r['payments'].length}");
            if (r['payments'].isNotEmpty) {
              debugPrint(
                  "First payment keys: ${r['payments'][0].keys.toList()}");
            }
          }
          debugPrint("Project ID: ${r['projectId']}");
          debugPrint("Project Name: ${r['projectName']}");
          debugPrint("====================");

          return Request(
            id: r['id'],
            employeeId: r['employee_id'] ?? 'Unknown',
            employeeName: r['employee_name'] ?? 'Unknown',
            avatarUrl: r['employee_avatar'],
            submissionDate: r['request_date']?.toString() ?? '',
            amount: double.tryParse(r['amount'].toString()) ?? 0,
            description: r['description'] ?? '',
            payments: _parseAdvancePayments(r),
            requestType: 'advance',
          );
        }).toList();
      });
    } catch (e) {
      debugPrint("Error fetching requests: $e");
    }
  }

// ✅ IMPROVED: Parse reimbursement payments with better field detection
  List<dynamic> _parseReimbursementPayments(
      Map<String, dynamic> reimbursement) {
    try {
      List<dynamic> payments = [];

      // Check if payments array exists
      if (reimbursement['payments'] is List &&
          reimbursement['payments'].isNotEmpty) {
        payments = reimbursement['payments'].map((payment) {
          // Try different possible field names for each field
          return {
            'amount': payment['amount']?.toString() ??
                payment['Amount']?.toString() ??
                '0',
            'paymentDate': payment['paymentDate'] ??
                payment['payment_date'] ??
                payment['date'] ??
                payment['Date'] ??
                reimbursement['date'],
            'claimType': payment['claimType'] ??
                payment['claim_type'] ??
                payment['type'] ??
                'Not specified',
            'customClaimType': payment['customClaimType'] ??
                payment['custom_claim_type'] ??
                payment['otherType'],
            'description': payment['description'] ??
                payment['Description'] ??
                payment['desc'] ??
                reimbursement['description'],
            'projectId': payment['projectId'] ??
                payment['project_id'] ??
                payment['projectID'] ??
                reimbursement['projectId'] ??
                reimbursement['project_id'],
            'attachmentPath': payment['attachmentPath'] ??
                payment['attachment_path'] ??
                payment['filePath'] ??
                payment['attachment'],
            'attachmentPaths': payment['attachmentPaths'] ??
                payment['attachment_paths'] ??
                payment['files'] ??
                [],
          };
        }).toList();
      } else {
        // If no payments array, create one from main reimbursement data
        payments = [
          {
            'amount': reimbursement['amount']?.toString() ?? '0',
            'paymentDate': reimbursement['date'] ??
                reimbursement['paymentDate'] ??
                reimbursement['payment_date'],
            'claimType': reimbursement['claimType'] ??
                reimbursement['claim_type'] ??
                'Not specified',
            'customClaimType': reimbursement['customClaimType'] ??
                reimbursement['custom_claim_type'],
            'description': reimbursement['description'] ?? '',
            'projectId': reimbursement['projectId'] ??
                reimbursement['project_id'] ??
                reimbursement['projectID'],
            'attachmentPath': reimbursement['attachmentPath'] ??
                reimbursement['attachment_path'],
            'attachmentPaths': reimbursement['attachmentPaths'] ??
                reimbursement['attachment_paths'] ??
                [],
          }
        ];
      }

      // ✅ DEBUG: Print parsed reimbursement payments
      debugPrint("=== PARSED REIMBURSEMENT PAYMENTS ===");
      debugPrint("Number of payments: ${payments.length}");
      if (payments.isNotEmpty) {
        debugPrint("First payment keys: ${payments[0].keys.toList()}");
        debugPrint("Project ID in payment: ${payments[0]['projectId']}");
        debugPrint("Payment Date in payment: ${payments[0]['paymentDate']}");
      }
      debugPrint("===================================");

      return payments;
    } catch (e) {
      debugPrint("Error parsing reimbursement payments: $e");
      return [];
    }
  }

// ✅ IMPROVED: Parse advance payments with better field detection
  List<dynamic> _parseAdvancePayments(Map<String, dynamic> advance) {
    try {
      List<dynamic> payments = [];

      // Check if payments array exists
      if (advance['payments'] is List && advance['payments'].isNotEmpty) {
        payments = advance['payments'].map((payment) {
          // Try different possible field names for each field
          return {
            'amount': payment['amount']?.toString() ??
                payment['Amount']?.toString() ??
                '0',
            'requestDate': payment['requestDate'] ??
                payment['request_date'] ??
                payment['date'] ??
                payment['Date'] ??
                advance['request_date'],
            'projectDate': payment['projectDate'] ??
                payment['project_date'] ??
                payment['projectDate'] ??
                advance['project_date'],
            'particulars': payment['particulars'] ??
                payment['Particulars'] ??
                payment['description'] ??
                payment['Description'] ??
                advance['description'],
            'projectId': payment['projectId'] ??
                payment['project_id'] ??
                payment['projectID'] ??
                advance['projectId'] ??
                advance['project_id'],
            'projectName': payment['projectName'] ??
                payment['project_name'] ??
                payment['projectName'] ??
                advance['projectName'] ??
                advance['project_name'],
            'attachmentPath': payment['attachmentPath'] ??
                payment['attachment_path'] ??
                payment['filePath'] ??
                payment['attachment'],
            'attachmentPaths': payment['attachmentPaths'] ??
                payment['attachment_paths'] ??
                payment['files'] ??
                [],
          };
        }).toList();
      } else {
        // If no payments array, create one from main advance data
        payments = [
          {
            'amount': advance['amount']?.toString() ?? '0',
            'requestDate': advance['request_date'] ?? advance['requestDate'],
            'projectDate': advance['project_date'] ?? advance['projectDate'],
            'particulars':
                advance['particulars'] ?? advance['description'] ?? '',
            'projectId': advance['projectId'] ??
                advance['project_id'] ??
                advance['projectID'],
            'projectName': advance['projectName'] ?? advance['project_name'],
            'attachmentPath':
                advance['attachmentPath'] ?? advance['attachment_path'],
            'attachmentPaths':
                advance['attachmentPaths'] ?? advance['attachment_paths'] ?? [],
          }
        ];
      }

      // ✅ DEBUG: Print parsed advance payments
      debugPrint("=== PARSED ADVANCE PAYMENTS ===");
      debugPrint("Number of payments: ${payments.length}");
      if (payments.isNotEmpty) {
        debugPrint("First payment keys: ${payments[0].keys.toList()}");
        debugPrint("Project ID in payment: ${payments[0]['projectId']}");
        debugPrint("Project Name in payment: ${payments[0]['projectName']}");
      }
      debugPrint("==============================");

      return payments;
    } catch (e) {
      debugPrint("Error parsing advance payments: $e");
      return [];
    }
  }

//filter methods
  List<Request> _getFilteredReimbursementRequests() {
    return _applyFilter(reimbursementRequests, _currentReimbursementFilter);
  }

  List<Request> _getFilteredAdvanceRequests() {
    return _applyFilter(advanceRequests, _currentAdvanceFilter);
  }

  List<Request> _applyFilter(List<Request> requests, String filter) {
    List<Request> filteredList = List.from(requests);

    switch (filter) {
      case 'latest':
        filteredList
            .sort((a, b) => b.submissionDate.compareTo(a.submissionDate));
        break;
      case 'oldest':
        filteredList
            .sort((a, b) => a.submissionDate.compareTo(b.submissionDate));
        break;
      case 'under_2000':
        filteredList = filteredList.where((r) => r.amount < 2000).toList();
        filteredList.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'above_2000':
        filteredList = filteredList.where((r) => r.amount >= 2000).toList();
        filteredList.sort((a, b) => b.amount.compareTo(a.amount));
        break;
    }

    return filteredList;
  }

  void _showFilterDialog(String type) {
    String currentFilter = type == 'Reimbursement'
        ? _currentReimbursementFilter
        : _currentAdvanceFilter;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Filter $type Requests',
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('Latest First', 'latest', currentFilter, type),
            _buildFilterOption('Oldest First', 'oldest', currentFilter, type),
            _buildFilterOption(
                'Amount Under ₹2000', 'under_2000', currentFilter, type),
            _buildFilterOption(
                'Amount Above ₹2000', 'above_2000', currentFilter, type),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(
      String title, String value, String currentFilter, String type) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      leading: Radio<String>(
        value: value,
        groupValue: currentFilter,
        onChanged: (String? newValue) {
          setState(() {
            if (type == 'Reimbursement') {
              _currentReimbursementFilter = newValue!;
            } else {
              _currentAdvanceFilter = newValue!;
            }
          });
          Navigator.pop(context);
        },
        activeColor: Colors.tealAccent,
      ),
    );
  }

  String _getFilterText(String filter) {
    switch (filter) {
      case 'latest':
        return 'Latest';
      case 'oldest':
        return 'Oldest';
      case 'under_2000':
        return 'Under ₹2000';
      case 'above_2000':
        return 'Above ₹2000';
      default:
        return 'Latest';
    }
  }

  double get totalReimbursement =>
      reimbursementRequests.fold(0, (sum, r) => sum + r.amount);
  double get totalAdvance =>
      advanceRequests.fold(0, (sum, r) => sum + r.amount);
  int get pendingCount => reimbursementRequests.length + advanceRequests.length;

  Future<void> _approveRequest(Request request, String type) async {
    bool success = await apiService.approveRequest(
      authToken: widget.authToken,
      requestId: request.id,
      requestType: type.toLowerCase(),
    );

    if (success) {
      setState(() {
        if (type == 'Reimbursement') {
          reimbursementRequests.removeWhere((r) => r.id == request.id);
        } else {
          advanceRequests.removeWhere((r) => r.id == request.id);
        }
        approvedCount++;
      });
    }
  }

  Future<void> _rejectRequest(
      Request request, String type, String reason) async {
    bool success = await apiService.rejectRequest(
      authToken: widget.authToken,
      requestId: request.id,
      requestType: type.toLowerCase(),
      reason: reason,
    );

    if (success) {
      setState(() {
        if (type == 'Reimbursement') {
          reimbursementRequests.removeWhere((r) => r.id == request.id);
        } else {
          advanceRequests.removeWhere((r) => r.id == request.id);
        }
        rejectedCount++;
      });
    }
  }

  void _showRejectDialog(Request request, String type) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Reject $type Request',
            style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter rejection reason',
            hintStyle: TextStyle(color: Colors.white54),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(context);
              _rejectRequest(request, type, reason);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  // 👇 CSV Download function for Common Dashboard
  Future<void> _downloadCSV(String period) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // For Mobile - Download from backend and share
      if (Platform.isAndroid || Platform.isIOS) {
        await _downloadAndShareCSV(period);
      }
      // For Web - Direct download
      else {
        await _downloadCSVForWeb(period);
      }
    } catch (error) {
      if (mounted) Navigator.pop(context);
      print("Error generating CSV: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error downloading CSV: $error"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 👇 Download from backend and share for Mobile
  Future<void> _downloadAndShareCSV(String period) async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://10.0.2.2:8000/api/employee/csv-download/?period=$period'),
        headers: {
          'Authorization': 'Token ${widget.authToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final fileName =
            'Xpensure_${period.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv';
        final filePath = '${directory.path}/$fileName';

        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) Navigator.pop(context);

        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Xpensure Requests - $period Period',
          subject: 'Xpensure CSV Export',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("CSV exported successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to download CSV: ${response.statusCode}');
      }
    } catch (error) {
      throw error;
    }
  }

  // 👇 Direct download for Web
  Future<void> _downloadCSVForWeb(String period) async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://10.0.2.2:8000/api/employee/csv-download/?period=$period'),
        headers: {
          'Authorization': 'Token ${widget.authToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("CSV downloaded successfully for $period period!"),
              backgroundColor: Colors.green,
            ),
          );
        }

        print("CSV Content Length: ${response.body.length} characters");
      } else {
        throw Exception('Failed to download CSV: ${response.statusCode}');
      }
    } catch (error) {
      throw error;
    }
  }

  // 👇 CSV Download Menu for App Bar
  Widget _buildCSVDownloadMenu() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.download, color: Colors.grey[300]),
      onSelected: _downloadCSV,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: "1 Month",
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text("1 Month", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem(
          value: "3 Months",
          child: Row(
            children: [
              Icon(Icons.calendar_view_month, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text("3 Months", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem(
          value: "6 Months",
          child: Row(
            children: [
              Icon(Icons.date_range, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text("6 Months", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem(
          value: "1 Year",
          child: Row(
            children: [
              Icon(Icons.calendar_view_day, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text("1 Year", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
      color: Color(0xFF1E1E1E),
    );
  }

  Widget _buildStatsCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        height: 90,
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(title,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final pending = pendingCount;
    final total = approvedCount + rejectedCount + pending;
    if (total == 0) {
      return const Center(
          child: Text('No data yet', style: TextStyle(color: Colors.white54)));
    }
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 50,
        sections: [
          PieChartSectionData(
            color: Colors.greenAccent,
            value: approvedCount.toDouble(),
            title: 'Approved\n$approvedCount',
            radius: 70,
            titleStyle: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold),
          ),
          PieChartSectionData(
            color: Colors.redAccent,
            value: rejectedCount.toDouble(),
            title: 'Rejected\n$rejectedCount',
            radius: 70,
            titleStyle: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold),
          ),
          PieChartSectionData(
            color: Colors.orangeAccent,
            value: pending.toDouble(),
            title: 'Pending\n$pending',
            radius: 70,
            titleStyle: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _emptyListWidget(String message) => Center(
      child: Text(message, style: const TextStyle(color: Colors.white54)));

  // Helper method to extract file name from path
  String _getFileName(String path) {
    try {
      return path.split('/').last;
    } catch (e) {
      return 'Unknown file';
    }
  }

  // Check if file is an image
  bool _isImageFile(String path) {
    final ext = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  }

  // Check if file is a PDF
  bool _isPdfFile(String path) {
    return path.toLowerCase().endsWith('.pdf');
  }

  // View attachment with actual file display
  void _viewAttachment(String attachmentPath) {
    if (_isImageFile(attachmentPath)) {
      _showImageDialog(attachmentPath);
    } else if (_isPdfFile(attachmentPath)) {
      _openPdf(attachmentPath);
    } else {
      _downloadFile(attachmentPath);
    }
  }

  // Show image in full screen dialog
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
              child: ElevatedButton(
                onPressed: () => _downloadFile(imagePath),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent),
                child: const Text('Download'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Open PDF file
  Future<void> _openPdf(String pdfPath) async {
    try {
      final url = pdfPath.startsWith('http') ? pdfPath : 'file://$pdfPath';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot open PDF file')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error opening PDF: $e')));
    }
  }

  // Download file functionality
  Future<void> _downloadFile(String filePath) async {
    try {
      if (filePath.startsWith('http')) {
        // For network files - download and save
        final response = await http.get(Uri.parse(filePath));
        final documentsDir = await getApplicationDocumentsDirectory();
        final fileName = _getFileName(filePath);
        final file = File('${documentsDir.path}/$fileName');

        await file.writeAsBytes(response.bodyBytes);

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File downloaded to: ${file.path}')));
      } else {
        // For local files - just show path
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('File location: $filePath')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error downloading file: $e')));
    }
  }

  // Build attachment preview widget
  Widget _buildAttachmentPreview(String attachmentPath) {
    if (_isImageFile(attachmentPath)) {
      return Column(
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: attachmentPath.startsWith('http')
                ? Image.network(attachmentPath, fit: BoxFit.cover)
                : Image.file(File(attachmentPath), fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _showImageDialog(attachmentPath),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('View Image'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _downloadFile(attachmentPath),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('Download'),
              ),
            ],
          ),
        ],
      );
    } else if (_isPdfFile(attachmentPath)) {
      return Column(
        children: [
          const Icon(Icons.picture_as_pdf, size: 50, color: Colors.red),
          const SizedBox(height: 8),
          Text(_getFileName(attachmentPath),
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _openPdf(attachmentPath),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Open PDF'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _downloadFile(attachmentPath),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('Download'),
              ),
            ],
          ),
        ],
      );
    } else {
      return Column(
        children: [
          const Icon(Icons.insert_drive_file, size: 50, color: Colors.grey),
          const SizedBox(height: 8),
          Text(_getFileName(attachmentPath),
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _downloadFile(attachmentPath),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Download File'),
          ),
        ],
      );
    }
  }

  void _showDetailsDialog(Request request) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Request Details',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Employee:', request.employeeName),
              _detailRow('Date:', request.submissionDate),
              _detailRow(
                  'Total Amount:', '₹${request.amount.toStringAsFixed(2)}'),
              _detailRow('Description:', request.description),
              const SizedBox(height: 16),
              const Text('Payment Details:',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              if (request.payments != null && request.payments.isNotEmpty)
                ...request.payments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final payment = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment ${index + 1}:',
                            style: const TextStyle(
                                color: Colors.tealAccent,
                                fontWeight: FontWeight.bold)),
                        _detailRow('Amount:',
                            '₹${payment['amount']?.toString() ?? '0'}'),
                        _detailRow('Description:',
                            payment['description']?.toString() ?? ''),
                        if (payment['claimType'] != null)
                          _detailRow('Claim Type:',
                              payment['claimType']?.toString() ?? ''),
                        if (payment['date'] != null)
                          _detailRow(
                              'Date:', payment['date']?.toString() ?? ''),

                        // ✅ ACTUAL FILE DISPLAY
                        if (payment['attachmentPath'] != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              const Text('Attachment:',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              _detailRow('File:',
                                  _getFileName(payment['attachmentPath'])),
                              const SizedBox(height: 8),
                              _buildAttachmentPreview(
                                  payment['attachmentPath']),
                            ],
                          )
                        else
                          _detailRow('Attachment:', 'No attachment'),
                      ],
                    ),
                  );
                }).toList()
              else
                const Text('No payment details available',
                    style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close',
                  style: TextStyle(color: Colors.tealAccent))),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: RichText(
          text: TextSpan(
            text: '$label ',
            style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 14),
            children: [
              TextSpan(
                  text: value,
                  style: const TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.normal))
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final fullName = widget.userData['fullName'] ?? 'Employee';
    final avatarUrl = widget.userData['avatar'];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Expanded(
              child: Text(
                "Welcome, $fullName",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18),
              ),
            ),
            _buildCSVDownloadMenu(), // ✅ ADD CSV DOWNLOAD BUTTON
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[700],
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))
                  : null,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                _buildStatsCard(
                    'Pending Reimbursement',
                    '${reimbursementRequests.length}',
                    const Color.fromARGB(255, 230, 219, 99)),
                _buildStatsCard('Pending Advance', '${advanceRequests.length}',
                    const Color.fromARGB(255, 230, 219, 99)),
              ],
            ),
          ),
          Container(
            color: const Color(0xFF1E1E1E),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.tealAccent,
              labelColor: Colors.tealAccent,
              unselectedLabelColor: Colors.white54,
              labelStyle:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: "Reimbursement"),
                Tab(text: "Advance"),
                Tab(text: "Overview"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestList('Reimbursement', reimbursementRequests),
                _buildRequestList('Advance', advanceRequests),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildStatsCard(
                              'Total Reimbursement',
                              '₹${totalReimbursement.toStringAsFixed(2)}',
                              const Color.fromARGB(255, 129, 160, 214)),
                          _buildStatsCard(
                              'Total Advance',
                              '₹${totalAdvance.toStringAsFixed(2)}',
                              const Color.fromARGB(255, 129, 160, 214)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(child: _buildPieChart()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestList(String type, List<Request> requests) {
    final filteredRequests = type == 'Reimbursement'
        ? _getFilteredReimbursementRequests()
        : _getFilteredAdvanceRequests();

    final currentFilter = type == 'Reimbursement'
        ? _currentReimbursementFilter
        : _currentAdvanceFilter;

    return Column(
      children: [
        // Filter header
        Container(
          color: const Color(0xFF1E1E1E),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredRequests.length} requests found',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              Row(
                children: [
                  Text(
                    'Filter: ${_getFilterText(currentFilter)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon:
                        const Icon(Icons.filter_list, color: Colors.tealAccent),
                    onPressed: () => _showFilterDialog(type),
                    tooltip: 'Filter requests',
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchRequests,
            child: filteredRequests.isEmpty
                ? _emptyListWidget('No pending $type requests')
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredRequests.length,
                    itemBuilder: (context, index) {
                      final request = filteredRequests[index];
                      return _RequestTile(
                        request: request,
                        type: type,
                        onApprove: () => _approveRequest(request, type),
                        onReject: () => _showRejectDialog(request, type),
                        onDetails: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ApproverRequestDetails(
                                request: request,
                                authToken: widget.authToken,
                              ),
                            ),
                          );
                          if (result == true) {
                            setState(() {
                              if (type == 'Reimbursement') {
                                reimbursementRequests
                                    .removeWhere((r) => r.id == request.id);
                              } else {
                                advanceRequests
                                    .removeWhere((r) => r.id == request.id);
                              }
                            });
                          }
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _RequestTile extends StatelessWidget {
  final Request request;
  final String type;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDetails;

  const _RequestTile({
    Key? key,
    required this.request,
    required this.type,
    required this.onApprove,
    required this.onReject,
    required this.onDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color pastelTeal = Color(0xFF80CBC4);
    const Color pastelOrange = Color(0xFFFFAB91);

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: request.avatarUrl != null
                          ? NetworkImage(request.avatarUrl!)
                          : null,
                      child: request.avatarUrl == null
                          ? const Icon(Icons.person, color: Colors.white70)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(request.employeeName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color:
                          type == 'Reimbursement' ? pastelTeal : pastelOrange,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(type,
                      style: const TextStyle(
                          color: Colors.black87, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Submitted: ${request.submissionDate}',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 6),
            Text('Amount: ₹${request.amount.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            if (request.payments != null && request.payments.isNotEmpty)
              Text('Payments: ${request.payments.length}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: onDetails,
                    child: const Text('Details',
                        style: TextStyle(color: Color(0xFF80CBC4)))),
                const SizedBox(width: 8),
                ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: pastelTeal,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    child: const Text('Approve')),
                const SizedBox(width: 8),
                ElevatedButton(
                    onPressed: onReject,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: pastelOrange,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    child: const Text('Reject')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
