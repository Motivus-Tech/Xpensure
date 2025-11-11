import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../screens/ceo_request_details.dart';

class CEODashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String authToken;

  const CEODashboard({
    super.key,
    required this.userData,
    required this.authToken,
  });

  @override
  State<CEODashboard> createState() => _CEODashboardState();
}

class _CEODashboardState extends State<CEODashboard> {
  int _activeTab = 0;
  final List<String> _tabs = ['Pending', 'Analytics', 'History', 'Reports'];

  List<dynamic> _pendingRequests = [];
  List<dynamic> _filteredPendingRequests = [];
  List<dynamic> _historyData = [];
  Map<String, dynamic> _analyticsData = {};
  bool _isLoading = true;
  final ApiService _apiService = ApiService();

  // Filter variables
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Reimbursement',
    'Advance',
    'Amount under 2000',
    'Amount above 2000',
    'Latest',
    'Oldest'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load pending requests from actual API
      final dashboardData = await _apiService.getCEODashboardData(
        authToken: widget.authToken,
      );

      debugPrint('Dashboard Data: $dashboardData');

      // Transform API data to match your UI structure
      final pendingReimbursements = List<Map<String, dynamic>>.from(
          dashboardData['reimbursements_to_approve'] ?? []);
      final pendingAdvances = List<Map<String, dynamic>>.from(
          dashboardData['advances_to_approve'] ?? []);

      // Combine and transform data
      final allPendingRequests = [
        ...pendingReimbursements.map((r) => _transformReimbursementData(r)),
        ...pendingAdvances.map((a) => _transformAdvanceData(a)),
      ];

      // Load analytics from actual API
      final analytics = await _apiService.getCEOAnalytics(
        authToken: widget.authToken,
      );

      // Load history from actual API - CEO actions only
      final history = await _apiService.getCEOHistory(
        authToken: widget.authToken,
      );

      setState(() {
        _pendingRequests = allPendingRequests;
        _filteredPendingRequests = allPendingRequests;
        _analyticsData = analytics;
        _historyData = history;
        _isLoading = false;
      });

