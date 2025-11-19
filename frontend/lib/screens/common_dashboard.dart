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

  // Employee ID search - FIXED: Remove debouncing
  String _reimbursementEmployeeSearch = '';
  String _advanceEmployeeSearch = '';

  // Timer for real-time updates
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();

    // Set up real-time refresh every 30 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _fetchRequests();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    bool connected = await apiService.testConnection();
    if (!connected) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Connection Error',
              style: TextStyle(color: Colors.white)),
          content: const Text(
              'Cannot connect to server. Please check your network.',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
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

      setState(() {
        reimbursementRequests =
            (pendingData['reimbursements_to_approve'] as List).map((r) {
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

  List<dynamic> _parseReimbursementPayments(
      Map<String, dynamic> reimbursement) {
    try {
      List<dynamic> payments = [];

      if (reimbursement['payments'] is List &&
          reimbursement['payments'].isNotEmpty) {
        payments = reimbursement['payments'].map((payment) {
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

      return payments;
    } catch (e) {
      debugPrint("Error parsing reimbursement payments: $e");
      return [];
    }
  }

  List<dynamic> _parseAdvancePayments(Map<String, dynamic> advance) {
    try {
      List<dynamic> payments = [];

      if (advance['payments'] is List && advance['payments'].isNotEmpty) {
        payments = advance['payments'].map((payment) {
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

      return payments;
    } catch (e) {
      debugPrint("Error parsing advance payments: $e");
      return [];
    }
  }

  // Filter methods
  List<Request> _getFilteredReimbursementRequests() {
    List<Request> filtered =
        _applyFilter(reimbursementRequests, _currentReimbursementFilter);

    // Apply employee ID search
    if (_reimbursementEmployeeSearch.isNotEmpty) {
      filtered = filtered
          .where((request) =>
              request.employeeId
                  .toLowerCase()
                  .contains(_reimbursementEmployeeSearch.toLowerCase()) ||
              request.employeeName
                  .toLowerCase()
                  .contains(_reimbursementEmployeeSearch.toLowerCase()))
          .toList();
    }

    return filtered;
  }

  List<Request> _getFilteredAdvanceRequests() {
    List<Request> filtered =
        _applyFilter(advanceRequests, _currentAdvanceFilter);

    // Apply employee ID search
    if (_advanceEmployeeSearch.isNotEmpty) {
      filtered = filtered
          .where((request) =>
              request.employeeId
                  .toLowerCase()
                  .contains(_advanceEmployeeSearch.toLowerCase()) ||
              request.employeeName
                  .toLowerCase()
                  .contains(_advanceEmployeeSearch.toLowerCase()))
          .toList();
    }

    return filtered;
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

    List<Map<String, String>> filterOptions = [
      {'title': 'Latest First', 'value': 'latest'},
      {'title': 'Oldest First', 'value': 'oldest'},
      {'title': 'Amount Under ₹2000', 'value': 'under_2000'},
      {'title': 'Amount Above ₹2000', 'value': 'above_2000'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Filter $type Requests',
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: filterOptions.map((option) {
            return _buildFilterOption(
              option['title']!,
              option['value']!,
              currentFilter,
              type,
            );
          }).toList(),
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
        activeColor: Colors.deepPurpleAccent,
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
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter rejection reason',
            hintStyle: const TextStyle(color: Colors.white54),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: const Color(0xFF1F1F1F),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white70))),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.redAccent, Colors.deepOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) return;
                Navigator.pop(context);
                _rejectRequest(request, type, reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  const Text('Reject', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // CSV Download function - APPROVER VERSION
  Future<void> _downloadCSV(String period) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent)),
              ],
            ),
          ),
        ),
      );

      // Use approver CSV endpoint
      String baseUrl = 'http://10.0.2.2:8000'; // For Android emulator

      final url =
          Uri.parse('$baseUrl/api/approver/csv-download/?period=$period');

      debugPrint('Downloading Approver CSV from: $url');
      debugPrint('Period: $period');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Token ${widget.authToken}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      // Close loading indicator
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        debugPrint(
            'Approver CSV download successful, content length: ${response.bodyBytes.length} bytes');

        // For mobile - download and share
        await _downloadAndShareCSV(response.bodyBytes, period);
      } else {
        throw Exception(
            'Failed to download CSV: HTTP ${response.statusCode} - ${response.body}');
      }
    } on TimeoutException {
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar('Request timed out. Please try again.');
    } catch (error) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error generating CSV: $error");
      _showErrorSnackBar('Error downloading CSV: $error');
    }
  }

  Future<void> _downloadAndShareCSV(List<int> bytes, String period) async {
    try {
      final directory = await getTemporaryDirectory();
      final fileName =
          'Xpensure_Approver_Actions_${period.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = '${directory.path}/$fileName';

      final File file = File(filePath);
      await file.writeAsBytes(bytes);

      debugPrint('CSV saved to: $filePath');

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Xpensure Approver Actions - $period Period',
        subject: 'Xpensure Approver CSV Export',
      );

      _showSuccessSnackBar("CSV exported successfully!");
    } catch (error) {
      debugPrint("Error sharing CSV: $error");
      _showErrorSnackBar('Error sharing CSV: $error');
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildCSVDownloadMenu() {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.deepPurple, Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.download, color: Colors.white, size: 20),
      ),
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

  // FIXED: Compact stats card to prevent overflow
  Widget _buildStatsCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        height: 70, // Reduced height
        margin: const EdgeInsets.all(4), // Reduced margin
        padding: const EdgeInsets.all(8), // Reduced padding
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10, // Smaller font
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14, // Smaller font
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyListWidget(String message) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 48, color: Colors.white54),
            SizedBox(height: 12),
            Text(message,
                style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final userRole = widget.userData['role'] ?? 'Approver';
    final userName = widget.userData['name'] ?? 'Approver';
    final userAvatar = widget.userData['avatar'] ??
        widget.userData['profile_picture'] ??
        widget.userData['image_url'];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            // Xpensure logo with welcome message below
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 32,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepPurple, Colors.purpleAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                  child: const Center(
                    child: Text(
                      "Xpensure",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Welcome, $userName", // FIXED: Shows actual name instead of "Approver"
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10, // Small font size
                  ),
                ),
              ],
            ),
            const Spacer(),
            _buildCSVDownloadMenu(),
            const SizedBox(width: 12),
            // User Avatar - FIXED: Proper avatar display
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.deepPurpleAccent,
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: userAvatar != null
                    ? Image.network(
                        userAvatar,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildFallbackAvatar(userName);
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildFallbackAvatar(userName);
                        },
                      )
                    : _buildFallbackAvatar(userName),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.deepPurpleAccent,
          labelColor: Colors.deepPurpleAccent,
          unselectedLabelColor: Colors.white54,
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "Reimbursement"),
            Tab(text: "Advance"),
          ],
        ),
      ),
      body: Column(
        children: [
          // Stats Cards - FIXED: More compact container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            height: 90, // Fixed height
            child: Row(
              children: [
                _buildStatsCard(
                  'Pending Reimbursement',
                  '${reimbursementRequests.length}',
                  const Color.fromARGB(255, 103, 168, 221),
                ),
                _buildStatsCard(
                  'Pending Advance',
                  '${advanceRequests.length}',
                  const Color.fromARGB(255, 132, 222, 122),
                ),
              ],
            ),
          ),

          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestList('Reimbursement', reimbursementRequests),
                _buildRequestList('Advance', advanceRequests),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackAvatar(String userName) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.tealAccent, Colors.greenAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
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

    // Use local state for search to prevent rebuilds
    return _RequestListContent(
      type: type,
      filteredRequests: filteredRequests,
      currentFilter: currentFilter,
      reimbursementEmployeeSearch: _reimbursementEmployeeSearch,
      advanceEmployeeSearch: _advanceEmployeeSearch,
      onSearchChanged: (value) {
        setState(() {
          if (type == 'Reimbursement') {
            _reimbursementEmployeeSearch = value;
          } else {
            _advanceEmployeeSearch = value;
          }
        });
      },
      onApprove: _approveRequest,
      onReject: _showRejectDialog,
      onDetails: (request) async {
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
              reimbursementRequests.removeWhere((r) => r.id == request.id);
            } else {
              advanceRequests.removeWhere((r) => r.id == request.id);
            }
          });
        }
      },
      onRefresh: _fetchRequests,
      emptyListWidget: _emptyListWidget,
      showFilterDialog: _showFilterDialog,
      getFilterText: _getFilterText,
    );
  }
}

