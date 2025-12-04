import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'ceo_request_details.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

class CEODashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String authToken;
  final VoidCallback onLogout;

  const CEODashboard({
    super.key,
    required this.userData,
    required this.authToken,
    required this.onLogout,
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

  // Real-time analytics refresh
  Timer? _analyticsTimer;
  final int _refreshInterval = 30000; // 30 seconds

  // Filter variables
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Reimbursement',
    'Advance',
    'Amount under 2000',
    'Amount above 2000',
    'Latest',
    'Oldest',
    'Search by Employee ID',
  ];

  // Report generation variables
  String _reportType = 'employee';
  String _reportPeriod = '1_month';
  String _reportIdentifier = '';
  bool _isGeneratingReport = false;

  // Add this variable for employee ID search
  String _employeeIdSearchQuery = '';

  // Employee project spending variables
  String _employeeIdForProjectReport = '';
  String _projectIdForEmployeeReport = '';
  bool _isGeneratingEmployeeProjectReport = false;

  // Custom date range variables
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isGeneratingCustomDateReport = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startRealTimeAnalytics();
  }

  @override
  void dispose() {
    _analyticsTimer?.cancel();
    super.dispose();
  }

  void _startRealTimeAnalytics() {
    _analyticsTimer = Timer.periodic(Duration(milliseconds: _refreshInterval), (
      Timer timer,
    ) {
      if (_activeTab == 1) {
        _loadAnalyticsData();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dashboardData = await _apiService.getCEODashboardData(
        authToken: widget.authToken,
      );

      // ✅ **ADD DETAILED DEBUG LOGGING HERE**
      debugPrint('=== CEO DASHBOARD DEBUG START ===');
      debugPrint('Full API response keys: ${dashboardData.keys.toList()}');

      final pendingReimbursements = List<Map<String, dynamic>>.from(
        dashboardData['reimbursements_to_approve'] ?? [],
      );
      final pendingAdvances = List<Map<String, dynamic>>.from(
        dashboardData['advances_to_approve'] ?? [],
      );

      debugPrint(
          'Reimbursements from API: ${pendingReimbursements.length} items');
      debugPrint('Advances from API: ${pendingAdvances.length} items');

      // Log each reimbursement
      for (var i = 0; i < pendingReimbursements.length; i++) {
        var reimb = pendingReimbursements[i];
        debugPrint(
            'Reimbursement $i: ID=${reimb['id']}, Amount=₹${reimb['amount']}, Finance Approved=${reimb['approved_by_finance']}');
      }

      // Log each advance
      for (var i = 0; i < pendingAdvances.length; i++) {
        var advance = pendingAdvances[i];
        debugPrint(
            'Advance $i: ID=${advance['id']}, Amount=₹${advance['amount']}, Finance Approved=${advance['approved_by_finance']}, HR Approved=${advance['approved_by_hr']}');
      }

      debugPrint('=== CEO DASHBOARD DEBUG END ===');

      final allPendingRequests = [
        ...pendingReimbursements.map((r) => _transformReimbursementData(r)),
        ...pendingAdvances.map((a) => _transformAdvanceData(a)),
      ];

      final analytics = await _apiService.getCEOAnalytics(
        authToken: widget.authToken,
      );

      final history = await _apiService.getCEOHistory(
        authToken: widget.authToken,
      );

      // ✅ **MOVE DEBUG HERE - AFTER LOADING ANALYTICS**
      debugPrint(
          '🔥 WHERE IS THIS COMING FROM? Analytics reimb: ${analytics['reimbursement_count']}, advance: ${analytics['advance_count']}');
      debugPrint(
          '🔥 Actual pending reimb: ${pendingReimbursements.length}, advance: ${pendingAdvances.length}');
      debugPrint('🔥 Analytics full data: $analytics');

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

  Future<void> _loadAnalyticsData() async {
    try {
      final analytics = await _apiService.getCEOAnalytics(
        authToken: widget.authToken,
      );

      if (mounted) {
        setState(() {
          _analyticsData = analytics;
        });
      }

      debugPrint('Real-time analytics updated: ${DateTime.now()}');
    } catch (e) {
      debugPrint('Error updating real-time analytics: $e');
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
      'project_id': data['project_id'],
      'project_code': data['project_code'],
      'projectId': data['project_id'],
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
      'projectId': data['project_id'],
      'projectName': data['project_name'],
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
    final request = _pendingRequests.firstWhere(
      (req) => req['id'] == requestId,
    );
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
        await _loadData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Request approved successfully - Sent to Finance for payment processing',
            ),
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
    final request = _pendingRequests.firstWhere(
      (req) => req['id'] == requestId,
    );
    final requestType = request['requestType'];

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
        await _loadData();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Request rejected - Sent back to employee with reason',
            ),
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

  Future<void> _generateEmployeeReport() async {
    if (_reportIdentifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter Employee ID"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingReport = true;
    });

    try {
      final employeeData = _historyData.where((request) {
        final employeeId = request['employeeId']?.toString() ??
            request['employee_id']?.toString() ??
            '';
        return employeeId.contains(_reportIdentifier);
      }).toList();

      if (employeeData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No data found for Employee ID: $_reportIdentifier"),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isGeneratingReport = false);
        return;
      }

      List<List<dynamic>> csvData = [];
      csvData.add([
        'Request ID',
        'Employee ID',
        'Employee Name',
        'Request Type',
        'Amount',
        'Description',
        'Submission Date',
        'CEO Action',
        'Status',
        'Project Name',
        'Rejection Reason',
      ]);

      for (var request in employeeData) {
        csvData.add([
          request['id'] ?? '',
          request['employeeId'] ?? request['employee_id'] ?? '',
          request['employeeName'] ?? request['employee_name'] ?? '',
          request['requestType'] ?? request['type'] ?? '',
          (request['amount'] ?? 0).toStringAsFixed(2),
          request['description'] ?? '',
          request['date'] ?? '',
          request['ceo_action'] ?? 'Pending',
          request['status'] ?? '',
          request['project_name'] ?? '',
          request['rejection_reason'] ?? '',
        ]);
      }

      String csv = const ListToCsvConverter().convert(csvData);
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/ceo_employee_report_${_reportIdentifier}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(filePath);
      await file.writeAsString(csv);

      await Share.shareFiles(
        [filePath],
        text:
            'CEO Employee Report\nEmployee: $_reportIdentifier\nTotal Records: ${employeeData.length}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Employee report generated with ${employeeData.length} records",
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("❌ Error generating employee report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error generating report: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isGeneratingReport = false);
    }
  }

  Future<void> _generateProjectReport() async {
    if (_reportIdentifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter Project ID/Code/Name"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingReport = true;
    });

    try {
      DateTime startDate;
      final now = DateTime.now();

      switch (_reportPeriod) {
        case '1_month':
          startDate = DateTime(now.year, now.month - 1, now.day);
          break;
        case '3_months':
          startDate = DateTime(now.year, now.month - 3, now.day);
          break;
        case '6_months':
          startDate = DateTime(now.year, now.month - 6, now.day);
          break;
        case 'all_time':
          startDate = DateTime(2000);
          break;
        default:
          startDate = DateTime(now.year, now.month - 1, now.day);
      }

      List<dynamic> reportData = [..._historyData, ..._pendingRequests].where((
        request,
      ) {
        final projectId = request['project_id']?.toString() ?? '';
        final projectName = request['project_name']?.toString() ?? '';
        final projectCode = request['project_code']?.toString() ?? '';
        final requestDate = DateTime.tryParse(request['date'] ?? '');

        return (projectId.contains(_reportIdentifier) ||
                projectName.toLowerCase().contains(
                      _reportIdentifier.toLowerCase(),
                    ) ||
                projectCode.contains(_reportIdentifier)) &&
            requestDate != null &&
            requestDate.isAfter(startDate);
      }).toList();

      if (reportData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No data found for Project: $_reportIdentifier"),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isGeneratingReport = false;
        });
        return;
      }

      List<List<dynamic>> csvData = [];

      csvData.add([
        'Request ID',
        'Employee ID',
        'Employee Name',
        'Request Type',
        'Amount',
        'Description',
        'Submission Date',
        'Status',
        'CEO Action',
        'Project ID',
        'Project Name',
        'Rejection Reason',
      ]);

      for (var request in reportData) {
        csvData.add([
          request['id'] ?? '',
          request['employeeId'] ?? request['employee_id'] ?? '',
          request['employeeName'] ?? request['employee_name'] ?? '',
          request['requestType'] ?? request['type'] ?? '',
          (request['amount'] ?? 0).toStringAsFixed(2),
          request['description'] ?? '',
          request['date'] ?? '',
          request['status'] ?? '',
          request['ceo_action'] ?? 'Pending',
          request['project_id'] ?? '',
          request['project_name'] ?? '',
          request['rejection_reason'] ?? '',
        ]);
      }

      String csv = const ListToCsvConverter().convert(csvData);

      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/ceo_project_report_${_reportIdentifier}_${DateTime.now().millisecondsSinceEpoch}.csv';

      final file = File(filePath);
      await file.writeAsString(csv);

      debugPrint("✅ CEO Project CSV file created at: $filePath");
      debugPrint("✅ Report contains ${reportData.length} records");

      await Share.shareFiles([
        filePath,
      ], text: 'CEO Project Report - Project: $_reportIdentifier');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Project report generated successfully with ${reportData.length} records",
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("❌ Error generating project report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error generating report: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGeneratingReport = false;
      });
    }
  }

  Future<void> _generateEmployeeProjectReport() async {
    if (_employeeIdForProjectReport.isEmpty ||
        _projectIdForEmployeeReport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Please enter both Employee ID and Project ID/Code/Name",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingEmployeeProjectReport = true;
    });

    try {
      final employeeProjectData = [..._historyData, ..._pendingRequests].where((
        request,
      ) {
        final employeeId = request['employeeId']?.toString() ??
            request['employee_id']?.toString() ??
            '';
        final projectId = request['project_id']?.toString() ?? '';
        final projectName = request['project_name']?.toString() ?? '';
        final projectCode = request['project_code']?.toString() ?? '';

        return employeeId.contains(_employeeIdForProjectReport) &&
            (projectId.contains(_projectIdForEmployeeReport) ||
                projectName.toLowerCase().contains(
                      _projectIdForEmployeeReport.toLowerCase(),
                    ) ||
                projectCode.contains(_projectIdForEmployeeReport));
      }).toList();

      if (employeeProjectData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "No CEO approval data found for:\n"
              "Employee: ${_employeeIdForProjectReport}\n"
              "Project: ${_projectIdForEmployeeReport}",
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 6),
          ),
        );
        setState(() {
          _isGeneratingEmployeeProjectReport = false;
        });
        return;
      }

      double totalAmount = employeeProjectData.fold(
        0,
        (sum, request) => sum + (request['amount'] ?? 0),
      );
      int totalRequests = employeeProjectData.length;
      int reimbursementCount = employeeProjectData
          .where(
            (r) =>
                r['type'] == 'reimbursement' ||
                r['requestType'] == 'reimbursement',
          )
          .length;
      int advanceCount = employeeProjectData
          .where((r) => r['type'] == 'advance' || r['requestType'] == 'advance')
          .length;

      int approvedCount = employeeProjectData
          .where(
            (r) => r['ceo_action'] == 'approved' || r['status'] == 'approved',
          )
          .length;
      int rejectedCount = employeeProjectData
          .where(
            (r) => r['ceo_action'] == 'rejected' || r['status'] == 'rejected',
          )
          .length;
      int pendingCount =
          employeeProjectData.where((r) => r['status'] == 'pending').length;

      List<List<dynamic>> csvData = [];

      csvData.add(['CEO APPROVAL TRACKING REPORT']);
      csvData.add(['Generated on', DateTime.now().toString().split(' ')[0]]);
      csvData.add(['Employee ID', _employeeIdForProjectReport]);
      csvData.add([
        'Employee Name',
        employeeProjectData.first['employeeName'] ??
            employeeProjectData.first['employee_name'] ??
            'Unknown',
      ]);
      csvData.add(['Project Identifier', _projectIdForEmployeeReport]);
      csvData.add(['Report Period', _reportPeriod.replaceAll('_', ' ')]);
      csvData.add([]);

      csvData.add(['CEO APPROVAL SUMMARY']);
      csvData.add(['Total Requests', totalRequests]);
      csvData.add(['Reimbursements', reimbursementCount]);
      csvData.add(['Advances', advanceCount]);
      csvData.add(['Approved by CEO', approvedCount]);
      csvData.add(['Rejected by CEO', rejectedCount]);
      csvData.add(['Pending CEO Approval', pendingCount]);
      csvData.add(['Total Amount', '₹${totalAmount.toStringAsFixed(2)}']);
      csvData.add([]);

      csvData.add(['DETAILED APPROVAL RECORDS']);
      csvData.add([
        'Request ID',
        'Type',
        'Amount',
        'Description',
        'Status',
        'CEO Action',
        'Submission Date',
        'CEO Action Date',
        'Project ID',
        'Project Name',
        'Rejection Reason',
      ]);

      for (var request in employeeProjectData) {
        csvData.add([
          request['id'] ?? '',
          request['requestType'] ?? request['type'] ?? '',
          '₹${(request['amount'] ?? 0).toStringAsFixed(2)}',
          request['description'] ?? '',
          request['status'] ?? '',
          request['ceo_action'] ?? 'Pending',
          request['date'] ?? '',
          request['ceo_action_date'] ?? '',
          request['project_id'] ?? '',
          request['project_name'] ?? '',
          request['rejection_reason'] ?? '',
        ]);
      }

      String csv = const ListToCsvConverter().convert(csvData);

      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/ceo_employee_project_${_employeeIdForProjectReport}_${_projectIdForEmployeeReport}_${DateTime.now().millisecondsSinceEpoch}.csv';

      final file = File(filePath);
      await file.writeAsString(csv);

      debugPrint("✅ CEO Employee-Project CSV file created at: $filePath");

      await Share.shareFiles(
        [filePath],
        text: 'CEO Approval Tracking Report\n\n'
            '👤 Employee: ${employeeProjectData.first['employeeName'] ?? 'Unknown'} ($_employeeIdForProjectReport)\n'
            '📁 Project: $_projectIdForEmployeeReport\n'
            '💰 Total Amount: ₹${totalAmount.toStringAsFixed(2)}\n'
            '📊 Total Requests: $totalRequests\n'
            '🧾 Reimbursements: $reimbursementCount | 💰 Advances: $advanceCount\n'
            '✅ Approved: $approvedCount | ❌ Rejected: $rejectedCount | ⏳ Pending: $pendingCount\n'
            '📅 Period: ${_reportPeriod.replaceAll('_', ' ')}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("CEO Approval report generated successfully!"),
              SizedBox(height: 4),
              Text("Total Amount: ₹${totalAmount.toStringAsFixed(2)}"),
              Text(
                "Requests: $totalRequests (${reimbursementCount}R + ${advanceCount}A)",
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint("❌ Error generating CEO employee-project report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error generating report: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGeneratingEmployeeProjectReport = false;
      });
    }
  }

  Future<void> _generateCustomDateRangeReport() async {
    if (_customStartDate == null || _customEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please select both start and end dates"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_customStartDate!.isAfter(_customEndDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Start date cannot be after end date"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingCustomDateReport = true;
    });

    try {
      final customDateData = [..._historyData, ..._pendingRequests].where((
        request,
      ) {
        final requestDate = DateTime.tryParse(request['date'] ?? '');
        if (requestDate == null) return false;

        return (requestDate.isAfter(_customStartDate!) ||
                requestDate.isAtSameMomentAs(_customStartDate!)) &&
            (requestDate.isBefore(_customEndDate!) ||
                requestDate.isAtSameMomentAs(_customEndDate!));
      }).toList();

      if (customDateData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "No CEO approval data found for selected date range",
            ),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isGeneratingCustomDateReport = false;
        });
        return;
      }

      double totalAmount = customDateData.fold(
        0,
        (sum, request) => sum + (request['amount'] ?? 0),
      );
      int totalRequests = customDateData.length;
      int reimbursementCount = customDateData
          .where(
            (r) =>
                r['type'] == 'reimbursement' ||
                r['requestType'] == 'reimbursement',
          )
          .length;
      int advanceCount = customDateData
          .where((r) => r['type'] == 'advance' || r['requestType'] == 'advance')
          .length;

      int approvedCount = customDateData
          .where(
            (r) => r['ceo_action'] == 'approved' || r['status'] == 'approved',
          )
          .length;
      int rejectedCount = customDateData
          .where(
            (r) => r['ceo_action'] == 'rejected' || r['status'] == 'rejected',
          )
          .length;
      int pendingCount =
          customDateData.where((r) => r['status'] == 'pending').length;

      List<List<dynamic>> csvData = [];

      csvData.add(['CEO APPROVAL REPORT - CUSTOM DATE RANGE']);
      csvData.add(['Generated on', DateTime.now().toString().split(' ')[0]]);
      csvData.add([
        'Date Range',
        '${DateFormat('MMM dd, yyyy').format(_customStartDate!)} - ${DateFormat('MMM dd, yyyy').format(_customEndDate!)}'
      ]);
      csvData.add([]);

      csvData.add(['CEO APPROVAL SUMMARY']);
      csvData.add(['Total Requests', totalRequests]);
      csvData.add(['Reimbursements', reimbursementCount]);
      csvData.add(['Advances', advanceCount]);
      csvData.add(['Approved by CEO', approvedCount]);
      csvData.add(['Rejected by CEO', rejectedCount]);
      csvData.add(['Pending CEO Approval', pendingCount]);
      csvData.add(['Total Amount', '₹${totalAmount.toStringAsFixed(2)}']);
      csvData.add([]);

      csvData.add(['DETAILED APPROVAL RECORDS']);
      csvData.add([
        'Request ID',
        'Employee ID',
        'Employee Name',
        'Request Type',
        'Amount',
        'Description',
        'Submission Date',
        'Status',
        'CEO Action',
        'Project ID',
        'Project Name',
        'Rejection Reason',
      ]);

      for (var request in customDateData) {
        csvData.add([
          request['id'] ?? '',
          request['employeeId'] ?? request['employee_id'] ?? '',
          request['employeeName'] ?? request['employee_name'] ?? '',
          request['requestType'] ?? request['type'] ?? '',
          '₹${(request['amount'] ?? 0).toStringAsFixed(2)}',
          request['description'] ?? '',
          request['date'] ?? '',
          request['status'] ?? '',
          request['ceo_action'] ?? 'Pending',
          request['project_id'] ?? '',
          request['project_name'] ?? '',
          request['rejection_reason'] ?? '',
        ]);
      }

      String csv = const ListToCsvConverter().convert(csvData);

      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/ceo_custom_date_report_${_customStartDate!.millisecondsSinceEpoch}_${_customEndDate!.millisecondsSinceEpoch}.csv';

      final file = File(filePath);
      await file.writeAsString(csv);

      debugPrint("✅ CEO Custom Date Range CSV file created at: $filePath");

      await Share.shareFiles(
        [filePath],
        text: 'CEO Approval Report - Custom Date Range\n\n'
            '📅 Date Range: ${DateFormat('MMM dd, yyyy').format(_customStartDate!)} - ${DateFormat('MMM dd, yyyy').format(_customEndDate!)}\n'
            '💰 Total Amount: ₹${totalAmount.toStringAsFixed(2)}\n'
            '📊 Total Requests: $totalRequests\n'
            '🧾 Reimbursements: $reimbursementCount | 💰 Advances: $advanceCount\n'
            '✅ Approved: $approvedCount | ❌ Rejected: $rejectedCount | ⏳ Pending: $pendingCount',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Custom date range report generated successfully!"),
              SizedBox(height: 4),
              Text(
                  "Period: ${DateFormat('MMM dd, yyyy').format(_customStartDate!)} - ${DateFormat('MMM dd, yyyy').format(_customEndDate!)}"),
              Text("Total Amount: ₹${totalAmount.toStringAsFixed(2)}"),
              Text(
                "Requests: $totalRequests (${reimbursementCount}R + ${advanceCount}A)",
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint("❌ Error generating custom date range report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error generating report: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGeneratingCustomDateReport = false;
      });
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _customStartDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2DD4BF),
              onPrimary: Colors.white,
              surface: Color(0xFF1F2937),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1F2937),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _customStartDate) {
      setState(() {
        _customStartDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _customEndDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2DD4BF),
              onPrimary: Colors.white,
              surface: Color(0xFF1F2937),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1F2937),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _customEndDate) {
      setState(() {
        _customEndDate = picked;
      });
    }
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
      case 'Search by Employee ID':
        if (_employeeIdSearchQuery.isNotEmpty) {
          filtered = filtered.where((req) {
            final employeeId =
                req['employeeId']?.toString().toLowerCase() ?? '';
            final employeeName =
                req['employeeName']?.toString().toLowerCase() ?? '';
            final searchQuery = _employeeIdSearchQuery.toLowerCase();

            // Search in both employee ID and name
            return employeeId.contains(searchQuery) ||
                employeeName.contains(searchQuery);
          }).toList();
        }
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
      0,
      (sum, request) => sum + (request['amount'] ?? 0),
    );
    return total.toStringAsFixed(0);
  }

  // Logout confirmation dialog
  Future<void> _showLogoutDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Colors.grey),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onLogout();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isLargeScreen = screenWidth > 1200;

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(isSmallScreen),
            _buildTabBar(isSmallScreen),
            Expanded(child: _buildContent(isSmallScreen, isLargeScreen)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: 8,
      ),
      child: Row(
        children: [
          Text(
            "CEO Dashboard",
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2DD4BF),
            ),
          ),
          const Spacer(),
          if (_activeTab == 1) ...[
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: Icon(Icons.refresh,
                color: const Color(0xFF2DD4BF), size: isSmallScreen ? 20 : 24),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 4),
          // Logout button
          IconButton(
            icon: Icon(Icons.logout,
                color: Colors.red.shade400, size: isSmallScreen ? 20 : 24),
            onPressed: _showLogoutDialog,
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
          // CEO Avatar
          if (widget.userData['avatar'] != null)
            CircleAvatar(
              radius: isSmallScreen ? 16 : 18,
              backgroundImage: NetworkImage(widget.userData['avatar']),
            )
          else
            CircleAvatar(
              radius: isSmallScreen ? 16 : 18,
              backgroundColor: Colors.grey.shade700,
              child: Icon(Icons.person,
                  size: isSmallScreen ? 16 : 18, color: Colors.white),
            ),
          if (!isSmallScreen) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.userData['name'] ?? "CEO",
                style: TextStyle(
                  color: const Color(0xFFD1D5DB),
                  fontSize: isSmallScreen ? 12 : 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: isSmallScreen ? Axis.horizontal : Axis.horizontal,
        child: Row(
          children: _tabs.asMap().entries.map((entry) {
            final index = entry.key;
            final tab = entry.value;
            return Container(
              width: isSmallScreen
                  ? MediaQuery.of(context).size.width / 4 - 8
                  : null,
              child: TextButton(
                onPressed: () => setState(() => _activeTab = index),
                style: TextButton.styleFrom(
                  foregroundColor: _activeTab == index
                      ? const Color(0xFF2DD4BF)
                      : const Color(0xFF9CA3AF),
                  backgroundColor: _activeTab == index
                      ? const Color(0xFF374151)
                      : Colors.transparent,
                  padding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 10 : 12,
                    horizontal: isSmallScreen ? 4 : 8,
                  ),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContent(bool isSmallScreen, bool isLargeScreen) {
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
        return _buildPendingTab(isSmallScreen);
      case 1:
        return _buildAnalyticsTab(isSmallScreen, isLargeScreen);
      case 2:
        return _buildHistoryTab(isSmallScreen);
      case 3:
        return _buildReportsTab(isSmallScreen);
      default:
        return _buildPendingTab(isSmallScreen);
    }
  }

  Widget _buildPendingTab(bool isSmallScreen) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration:
                          _buildDropdownDecoration("Filter", isSmallScreen),
                      value: _selectedFilter,
                      items: _filterOptions.map((String value) {
                        return DropdownMenuItem(
                          value: value,
                          child: Text(
                            value,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFilter = value!;
                          _employeeIdSearchQuery = '';
                          _applyFilter();
                        });
                      },
                      dropdownColor: const Color(0xFF374151),
                      isExpanded: true,
                    ),
                  ),
                ],
              ),
              if (_selectedFilter == 'Search by Employee ID')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _employeeIdSearchQuery = value;
                        _applyFilter();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Enter Employee ID to search...",
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: isSmallScreen ? 12 : 14,
                      ),
                      border: const OutlineInputBorder(),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF2DD4BF)),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF374151),
                      prefixIcon: Icon(Icons.search,
                          color: Colors.grey, size: isSmallScreen ? 18 : 24),
                      suffixIcon: _employeeIdSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: Colors.grey,
                                  size: isSmallScreen ? 18 : 24),
                              onPressed: () {
                                setState(() {
                                  _employeeIdSearchQuery = '';
                                  _applyFilter();
                                });
                              },
                            )
                          : null,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                    ),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(isSmallScreen ? 12 : 16, 0,
              isSmallScreen ? 12 : 16, isSmallScreen ? 12 : 16),
          child: Row(
            children: [
              Expanded(
                  child: _buildStatCard(
                'Total Pending',
                _filteredPendingRequests.length.toString(),
                isSmallScreen,
              )),
              SizedBox(width: isSmallScreen ? 8 : 12),
              Expanded(
                  child: _buildStatCard(
                'Total Amount',
                '₹${_calculateTotalAmount()}',
                isSmallScreen,
              )),
              SizedBox(width: isSmallScreen ? 8 : 12),
              Expanded(
                  child: _buildStatCard(
                'Approval Rate',
                '${_analyticsData['approval_rate']?.toStringAsFixed(1) ?? '0'}%',
                isSmallScreen,
              )),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFF2DD4BF),
            child: _filteredPendingRequests.isEmpty
                ? _buildEmptyState(
                    _selectedFilter == 'Search by Employee ID' &&
                            _employeeIdSearchQuery.isNotEmpty
                        ? 'No Matching Employee ID'
                        : 'No Pending Requests',
                    _selectedFilter == 'Search by Employee ID' &&
                            _employeeIdSearchQuery.isNotEmpty
                        ? 'No pending requests found for Employee ID: $_employeeIdSearchQuery'
                        : 'All CEO approvals have been processed',
                    isSmallScreen,
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                    ),
                    itemCount: _filteredPendingRequests.length,
                    itemBuilder: (context, index) {
                      final request = _filteredPendingRequests[index];
                      return _buildRequestCard(request, isSmallScreen);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, bool isSmallScreen) {
    return Card(
      color: const Color(0xFF1F2937),
      margin: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (request['employeeAvatar'] != null)
                  CircleAvatar(
                    radius: isSmallScreen ? 14 : 16,
                    backgroundImage: NetworkImage(request['employeeAvatar']),
                  )
                else
                  CircleAvatar(
                    radius: isSmallScreen ? 14 : 16,
                    backgroundColor: Colors.grey.shade800,
                    child: Text(
                      request['employeeName'][0],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 10 : 12,
                      ),
                    ),
                  ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['employeeName'],
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        request['employeeId'],
                        style: TextStyle(
                          color: const Color(0xFF9CA3AF),
                          fontSize: isSmallScreen ? 9 : 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 4 : 6,
                    vertical: isSmallScreen ? 1 : 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade800,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Pending CEO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 7 : 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "₹${request['amount'].toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2DD4BF),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 1 : 2),
                    Text(
                      "Total Amount",
                      style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: isSmallScreen ? 9 : 10),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${_getPaymentCount(request)} payments",
                      style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: isSmallScreen ? 9 : 10),
                    ),
                    SizedBox(height: isSmallScreen ? 1 : 2),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 4 : 6,
                        vertical: isSmallScreen ? 1 : 2,
                      ),
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 7 : 8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: isSmallScreen ? 10 : 12, color: Color(0xFF9CA3AF)),
                SizedBox(width: isSmallScreen ? 3 : 4),
                Text(
                  "Submitted: ${request['date']}",
                  style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: isSmallScreen ? 9 : 10),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              request['description'],
              style: TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: isSmallScreen ? 11 : 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isSmallScreen ? 10 : 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleApprove(request['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 6 : 8,
                      ),
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(
                      "Approve",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isSmallScreen ? 11 : 12,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleReject(request['id']),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 6 : 8,
                      ),
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(
                      "Reject",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isSmallScreen ? 11 : 12,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRequestDetails(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2DD4BF),
                      side: const BorderSide(color: Color(0xFF2DD4BF)),
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 6 : 8,
                      ),
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(
                      "Details",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isSmallScreen ? 11 : 12,
                      ),
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

  Widget _buildAnalyticsTab(bool isSmallScreen, bool isLargeScreen) {
    return RefreshIndicator(
      onRefresh: _loadAnalyticsData,
      color: const Color(0xFF2DD4BF),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          children: [
            Card(
              color: const Color(0xFF1F2937),
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    const Expanded(
                      child: Text(
                        'Real-time Analytics',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    Text(
                      'Updated: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: isSmallScreen ? 10 : 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            GridView.count(
              crossAxisCount: isSmallScreen ? 2 : (isLargeScreen ? 3 : 2),
              crossAxisSpacing: isSmallScreen ? 8 : 12,
              mainAxisSpacing: isSmallScreen ? 8 : 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: isSmallScreen ? 1.3 : 1.5,
              children: [
                _buildAnalyticsCard(
                  "Monthly Approved",
                  "₹${(_analyticsData['monthly_spending'] ?? 0).toStringAsFixed(0)}",
                  isSmallScreen,
                ),
                _buildAnalyticsCard(
                  "Approval Rate",
                  "${(_analyticsData['approval_rate']?.toStringAsFixed(1) ?? '0')}%",
                  isSmallScreen,
                ),
                _buildAnalyticsCard(
                  "Avg. Request Amount",
                  "₹${(_analyticsData['average_request_amount'] ?? 0).toStringAsFixed(0)}",
                  isSmallScreen,
                ),
                _buildAnalyticsCard(
                  "Monthly Approved Count",
                  (_analyticsData['monthly_approved_count'] ?? 0).toString(),
                  isSmallScreen,
                ),
                _buildAnalyticsCard(
                  "Total Requests This Month",
                  (_analyticsData['total_requests_this_month'] ?? 0).toString(),
                  isSmallScreen,
                ),
                _buildAnalyticsCard(
                  "Monthly Growth",
                  "${(_analyticsData['monthly_growth'] ?? 0).toStringAsFixed(1)}%",
                  isSmallScreen,
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            _buildChartCard(
                "Request Types Distribution", _buildTypeChart(), isSmallScreen),
            SizedBox(height: isSmallScreen ? 12 : 16),
            _buildChartCard(
                "Department Distribution", _buildPieChart(), isSmallScreen),
            SizedBox(height: isSmallScreen ? 12 : 16),
            _buildChartCard("Approval Statistics", _buildApprovalStatsChart(),
                isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(bool isSmallScreen) {
    return Column(
      children: [
        Card(
          color: const Color(0xFF1F2937),
          margin: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: _buildDropdownDecoration(
                            "Time Period", isSmallScreen),
                        value: 'Last 30 days',
                        items: ['Last 30 days', 'Last 7 days', 'Last 90 days']
                            .map((String value) {
                          return DropdownMenuItem(
                            value: value,
                            child: Text(
                              value,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 12 : 14,
                              ),
                            ),
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
                    SizedBox(width: isSmallScreen ? 8 : 12),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFF2DD4BF),
            child: _historyData.isEmpty
                ? _buildEmptyState(
                    'No History',
                    'No CEO actions found for selected period',
                    isSmallScreen,
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                    ),
                    itemCount: _historyData.length,
                    itemBuilder: (context, index) {
                      final request = _historyData[index];
                      return _buildHistoryCard(request, isSmallScreen);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportsTab(bool isSmallScreen) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF2DD4BF),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          children: [
            // Employee ID Report
            _buildReportSection(
              icon: Icons.person,
              title: "By Employee ID",
              color: Color(0xFF2DD4BF),
              isSmallScreen: isSmallScreen,
              fields: [
                _buildReportTextField(
                  label: "Employee ID:",
                  hint: "Enter Employee ID",
                  prefixIcon: Icons.badge,
                  onChanged: (value) => _reportIdentifier = value,
                  isSmallScreen: isSmallScreen,
                ),
                _buildReportDropdown(isSmallScreen),
              ],
              button: _buildReportButton(
                text: "Generate Employee Report",
                icon: Icons.people,
                isLoading: _isGeneratingReport,
                onPressed: _generateEmployeeReport,
                isSmallScreen: isSmallScreen,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),

            // Project ID/Code/Name Report
            _buildReportSection(
              icon: Icons.business,
              title: "By Project ID/Code/Name",
              color: Color(0xFF10B981),
              isSmallScreen: isSmallScreen,
              fields: [
                _buildReportTextField(
                  label: "Project ID/Code/Name:",
                  hint: "Enter Project ID, Code or Name",
                  prefixIcon: Icons.work,
                  onChanged: (value) => _reportIdentifier = value,
                  isSmallScreen: isSmallScreen,
                ),
                _buildReportDropdown(isSmallScreen),
              ],
              button: _buildReportButton(
                text: "Generate Project Report",
                icon: Icons.assignment,
                isLoading: _isGeneratingReport,
                onPressed: _generateProjectReport,
                isSmallScreen: isSmallScreen,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),

            // Employee ID in Particular Project Report
            _buildReportSection(
              icon: Icons.person_search,
              title: "Employee in Specific Project",
              color: Color(0xFF8B5CF6),
              isSmallScreen: isSmallScreen,
              fields: [
                _buildReportTextField(
                  label: "Employee ID:",
                  hint: "Enter Employee ID",
                  prefixIcon: Icons.badge,
                  onChanged: (value) => _employeeIdForProjectReport = value,
                  isSmallScreen: isSmallScreen,
                ),
                _buildReportTextField(
                  label: "Project ID/Code/Name:",
                  hint: "Enter Project ID, Code or Name",
                  prefixIcon: Icons.work,
                  onChanged: (value) => _projectIdForEmployeeReport = value,
                  isSmallScreen: isSmallScreen,
                ),
              ],
              button: _buildReportButton(
                text: "Generate Combined Report",
                icon: Icons.insights,
                isLoading: _isGeneratingEmployeeProjectReport,
                onPressed: _generateEmployeeProjectReport,
                isSmallScreen: isSmallScreen,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),

            // Custom Date Range Report
            _buildReportSection(
              icon: Icons.calendar_today,
              title: "Custom Date Range Report",
              color: Color(0xFFF59E0B),
              isSmallScreen: isSmallScreen,
              fields: [
                _buildDateRangeSelector(isSmallScreen),
              ],
              button: _buildReportButton(
                text: "Generate Date Range Report",
                icon: Icons.date_range,
                isLoading: _isGeneratingCustomDateReport,
                onPressed: _generateCustomDateRangeReport,
                isSmallScreen: isSmallScreen,
                color: Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportSection({
    required IconData icon,
    required String title,
    required Color color,
    required bool isSmallScreen,
    required List<Widget> fields,
    required Widget button,
  }) {
    return Card(
      color: const Color(0xFF1F2937),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            ...fields,
            SizedBox(height: isSmallScreen ? 12 : 16),
            button,
          ],
        ),
      ),
    );
  }

  Widget _buildReportTextField({
    required String label,
    required String hint,
    required IconData prefixIcon,
    required Function(String) onChanged,
    required bool isSmallScreen,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: isSmallScreen ? 12 : 14,
          ),
        ),
        SizedBox(height: isSmallScreen ? 4 : 8),
        TextField(
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: isSmallScreen ? 12 : 14,
            ),
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2DD4BF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            filled: true,
            fillColor: Color(0xFF374151),
            prefixIcon: Icon(prefixIcon, color: Colors.grey),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isSmallScreen ? 12 : 16,
            ),
          ),
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 12 : 14,
          ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
      ],
    );
  }

  Widget _buildReportDropdown(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Time Period:",
          style: TextStyle(
              color: Color(0xFF9CA3AF), fontSize: isSmallScreen ? 12 : 14),
        ),
        SizedBox(height: isSmallScreen ? 4 : 8),
        DropdownButtonFormField<String>(
          value: _reportPeriod,
          dropdownColor: const Color(0xFF374151),
          style:
              TextStyle(color: Colors.white, fontSize: isSmallScreen ? 12 : 14),
          decoration: _buildDropdownDecoration("", isSmallScreen),
          items: [
            DropdownMenuItem(
              value: '1_month',
              child: Text('Last 1 Month'),
            ),
            DropdownMenuItem(
              value: '3_months',
              child: Text('Last 3 Months'),
            ),
            DropdownMenuItem(
              value: '6_months',
              child: Text('Last 6 Months'),
            ),
            DropdownMenuItem(
              value: 'all_time',
              child: Text('All Time'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _reportPeriod = value!;
            });
          },
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
      ],
    );
  }

  Widget _buildReportButton({
    required String text,
    required IconData icon,
    required bool isLoading,
    required VoidCallback onPressed,
    required bool isSmallScreen,
    Color? color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Color.fromARGB(255, 207, 205, 213),
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 14),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Generating...",
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: isSmallScreen ? 16 : 20),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDateRangeSelector(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select Date Range:",
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: isSmallScreen ? 12 : 14,
          ),
        ),
        SizedBox(height: isSmallScreen ? 6 : 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Start Date:",
                    style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: isSmallScreen ? 10 : 12),
                  ),
                  SizedBox(height: isSmallScreen ? 2 : 4),
                  ElevatedButton(
                    onPressed: () => _selectStartDate(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF374151),
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: isSmallScreen ? 8 : 10,
                      ),
                      minimumSize: Size(0, isSmallScreen ? 36 : 40),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _customStartDate != null
                                ? DateFormat('MMM dd, yyyy')
                                    .format(_customStartDate!)
                                : "Select Start Date",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 10 : 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.calendar_today,
                            size: isSmallScreen ? 14 : 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "End Date:",
                    style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: isSmallScreen ? 10 : 12),
                  ),
                  SizedBox(height: isSmallScreen ? 2 : 4),
                  ElevatedButton(
                    onPressed: () => _selectEndDate(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF374151),
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: isSmallScreen ? 8 : 10,
                      ),
                      minimumSize: Size(0, isSmallScreen ? 36 : 40),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _customEndDate != null
                                ? DateFormat('MMM dd, yyyy')
                                    .format(_customEndDate!)
                                : "Select End Date",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 10 : 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.calendar_today,
                            size: isSmallScreen ? 14 : 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_customStartDate != null && _customEndDate != null) ...[
          SizedBox(height: isSmallScreen ? 8 : 12),
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
            decoration: BoxDecoration(
              color: Color(0xFF374151),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today,
                    size: isSmallScreen ? 14 : 16, color: Color(0xFFF59E0B)),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Expanded(
                  child: Text(
                    "Selected: ${DateFormat('MMM dd, yyyy').format(_customStartDate!)} - ${DateFormat('MMM dd, yyyy').format(_customEndDate!)}",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 10 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(String title, String value, bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: isSmallScreen ? 10 : 12),
          ),
          SizedBox(height: isSmallScreen ? 2 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2DD4BF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String value, bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: isSmallScreen ? 10 : 12),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2DD4BF),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chart, bool isSmallScreen) {
    return Card(
      color: const Color(0xFF1F2937),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                if (_activeTab == 1)
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      size: isSmallScreen ? 16 : 18,
                      color: Color(0xFF2DD4BF),
                    ),
                    onPressed: _loadAnalyticsData,
                    tooltip: 'Refresh Chart',
                  ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            chart,
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChart() {
    final reimbursementCount = _analyticsData['reimbursement_count'] ?? 0;
    final advanceCount = _analyticsData['advance_count'] ?? 0;

    if (reimbursementCount == 0 && advanceCount == 0) {
      return SizedBox(
        height: 150,
        child: Center(
          child: Text(
            "No data available",
            style: TextStyle(color: Color(0xFF9CA3AF)),
            textAlign: TextAlign.center,
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
                  "Reimbursements",
                  Colors.blue,
                  reimbursementCount,
                ),
                _buildChartLegend("Advances", Colors.purple, advanceCount),
              ],
            ),
            SizedBox(height: 20),
            Text(
              "Total: ${reimbursementCount + advanceCount} requests",
              style: TextStyle(color: Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final departmentStats = List<Map<String, dynamic>>.from(
      _analyticsData['department_stats'] ?? [],
    );

    if (departmentStats.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pie_chart, size: 48, color: Colors.grey.shade600),
              SizedBox(height: 8),
              Text(
                "No department data",
                style: TextStyle(color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: departmentStats.length,
              itemBuilder: (context, index) {
                final dept = departmentStats[index];
                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF374151),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: [
                            Colors.blue,
                            Colors.green,
                            Colors.orange,
                            Colors.purple,
                            Colors.red,
                            Colors.teal,
                          ][index % 6],
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          dept['department'] ?? 'Unknown',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "₹${dept['amount']?.toStringAsFixed(0) ?? '0'}",
                        style: TextStyle(
                          color: Color(0xFF2DD4BF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Total Departments: ${departmentStats.length}",
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
        ],
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
            SizedBox(height: 20),
            Text(
              "Total: ${approved + rejected + pending} requests",
              style: TextStyle(color: Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color, int count) {
    return Column(
      children: [
        Container(width: 20, height: 20, color: color),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white, fontSize: 12),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          count.toString(),
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> request, bool isSmallScreen) {
    return Card(
      color: const Color(0xFF1F2937),
      margin: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
      child: ListTile(
        contentPadding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        leading: request['employee_avatar'] != null
            ? CircleAvatar(
                radius: isSmallScreen ? 20 : 24,
                backgroundImage: NetworkImage(request['employee_avatar']),
              )
            : CircleAvatar(
                radius: isSmallScreen ? 20 : 24,
                backgroundColor: Colors.grey.shade800,
                child: Text(
                  (request['employee_name']?[0] ?? 'U').toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                ),
              ),
        title: Text(
          request['employee_name'] ?? 'Unknown',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: isSmallScreen ? 12 : 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: isSmallScreen ? 2 : 4),
            Text(
              request['type'] ?? 'Unknown type',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: isSmallScreen ? 10 : 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              request['date'] ?? 'Unknown date',
              style: TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: isSmallScreen ? 9 : 10),
              overflow: TextOverflow.ellipsis,
            ),
            if (request['ceo_action'] == 'rejected' &&
                request['rejection_reason'] != null)
              Text(
                'CEO Rejected: ${request['rejection_reason']}',
                style: TextStyle(
                    color: Colors.orange, fontSize: isSmallScreen ? 9 : 10),
                overflow: TextOverflow.ellipsis,
              ),
            if (request['ceo_action'] == 'approved')
              Text(
                'CEO Approved',
                style: TextStyle(
                    color: Colors.green, fontSize: isSmallScreen ? 9 : 10),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "₹${(request['amount'] ?? 0).toStringAsFixed(0)}",
              style: TextStyle(
                color: Color(0xFF2DD4BF),
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
            SizedBox(height: isSmallScreen ? 2 : 4),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 6 : 8,
                  vertical: isSmallScreen ? 1 : 2),
              decoration: BoxDecoration(
                color: _getStatusColor(request['status']),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                request['status'] ?? 'Unknown',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 8 : 10,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String message, bool isSmallScreen) {
    return SingleChildScrollView(
      child: Container(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined,
                    size: isSmallScreen ? 48 : 64, color: Colors.grey.shade600),
                SizedBox(height: isSmallScreen ? 12 : 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isSmallScreen ? 6 : 8),
                Text(
                  message,
                  style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: isSmallScreen ? 12 : 14),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildDropdownDecoration(String label, bool isSmallScreen) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: isSmallScreen ? 12 : 14,
      ),
      border: OutlineInputBorder(),
      filled: true,
      fillColor: Color(0xFF374151),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isSmallScreen ? 12 : 16,
      ),
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
}