      debugPrint('Loaded ${_pendingRequests.length} pending requests');
      debugPrint('Analytics data: $analytics');
      debugPrint('History data: ${_historyData.length} items');
    } catch (e) {
      debugPrint('Error loading CEO dashboard data: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _transformReimbursementData(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'employeeName': data['employee_name'] ?? 'Unknown',
      'employeeId': data['employee_id'] ?? 'N/A',
      'type': 'reimbursement',
      'amount': (data['amount'] ?? 0).toDouble(),
      'date': _formatDate(data['date']),
      'description': data['description'] ?? 'No description',
      'status': data['status'] ?? 'Pending',
      'payments': data['payments'] ?? [],
      'requestType': 'reimbursement',
      'employeeAvatar': data['employee_avatar'],
      'rejection_reason': data['rejection_reason'],
      // ✅ ADD PROJECT INFORMATION
      'project_id': data['project_id'],
      'project_code': data['project_code'],
      'projectId': data['project_id'], // Alternative key

      'rawData': data,
    };
  }

  Map<String, dynamic> _transformAdvanceData(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'employeeName': data['employee_name'] ?? 'Unknown',
      'employeeId': data['employee_id'] ?? 'N/A',
      'type': 'advance',
      'amount': (data['amount'] ?? 0).toDouble(),
      'date': _formatDate(data['date'] ?? data['request_date']),
      'description': data['description'] ?? 'No description',
      'status': data['status'] ?? 'Pending',
      'payments': data['payments'] ?? [],
      'requestType': 'advance',
      'employeeAvatar': data['employee_avatar'],
      'rejection_reason': data['rejection_reason'],
      'project_id': data['project_id'],
      'project_code': data['project_code'],
      'project_name': data['project_name'],
      'project_title': data['project_title'],
      'projectId': data['project_id'], // Alternative key
      'projectName': data['project_name'], // Alternative key

      'rawData': data,
    };
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Unknown date';

    try {
      if (dateValue is String) {
        final date = DateTime.parse(dateValue);
        return DateFormat('MMM dd, yyyy').format(date);
      } else {
        return dateValue.toString();
      }
    } catch (e) {
      return dateValue.toString();
    }
  }

  Future<void> _handleApprove(int requestId) async {
    final request =
        _pendingRequests.firstWhere((req) => req['id'] == requestId);
    final requestType = request['requestType'];

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _apiService.approveCEORequest(
        authToken: widget.authToken,
        requestId: requestId,
        requestType: requestType,
      );

      if (success) {
        await _loadData(); // Reload to get updated counts

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Request approved successfully - Sent to Finance for payment processing'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleReject(int requestId) async {
    final request =
        _pendingRequests.firstWhere((req) => req['id'] == requestId);
    final requestType = request['requestType'];

    // Show reason dialog first
    final reason = await _showRejectionReasonDialog();
    if (reason == null || reason.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _apiService.rejectCEORequest(
        authToken: widget.authToken,
        requestId: requestId,
        requestType: requestType,
        reason: reason,
      );

      if (success) {
        await _loadData(); // Reload to get updated counts

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Request rejected - Sent back to employee with reason'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reject request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _showRejectionReasonDialog() async {
    final controller = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Rejection Reason',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This rejection reason will be sent to the employee:',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Enter detailed reason for rejection...',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFF374151),
              ),
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              minLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a rejection reason'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CeoRequestDetails(
          requestData: request,
          authToken: widget.authToken,
        ),
      ),
    );
  }

  void _applyFilter() {
    List<dynamic> filtered = List.from(_pendingRequests);

    switch (_selectedFilter) {
      case 'Reimbursement':
        filtered =
            filtered.where((req) => req['type'] == 'reimbursement').toList();
        break;
      case 'Advance':
        filtered = filtered.where((req) => req['type'] == 'advance').toList();
        break;
      case 'Amount under 2000':
        filtered = filtered.where((req) => req['amount'] < 2000).toList();
        break;
      case 'Amount above 2000':
        filtered = filtered.where((req) => req['amount'] >= 2000).toList();
        break;
      case 'Latest':
        filtered.sort((a, b) => b['date'].compareTo(a['date']));
        break;
      case 'Oldest':
        filtered.sort((a, b) => a['date'].compareTo(b['date']));
        break;
    }

    setState(() {
      _filteredPendingRequests = filtered;
    });
  }

  int _getPaymentCount(Map<String, dynamic> request) {
    if (request['payments'] != null && request['payments'] is List) {
      return (request['payments'] as List).length;
    }
    return 0;
  }

  String _calculateTotalAmount() {
    double total = _filteredPendingRequests.fold(
        0, (sum, request) => sum + (request['amount'] ?? 0));
    return total.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildTabBar(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Text(
            "CEO Dashboard",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2DD4BF),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2DD4BF)),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade700,
            child: const Icon(Icons.person, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Text(
            "CEO",
            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: _tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          return Expanded(
            child: TextButton(
              onPressed: () => setState(() => _activeTab = index),
              style: TextButton.styleFrom(
                foregroundColor: _activeTab == index
                    ? const Color(0xFF2DD4BF)
                    : const Color(0xFF9CA3AF),
                backgroundColor: _activeTab == index
                    ? const Color(0xFF374151)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(tab,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF2DD4BF)),
            SizedBox(height: 16),
            Text(
              'Loading CEO Dashboard...',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }

    switch (_activeTab) {
      case 0:
        return _buildPendingTab();
      case 1:
        return _buildAnalyticsTab();
      case 2:
        return _buildHistoryTab();
      case 3:
        return _buildReportsTab();
      default:
        return _buildPendingTab();
    }
  }

  Widget _buildPendingTab() {
    return Column(
      children: [
        // Filter Row
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: _buildDropdownDecoration("Filter"),
                  value: _selectedFilter,
                  items: _filterOptions.map((String value) {
                    return DropdownMenuItem(
                      value: value,
                      child: Text(value, style: TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value!;
                      _applyFilter();
                    });
                  },
                  dropdownColor: const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),

        // Stats Row
        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              _buildStatCard(
                  'Total Pending', _filteredPendingRequests.length.toString()),
              const SizedBox(width: 12),
              _buildStatCard('Total Amount', '₹${_calculateTotalAmount()}'),
              const SizedBox(width: 12),
              _buildStatCard('Approval Rate',
                  '${_analyticsData['approval_rate']?.toStringAsFixed(1) ?? '0'}%'),
            ],
          ),
        ),

        // Info Banner
        if (_filteredPendingRequests.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blueAccent, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Approved requests go to Finance for payment. Rejected requests are sent back to employees with reasons.',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        // Requests List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFF2DD4BF),
            child: _filteredPendingRequests.isEmpty
                ? _buildEmptyState('No Pending Requests',
                    'All CEO approvals have been processed')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredPendingRequests.length,
                    itemBuilder: (context, index) {
                      final request = _filteredPendingRequests[index];
                      return _buildRequestCard(request);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    return Card(
      color: const Color(0xFF1F2937),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - Enhanced with avatar and total info
            Row(
              children: [
                // Avatar
                if (request['employeeAvatar'] != null)
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(request['employeeAvatar']),
                  )
                else
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey.shade800,
                    child: Text(
                      request['employeeName'][0],
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['employeeName'],
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                      Text(
                        request['employeeId'],
                        style: const TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 10),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade800,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Pending CEO',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Enhanced Amount & Payment Info
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "₹${request['amount'].toStringAsFixed(0)}",
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2DD4BF)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Total Amount",
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${_getPaymentCount(request)} payments",
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: request['type'] == 'reimbursement'
                            ? Colors.blue.shade900
                            : Colors.purple.shade900,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        request['type'] == 'reimbursement'
                            ? 'Reimbursement'
                            : 'Advance',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Submission Date
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  "Submitted: ${request['date']}",
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Description - Compact
            Text(
              request['description'],
              style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Three Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleApprove(request['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text(
                      "Approve",
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleReject(request['id']),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text(
                      "Reject",
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRequestDetails(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2DD4BF),
                      side: const BorderSide(color: Color(0xFF2DD4BF)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text(
                      "Details",
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF2DD4BF),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Enhanced Stats Cards with all requested metrics
            Row(
              children: [
                _buildAnalyticsCard("Monthly Approved",
                    "₹${(_analyticsData['monthly_spending'] ?? 0).toStringAsFixed(0)}"),
                const SizedBox(width: 12),
                _buildAnalyticsCard("Approval Rate",
                    "${(_analyticsData['approval_rate']?.toStringAsFixed(1) ?? '0')}%"),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildAnalyticsCard("Avg. Request Amount",
                    "₹${(_analyticsData['average_request_amount'] ?? 0).toStringAsFixed(0)}"),
                const SizedBox(width: 12),
                _buildAnalyticsCard("Monthly Approved Count",
                    (_analyticsData['monthly_approved_count'] ?? 0).toString()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildAnalyticsCard(
                    "Total Requests This Month",
                    (_analyticsData['total_requests_this_month'] ?? 0)
                        .toString()),
                const SizedBox(width: 12),
                _buildAnalyticsCard("Monthly Growth",
                    "${(_analyticsData['monthly_growth'] ?? 0).toStringAsFixed(1)}%"),
              ],
            ),
            const SizedBox(height: 24),

            // Charts
            _buildChartCard("Request Types Distribution", _buildTypeChart()),
            const SizedBox(height: 16),
            _buildChartCard("Monthly Spending Trend", _buildBarChart()),
            const SizedBox(height: 16),
            _buildChartCard("Department Distribution", _buildPieChart()),
            const SizedBox(height: 16),
            _buildChartCard("Approval Statistics", _buildApprovalStatsChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        // Filters
        Card(
          color: const Color(0xFF1F2937),
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: _buildDropdownDecoration("Time Period"),
                        value: 'Last 30 days',
                        items: ['Last 30 days', 'Last 7 days', 'Last 90 days']
                            .map((String value) {
                          return DropdownMenuItem(
                            value: value,
                            child: Text(value,
                                style: TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          setState(() => _isLoading = true);
                          try {
                            final periodMap = {
                              'Last 30 days': 'last_30_days',
                              'Last 7 days': 'last_7_days',
                              'Last 90 days': 'last_90_days',
                            };

                            final history = await _apiService.getCEOHistory(
                              authToken: widget.authToken,
                              period: periodMap[value] ?? 'last_30_days',
                            );

                            setState(() {
                              _historyData = history;
                              _isLoading = false;
                            });
                          } catch (e) {
                            setState(() => _isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error loading history: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        dropdownColor: const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: _buildDropdownDecoration("Status"),
                        value: 'All Status',
                        items: ['All Status', 'Approved', 'Rejected', 'Pending']
                            .map((String value) {
                          return DropdownMenuItem(
                            value: value,
                            child: Text(value,
                                style: TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          // Client-side filtering can be implemented here
                        },
                        dropdownColor: const Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // History List - Only shows CEO actions
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFF2DD4BF),
            child: _historyData.isEmpty
                ? _buildEmptyState(
                    'No History', 'No CEO actions found for selected period')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _historyData.length,
                    itemBuilder: (context, index) {
                      final request = _historyData[index];
                      return _buildHistoryCard(request);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF2DD4BF),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Quick Reports
            Card(
              color: const Color(0xFF1F2937),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Download Reports (CSV)",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildReportButton('Monthly Report', 'monthly'),
                        _buildReportButton('Approved Requests', 'approved'),
                        _buildReportButton('All Data', 'all'),
                        _buildReportButton('Custom Range', 'custom'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Reports will be downloaded as CSV files containing:\n• Employee details\n• Request amounts\n• Status and CEO actions\n• Payment counts\n• Department information",
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Recent Reports
            Card(
              color: const Color(0xFF1F2937),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Recent Reports",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    const SizedBox(height: 12),
                    _buildReportItem("No reports generated",
                        "Download your first report above"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2DD4BF))),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String value) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF374151)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2DD4BF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Card(
      color: const Color(0xFF1F2937),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            chart,
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    return SizedBox(
      height: 150,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 48, color: Color(0xFF2DD4BF)),
            SizedBox(height: 8),
            Text(
              "Monthly Spending: ₹${_analyticsData['monthly_spending']?.toStringAsFixed(0) ?? '0'}",
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
            Text(
              "Growth: ${_analyticsData['monthly_growth']?.toStringAsFixed(1) ?? '0'}%",
              style: TextStyle(color: Color(0xFF2DD4BF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final departmentStats = List<Map<String, dynamic>>.from(
        _analyticsData['department_stats'] ?? []);

    if (departmentStats.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(
          child: Text(
            "No department data available",
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
        ),
      );
    }

    return SizedBox(
      height: 150,
      child: ListView.builder(
        padding: EdgeInsets.all(8),
        itemCount: departmentStats.length,
        itemBuilder: (context, index) {
          final dept = departmentStats[index];
          return ListTile(
            leading: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: [
                  Colors.blue,
                  Colors.green,
                  Colors.orange,
                  Colors.purple
                ][index % 4],
                shape: BoxShape.circle,
              ),
            ),
            title: Text(
              dept['department'],
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            trailing: Text(
              "₹${dept['amount']?.toStringAsFixed(0) ?? '0'}",
              style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 12),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeChart() {
    final reimbursementCount = _analyticsData['reimbursement_count'] ?? 0;
    final advanceCount = _analyticsData['advance_count'] ?? 0;

    if (reimbursementCount == 0 && advanceCount == 0) {
      return const SizedBox(
        height: 150,
        child: Center(
          child: Text(
            "No data available",
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
        ),
      );
    }

    return SizedBox(
      height: 150,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildChartLegend(
                    "Reimbursements", Colors.blue, reimbursementCount),
                _buildChartLegend("Advances", Colors.purple, advanceCount),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              "Total: ${reimbursementCount + advanceCount} requests",
              style: const TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalStatsChart() {
    final approved = _analyticsData['approved_count'] ?? 0;
    final rejected = _analyticsData['rejected_count'] ?? 0;
    final pending = _analyticsData['pending_count'] ?? 0;

    return SizedBox(
      height: 150,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildChartLegend("Approved", Colors.green, approved),
                _buildChartLegend("Rejected", Colors.red, rejected),
                _buildChartLegend("Pending", Colors.blue, pending),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              "Total: ${approved + rejected + pending} requests",
              style: const TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color, int count) {
    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          color: color,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        Text(
          count.toString(),
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> request) {
    return Card(
      color: const Color(0xFF1F2937),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: request['employee_avatar'] != null
            ? CircleAvatar(
                backgroundImage: NetworkImage(request['employee_avatar']),
              )
            : CircleAvatar(
                backgroundColor: Colors.grey.shade800,
                child: Text(
                  (request['employee_name']?[0] ?? 'U').toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
        title: Text(
          request['employee_name'] ?? 'Unknown',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              request['type'] ?? 'Unknown type',
              style: const TextStyle(color: Color(0xFF9CA3AF)),
            ),
            Text(
              request['date'] ?? 'Unknown date',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
            if (request['ceo_action'] == 'rejected' &&
                request['rejection_reason'] != null)
              Text(
                'CEO Rejected: ${request['rejection_reason']}',
                style: const TextStyle(color: Colors.orange, fontSize: 11),
              ),
            if (request['ceo_action'] == 'approved')
              Text(
                'CEO Approved',
                style: const TextStyle(color: Colors.green, fontSize: 11),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "₹${(request['amount'] ?? 0).toStringAsFixed(0)}",
              style: const TextStyle(
                color: Color(0xFF2DD4BF),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(request['status']),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                request['status'] ?? 'Unknown',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportButton(String title, String type) {
    return ElevatedButton(
      onPressed: () => _generateReport(type),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2DD4BF)),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildReportItem(String title, String date) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade800))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                Text(date,
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 12)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2DD4BF),
                side: const BorderSide(color: Color(0xFF2DD4BF))),
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(message,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  InputDecoration _buildDropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: const Color(0xFF374151),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green.shade900;
      case 'rejected':
        return Colors.red.shade900;
      case 'pending':
        return Colors.blue.shade900;
      default:
        return Colors.grey.shade900;
    }
  }

  Future<void> _generateReport(String type) async {
    try {
      setState(() => _isLoading = true);

      final success = await _apiService.downloadCEOReport(
        authToken: widget.authToken,
        reportName: 'ceo_${type}_report',
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$type report downloaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to download report');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
