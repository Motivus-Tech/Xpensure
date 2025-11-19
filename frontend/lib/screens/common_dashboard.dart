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
            style: const TextStyle(color: Colors.white)),
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

  // CSV Download function - APPROVER VERSION
  Future<void> _downloadCSV(String period) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Use approver CSV endpoint
      String baseUrl = 'http://10.0.2.2:8000'; // For Android emulator
      // String baseUrl = 'http://your-real-server-ip:8000'; // For real device

      final url =
          Uri.parse('$baseUrl/api/approver/csv-download/?period=$period');

      print('Downloading Approver CSV from: $url');
      print('Period: $period');
      print('Approver Token: ${widget.authToken.substring(0, 20)}...');

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
        print(
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
      print("Error generating CSV: $error");
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

      print('CSV saved to: $filePath');
      print('File exists: ${await file.exists()}');
      print('File size: ${(await file.length())} bytes');

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Xpensure Approver Actions - $period Period',
        subject: 'Xpensure Approver CSV Export',
      );

      _showSuccessSnackBar("CSV exported successfully!");
    } catch (error) {
      print("Error sharing CSV: $error");
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

  Widget _emptyListWidget(String message) => Center(
      child: Text(message, style: const TextStyle(color: Colors.white54)));

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
            _buildCSVDownloadMenu(),
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
              ],
            ),
          ),
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
