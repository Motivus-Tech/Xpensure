import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'finance_request_details.dart';

class FinanceDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String authToken;

  const FinanceDashboard({
    Key? key,
    required this.userData,
    required this.authToken,
  }) : super(key: key);

  @override
  State<FinanceDashboard> createState() => _FinanceDashboardState();
}

class _FinanceDashboardState extends State<FinanceDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService apiService = ApiService();

  List<FinanceRequest> verificationRequests = [];
  List<FinanceRequest> paymentRequests = [];

  String _currentVerificationFilter = 'latest';
  String _currentPaymentFilter = 'latest';

  int approvedCount = 0;
  int rejectedCount = 0;
  int pendingPaymentCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  Future<void> _initializeData() async {
    bool connected = await apiService.testConnection();
    if (!connected) {
      _showErrorDialog('Connection Error',
          'Cannot connect to server. Please check your network.');
      return;
    }
    await _fetchRequests();
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.tealAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchRequests() async {
    setState(() => isLoading = true);

    try {
      final financeData =
          await apiService.getFinanceRequests(authToken: widget.authToken);

      final pendingList =
          financeData['pending_finance_approval'] as List? ?? [];
      final ceoApprovedList = financeData['ceo_approved'] as List? ?? [];

      setState(() {
        // ✅ VERIFICATION TAB - Only show pending finance approval
        verificationRequests = pendingList
            .where((r) =>
                r['status'] == 'Pending Finance' ||
                r['status'] == 'Pending') // ✅ Only finance pending
            .map((r) => FinanceRequest(
                  id: r['id'] ?? 0,
                  employeeId: r['employee_id'] ?? 'Unknown',
                  employeeName: r['employee_name'] ?? 'Unknown',
                  avatarUrl: r['employee_avatar'] ?? '',
                  submissionDate: _formatDate(r['date']),
                  amount: double.tryParse(r['amount']?.toString() ?? '0') ?? 0,
                  description: r['description'] ?? '',
                  payments: r['payments'] ?? [],
                  requestType: r['request_type'] ?? 'reimbursement',
                  status: 'pending_finance',
                ))
            .toList();

        // ✅ PAYMENT TAB - Only CEO approved requests
        paymentRequests = ceoApprovedList
            .where((r) =>
                r['status'] == 'Approved') // ✅ Only fully approved requests
            .map((r) => FinanceRequest(
                  id: r['id'] ?? 0,
                  employeeId: r['employee_id'] ?? 'Unknown',
                  employeeName: r['employee_name'] ?? 'Unknown',
                  avatarUrl: r['employee_avatar'] ?? '',
                  submissionDate: _formatDate(r['date']),
                  amount: double.tryParse(r['amount']?.toString() ?? '0') ?? 0,
                  description: r['description'] ?? '',
                  payments: r['payments'] ?? [],
                  requestType: r['request_type'] ?? 'reimbursement',
                  status: 'ceo_approved',
                  approvedBy: 'CEO', // ✅ Explicitly set
                  approvalDate: _formatDate(r['approval_date']),
                ))
            .toList();

        approvedCount = financeData['approved_count'] ?? 0;
        rejectedCount = financeData['rejected_count'] ?? 0;
        pendingPaymentCount =
            financeData['pending_payment_count'] ?? paymentRequests.length;

        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Error fetching finance requests: $e");
      _showErrorDialog(
          'Error', 'Failed to load finance requests. Please try again.');
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown Date';
    try {
      final dateStr = date.toString();
      if (dateStr.contains('T')) {
        return dateStr.split('T')[0];
      }
      return dateStr;
    } catch (_) {
      return 'Unknown Date';
    }
  }

  List<FinanceRequest> _getFilteredVerificationRequests() =>
      _applyFilter(verificationRequests, _currentVerificationFilter);

  List<FinanceRequest> _getFilteredPaymentRequests() =>
      _applyFilter(paymentRequests, _currentPaymentFilter);

  List<FinanceRequest> _applyFilter(
      List<FinanceRequest> requests, String filter) {
    List<FinanceRequest> filteredList = List.from(requests);

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
    String currentFilter = type == 'Verification'
        ? _currentVerificationFilter
        : _currentPaymentFilter;

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
            if (type == 'Verification') {
              _currentVerificationFilter = newValue!;
            } else {
              _currentPaymentFilter = newValue!;
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

  Future<void> _approveRequest(FinanceRequest request) async {
    bool success = await apiService.financeApproveRequest(
      authToken: widget.authToken,
      requestId: request.id,
      requestType: request.requestType,
    );

    if (success) {
      setState(() {
        verificationRequests.removeWhere((r) => r.id == request.id);
        approvedCount++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${request.requestType} approved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve ${request.requestType}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectRequest(FinanceRequest request, String reason) async {
    bool success = await apiService.financeRejectRequest(
      authToken: widget.authToken,
      requestId: request.id,
      requestType: request.requestType,
      reason: reason,
    );

    if (success) {
      setState(() {
        verificationRequests.removeWhere((r) => r.id == request.id);
        rejectedCount++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${request.requestType} rejected'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject ${request.requestType}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processPayment(FinanceRequest request) async {
    bool success = await apiService.markAsPaid(
      authToken: widget.authToken,
      requestId: request.id,
      requestType: request.requestType,
    );

    if (success) {
      setState(() {
        paymentRequests.removeWhere((r) => r.id == request.id);
        pendingPaymentCount--;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment processed for ${request.employeeName}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process payment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRejectDialog(FinanceRequest request) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Reject ${request.requestType}',
            style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter rejection reason',
            hintStyle: TextStyle(color: Colors.white54),
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
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
                      content: Text('Please enter rejection reason')),
                );
                return;
              }
              Navigator.pop(context);
              _rejectRequest(request, reason);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  // Report Generation
  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Generate Report',
            style: TextStyle(color: Colors.white)),
        content: const Text('Select time period for report:',
            style: TextStyle(color: Colors.white70)),
        actions: [
          Column(
            children: [
              _buildReportOption('Last 1 Month', 1),
              _buildReportOption('Last 3 Months', 3),
              _buildReportOption('Last 6 Months', 6),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportOption(String title, int months) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      leading: const Icon(Icons.description, color: Colors.tealAccent),
      onTap: () {
        Navigator.pop(context);
        _generateCSVReport(months);
      },
    );
  }

  Future<void> _generateCSVReport(int months) async {
    try {
      final response = await apiService.generateFinanceReport(
        authToken: widget.authToken,
        months: months,
      );

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final file =
            File('${directory.path}/finance_report_${months}months.csv');
        await file.writeAsBytes(response.bodyBytes);

        _downloadFile(file.path);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$months month report generated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to generate report: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadFile(String filePath) async {
    try {
      if (await canLaunchUrl(Uri.parse('file://$filePath'))) {
        await launchUrl(Uri.parse('file://$filePath'));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('File saved to: $filePath')));
      }
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('File saved to: $filePath')));
    }
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
          border: Border.all(color: Colors.white24, width: 1),
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
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, color: Colors.white54, size: 64),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: Colors.white54, fontSize: 16)),
        ],
      ));

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.tealAccent),
          SizedBox(height: 16),
          Text('Loading Finance Dashboard...',
              style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName = widget.userData['fullName'] ?? 'Finance User';
    final avatarUrl = widget.userData['avatar'] ?? '';

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
                "Finance Dashboard",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.tealAccent),
              onPressed: _fetchRequests,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: const Icon(Icons.description, color: Colors.tealAccent),
              onPressed: _showReportDialog,
              tooltip: 'Generate Report',
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[700],
              backgroundImage:
                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty
                  ? Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'F',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))
                  : null,
            ),
          ],
        ),
      ),
      body: isLoading
          ? _buildLoadingIndicator()
          : Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      _buildStatsCard(
                          'Pending Verification',
                          '${verificationRequests.length}',
                          const Color.fromARGB(255, 230, 219, 99)),
                      _buildStatsCard('Pending Payment', '$pendingPaymentCount',
                          Colors.greenAccent),
                      _buildStatsCard('Total Approved', '$approvedCount',
                          const Color.fromARGB(255, 129, 160, 214)),
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
                    labelStyle: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: "Verification"),
                      Tab(text: "Payment"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildVerificationList(),
                      _buildPaymentList(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVerificationList() {
    final filteredRequests = _getFilteredVerificationRequests();
    final currentFilter = _currentVerificationFilter;

    return Column(
      children: [
        Container(
          color: const Color(0xFF1E1E1E),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredRequests.length} requests pending verification',
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
                    onPressed: () => _showFilterDialog('Verification'),
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
            color: Colors.tealAccent,
            child: filteredRequests.isEmpty
                ? _emptyListWidget('No requests pending verification')
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredRequests.length,
                    itemBuilder: (context, index) {
                      final request = filteredRequests[index];
                      return _VerificationTile(
                        request: request,
                        onApprove: () => _approveRequest(request),
                        onReject: () => _showRejectDialog(request),
                        onDetails: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FinanceRequestDetails(
                                request: request,
                                authToken: widget.authToken,
                                isPaymentTab: false,
                              ),
                            ),
                          );
                          if (result == true) await _fetchRequests();
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentList() {
    final filteredRequests = _getFilteredPaymentRequests();
    final currentFilter = _currentPaymentFilter;

    return Column(
      children: [
        Container(
          color: const Color(0xFF1E1E1E),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredRequests.length} requests ready for payment',
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
                    onPressed: () => _showFilterDialog('Payment'),
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
            color: Colors.tealAccent,
            child: filteredRequests.isEmpty
                ? _emptyListWidget('No requests ready for payment')
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredRequests.length,
                    itemBuilder: (context, index) {
                      final request = filteredRequests[index];
                      return _PaymentTile(
                        request: request,
                        onProcessPayment: () => _processPayment(request),
                        onDetails: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FinanceRequestDetails(
                                request: request,
                                authToken: widget.authToken,
                                isPaymentTab: true,
                              ),
                            ),
                          );
                          if (result == true) await _fetchRequests();
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

// Verification Tile
class _VerificationTile extends StatelessWidget {
  final FinanceRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDetails;

  const _VerificationTile({
    Key? key,
    required this.request,
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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white24)),
      elevation: 2,
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
                          ? const Icon(Icons.person,
                              color: Colors.white70, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request.employeeName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Text('ID: ${request.employeeId}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: request.requestType == 'reimbursement'
                          ? pastelTeal
                          : pastelOrange,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(
                      request.requestType == 'reimbursement'
                          ? 'Reimbursement'
                          : 'Advance',
                      style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Submitted: ${request.submissionDate}',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 4),
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

// Payment Tile
class _PaymentTile extends StatelessWidget {
  final FinanceRequest request;
  final VoidCallback onProcessPayment;
  final VoidCallback onDetails;

  const _PaymentTile({
    Key? key,
    required this.request,
    required this.onProcessPayment,
    required this.onDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color pastelGreen = Color(0xFFA5D6A7);
    const Color pastelBlue = Color(0xFF90CAF9);

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.greenAccent.withOpacity(0.3))),
      elevation: 2,
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
                          ? const Icon(Icons.person,
                              color: Colors.white70, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request.employeeName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Text('ID: ${request.employeeId}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: pastelGreen,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Text('APPROVED BY CEO',
                      style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Submitted: ${request.submissionDate}',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            if (request.approvalDate != null &&
                request.approvalDate!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('CEO Approved: ${request.approvalDate}',
                    style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 12)),
              ),
            const SizedBox(height: 6),
            Text('Amount: ₹${request.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Ready for Payment Processing',
                style: TextStyle(
                    color: pastelGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
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
                    onPressed: onProcessPayment,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: pastelBlue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    child: const Text('Mark as Paid')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