// Separate widget for request list content to prevent rebuilds
class _RequestListContent extends StatefulWidget {
  final String type;
  final List<Request> filteredRequests;
  final String currentFilter;
  final String reimbursementEmployeeSearch;
  final String advanceEmployeeSearch;
  final Function(String) onSearchChanged;
  final Function(Request, String) onApprove;
  final Function(Request, String) onReject;
  final Function(Request) onDetails;
  final Future<void> Function() onRefresh;
  final Widget Function(String) emptyListWidget;
  final Function(String) showFilterDialog;
  final Function(String) getFilterText;

  const _RequestListContent({
    Key? key,
    required this.type,
    required this.filteredRequests,
    required this.currentFilter,
    required this.reimbursementEmployeeSearch,
    required this.advanceEmployeeSearch,
    required this.onSearchChanged,
    required this.onApprove,
    required this.onReject,
    required this.onDetails,
    required this.onRefresh,
    required this.emptyListWidget,
    required this.showFilterDialog,
    required this.getFilterText,
  }) : super(key: key);

  @override
  State<_RequestListContent> createState() => _RequestListContentState();
}

class _RequestListContentState extends State<_RequestListContent> {
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.type == 'Reimbursement'
          ? widget.reimbursementEmployeeSearch
          : widget.advanceEmployeeSearch,
    );
    _searchFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_RequestListContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller text if search changed from parent
    final currentSearch = widget.type == 'Reimbursement'
        ? widget.reimbursementEmployeeSearch
        : widget.advanceEmployeeSearch;
    if (_searchController.text != currentSearch) {
      _searchController.text = currentSearch;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter header with search
        Container(
          color: const Color(0xFF1E1E1E),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.filteredRequests.length} requests found',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Row(
                    children: [
                      Text(
                        'Filter: ${widget.getFilterText(widget.currentFilter)}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.deepPurple, Colors.purpleAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.filter_list,
                              color: Colors.white, size: 20),
                          onPressed: () => widget.showFilterDialog(widget.type),
                          tooltip: 'Filter requests',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Employee ID Search - FIXED: No debouncing, immediate update
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F1F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (value) {
                    // Immediate update without delay
                    widget.onSearchChanged(value);
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by Employee ID or Name...',
                    hintStyle:
                        const TextStyle(color: Colors.white54, fontSize: 14),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.white54, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    // Clear button
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: Colors.white54, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              widget.onSearchChanged('');
                              _searchFocusNode.requestFocus();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Request List
        Expanded(
          child: RefreshIndicator(
            backgroundColor: Color(0xFF1E1E1E),
            color: Colors.deepPurpleAccent,
            onRefresh: widget.onRefresh,
            child: widget.filteredRequests.isEmpty
                ? widget.emptyListWidget('No pending ${widget.type} requests')
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.filteredRequests.length,
                    itemBuilder: (context, index) {
                      final request = widget.filteredRequests[index];
                      return _RequestTile(
                        request: request,
                        type: widget.type,
                        onApprove: () => widget.onApprove(request, widget.type),
                        onReject: () => widget.onReject(request, widget.type),
                        onDetails: () => widget.onDetails(request),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Employee Avatar - FIXED: Proper avatar display
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.deepPurpleAccent,
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: request.avatarUrl != null &&
                                  request.avatarUrl!.isNotEmpty
                              ? Image.network(
                                  request.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildEmployeeFallbackAvatar(
                                        request.employeeName);
                                  },
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return _buildEmployeeFallbackAvatar(
                                        request.employeeName);
                                  },
                                )
                              : _buildEmployeeFallbackAvatar(
                                  request.employeeName),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.employeeName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${request.employeeId}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: type == 'Reimbursement'
                          ? [Colors.blueAccent, Colors.lightBlueAccent]
                          : [Colors.greenAccent, Colors.tealAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(type,
                      style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text('Submitted: ${request.submissionDate}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
                Text('₹${request.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            if (request.payments != null && request.payments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${request.payments.length} payment(s)',
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 11)),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDetails,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text('Details',
                      style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                ),
                const SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.redAccent, Colors.deepOrange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    onPressed: onReject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Reject',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.greenAccent, Colors.tealAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Approve',
                        style: TextStyle(color: Colors.black87, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeFallbackAvatar(String employeeName) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.purpleAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          employeeName.isNotEmpty ? employeeName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
