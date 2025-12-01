import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'finance_request_details.dart';
import '../models/finance_request.dart';
import '../utils/date_formatter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class FinancePaymentDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String authToken;
  final VoidCallback onLogout;

  const FinancePaymentDashboard({
    Key? key,
    required this.userData,
    required this.authToken,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<FinancePaymentDashboard> createState() =>
      _FinancePaymentDashboardState();
}

class _FinancePaymentDashboardState extends State<FinancePaymentDashboard>
    with SingleTickerProviderStateMixin {
  List<dynamic> _readyForPayment = [];
  List<dynamic> _paidRequests = [];
  bool _isLoading = true;
  String _errorMessage = '';
  late TabController _tabController;

  // Filter variables
  String _searchQuery = '';
  String _sortFilter = 'Latest';
  String _amountFilter = 'All';

  // Insights data
  Map<String, dynamic> _insightsData = {};

  // Report generation variables
  String _reportType = 'employee';
  String _reportPeriod = '1_month';
  String _reportIdentifier = '';
  bool _isGeneratingReport = false;

  // Employee project spending variables
  String _employeeProjectReportType = 'employee_project';
  String _employeeProjectPeriod = '1_month';
  String _employeeIdForProjectReport = '';
  String _projectIdForEmployeeReport = '';
  bool _isGeneratingEmployeeProjectReport = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await _loadPaymentData();
    await _loadPaymentInsights();
  }

  Future<void> _loadPaymentData() async {
    try {
      final response = await http.get(
        Uri.parse("http://10.0.2.2:8000/api/finance-payment/dashboard/"),
        headers: {
          "Authorization": "Token ${widget.authToken}",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("🔍 Payment Dashboard API Response: ${jsonEncode(data)}");

        setState(() {
          _readyForPayment = data['ready_for_payment'] ?? [];
          _paidRequests = data['paid_requests'] ?? [];
          _isLoading = false;

          // Debug: Print first request to check avatar data
          if (_readyForPayment.isNotEmpty) {
            print(
                "🔍 First request avatar: ${_readyForPayment.first['employee_avatar']}");
          }

          // Sort by latest first
          _readyForPayment.sort((a, b) {
            final dateA =
                DateTime.tryParse(a['approved_date'] ?? '') ?? DateTime(0);
            final dateB =
                DateTime.tryParse(b['approved_date'] ?? '') ?? DateTime(0);
            return dateB.compareTo(dateA);
          });

          _paidRequests.sort((a, b) {
            final dateA =
                DateTime.tryParse(a['payment_date'] ?? '') ?? DateTime(0);
            final dateB =
                DateTime.tryParse(b['payment_date'] ?? '') ?? DateTime(0);
            return dateB.compareTo(dateA);
          });
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load data: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPaymentInsights() async {
    try {
      final response = await http.get(
        Uri.parse("http://10.0.2.2:8000/api/finance-payment/insights/"),
        headers: {
          "Authorization": "Token ${widget.authToken}",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _insightsData = data;
        });
      }
    } catch (e) {
      print("Error loading payment insights: $e");
    }
  }

  // ✅ IMPROVED: BETTER AVATAR DISPLAY WIDGET
  Widget _buildAvatar(String? avatarUrl,
      {double radius = 16, bool isAppBar = false}) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      // Check if URL is valid and not placeholder
      if (avatarUrl.startsWith('http') &&
          !avatarUrl.contains('placeholder') &&
          !avatarUrl.contains('default')) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(avatarUrl),
          backgroundColor: Colors.transparent,
          onBackgroundImageError: (exception, stackTrace) {
            print("❌ Avatar image failed to load: $avatarUrl");
          },
        );
      }
    }

    // Fallback avatar with different styles for app bar and cards
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          isAppBar ? Colors.white.withOpacity(0.2) : Color(0xFF0D47A1),
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: isAppBar ? radius * 1.2 : radius * 1.1,
      ),
    );
  }

  // ✅ FIXED: MARK AS PAID WITH CORRECT ENDPOINT
  Future<void> _markAsPaid(int requestId, String requestType) async {
    try {
      final response = await http.post(
        Uri.parse("http://10.0.2.2:8000/api/finance-payment/mark-paid/"),
        headers: {
          "Authorization": "Token ${widget.authToken}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          'request_id': requestId,
          'request_type': requestType,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Request marked as paid successfully"),
            backgroundColor: Colors.green[800],
          ),
        );
        _loadAllData(); // Refresh data
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Failed to mark as paid: ${errorData['error'] ?? 'Unknown error'}"),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  // ✅ IMPROVED: CONVERT TO FINANCE REQUEST WITH BETTER AVATAR HANDLING
  FinanceRequest _convertToFinanceRequest(dynamic requestData) {
    List<dynamic> payments = [];
    List<dynamic> mainAttachments = [];

    // Enhanced attachment extraction
    if (requestData['attachments'] != null) {
      if (requestData['attachments'] is List) {
        mainAttachments = List.from(requestData['attachments']);
      } else if (requestData['attachments'] is String) {
        try {
          mainAttachments = jsonDecode(requestData['attachments']);
        } catch (e) {
          mainAttachments = [requestData['attachments']];
        }
      }
    }

    if (requestData['payments'] != null) {
      if (requestData['payments'] is String) {
        try {
          payments = jsonDecode(requestData['payments']);
        } catch (e) {
          print("❌ Failed to parse payments JSON: $e");
        }
      } else if (requestData['payments'] is List) {
        payments = List.from(requestData['payments']);
      }

      for (var payment in payments) {
        if (payment is Map<String, dynamic>) {
          final paymentAttachments = _extractAttachmentsFromPayment(payment);
          if (paymentAttachments.isNotEmpty) {
            mainAttachments.addAll(paymentAttachments);
          }
        }
      }
    }

    if (payments.isEmpty) {
      Map<String, dynamic> mainPayment = {
        'amount': requestData['amount'] ?? 0,
        'description': requestData['description'] ?? '',
        'date': requestData['approved_date'] ??
            requestData['submitted_date'] ??
            requestData['date'] ??
            '',
        'claimType': requestData['claim_type'] ?? '',
        'attachmentPaths': mainAttachments,
        'attachments': mainAttachments,
      };
      payments.add(mainPayment);
    }

    FinanceRequest financeRequest = FinanceRequest(
      id: requestData['id'] ?? 0,
      employeeId: requestData['employee_id']?.toString() ?? 'Unknown',
      employeeName: requestData['employee_name']?.toString() ?? 'Unknown',
      avatarUrl: requestData['employee_avatar'], // ✅ Avatar passed directly
      submissionDate: requestData['submitted_date']?.toString() ??
          requestData['created_at']?.toString() ??
          requestData['date']?.toString() ??
          'Unknown',
      amount: (requestData['amount'] ?? 0).toDouble(),
      description: requestData['description']?.toString() ?? '',
      payments: payments,
      attachments: mainAttachments,
      requestType: requestData['request_type']?.toString() ?? 'Unknown',
      status: requestData['status'] ?? 'approved',
      approvedBy: requestData['approved_by'],
      approvalDate: requestData['approved_date'],
      projectId: requestData['project_id'] ?? requestData['projectId'],
      projectName: requestData['project_name'] ?? requestData['projectName'],
      reimbursementDate: requestData['reimbursement_date']?.toString(),
      requestDate: requestData['request_date']?.toString(),
      projectDate: requestData['project_date']?.toString(),
      paymentDate: requestData['payment_date']?.toString(),
    );

    return financeRequest;
  }

  List<String> _extractAttachmentsFromPayment(Map<String, dynamic> payment) {
    List<String> attachments = [];
    final attachmentFields = [
      'attachmentPaths',
      'attachments',
      'attachment',
      'file',
      'receipt',
      'document',
      'files'
    ];

    for (String field in attachmentFields) {
      if (payment[field] != null) {
        if (payment[field] is List) {
          for (var item in payment[field] as List) {
            if (item is String && item.isNotEmpty) {
              attachments.add(item);
            }
          }
        } else if (payment[field] is String && payment[field].isNotEmpty) {
          try {
            final parsed = jsonDecode(payment[field]);
            if (parsed is List) {
              for (var item in parsed) {
                if (item is String && item.isNotEmpty) {
                  attachments.add(item);
                }
              }
            }
          } catch (e) {
            attachments.add(payment[field]);
          }
        }
      }
    }
    return attachments;
  }

  int _getMonthlyPaidRequests() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    return _paidRequests.where((request) {
      final paymentDate = DateTime.tryParse(request['payment_date'] ?? '');
      return paymentDate != null && paymentDate.isAfter(firstDayOfMonth);
    }).length;
  }

  double _getMonthlyPaidAmount() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    double total = 0;
    for (var request in _paidRequests) {
      final paymentDate = DateTime.tryParse(request['payment_date'] ?? '');
      if (paymentDate != null && paymentDate.isAfter(firstDayOfMonth)) {
        total += (request['amount'] ?? 0).toDouble();
      }
    }
    return total;
  }

  // ✅ FIXED: REPORT GENERATION FUNCTION
  Future<void> _generateReport() async {
    if (_reportIdentifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _reportType == 'employee'
                ? "Please enter Employee ID"
                : "Please enter Project ID/Code/Name",
          ),
          backgroundColor: Colors.red[800],
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingReport = true;
    });

    try {
      // Calculate date range based on period
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
          startDate = DateTime(2000); // Very old date
          break;
        default:
          startDate = DateTime(now.year, now.month - 1, now.day);
      }

      // Filter data based on report type and period
      List<dynamic> reportData = [];

      if (_reportType == 'employee') {
        reportData = _paidRequests.where((request) {
          final employeeId = request['employee_id']?.toString() ?? '';
          final paymentDate = DateTime.tryParse(request['payment_date'] ?? '');
          return employeeId.contains(_reportIdentifier) &&
              paymentDate != null &&
              paymentDate.isAfter(startDate);
        }).toList();
      } else {
        reportData = _paidRequests.where((request) {
          final projectId = request['project_id']?.toString() ?? '';
          final projectName = request['project_name']?.toString() ?? '';
          final projectCode = request['project_code']?.toString() ?? '';
          final paymentDate = DateTime.tryParse(request['payment_date'] ?? '');

          return (projectId.contains(_reportIdentifier) ||
                  projectName
                      .toLowerCase()
                      .contains(_reportIdentifier.toLowerCase()) ||
                  projectCode.contains(_reportIdentifier)) &&
              paymentDate != null &&
              paymentDate.isAfter(startDate);
        }).toList();
      }

      if (reportData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No data found for the specified criteria"),
            backgroundColor: Colors.orange[800],
          ),
        );
        setState(() {
          _isGeneratingReport = false;
        });
        return;
      }

      // Create CSV data
      List<List<dynamic>> csvData = [];

      // Add headers
      csvData.add([
        'Request ID',
        'Employee ID',
        'Employee Name',
        'Request Type',
        'Amount',
        'Description',
        'Payment Date',
        'Project ID',
        'Project Name',
        'Status'
      ]);

      // Add rows
      for (var request in reportData) {
        csvData.add([
          request['id'] ?? '',
          request['employee_id'] ?? '',
          request['employee_name'] ?? '',
          request['request_type'] ?? '',
          (request['amount'] ?? 0).toStringAsFixed(2),
          request['description'] ?? '',
          request['payment_date'] ?? '',
          request['project_id'] ?? '',
          request['project_name'] ?? '',
          'Paid'
        ]);
      }

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(csvData);

      // Save file properly using File class
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/payment_report_${DateTime.now().millisecondsSinceEpoch}.csv';

      // Create and write the file
      final file = File(filePath);
      await file.writeAsString(csv);

      print("✅ CSV file created at: $filePath");
      print("✅ Report contains ${reportData.length} records");

      // Share file
      await Share.shareXFiles([XFile(filePath)],
          text:
              'Payment Report - ${_reportType == 'employee' ? 'Employee: $_reportIdentifier' : 'Project: $_reportIdentifier'}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Report generated successfully with ${reportData.length} records"),
          backgroundColor: Colors.green[800],
        ),
      );
    } catch (e) {
      print("❌ Error generating report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error generating report: ${e.toString()}"),
          backgroundColor: Colors.red[800],
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
          content:
              Text("Please enter both Employee ID and Project ID/Code/Name"),
          backgroundColor: Colors.red[800],
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingEmployeeProjectReport = true;
    });

    try {
      print("🔄 Fetching employee-project spending data...");

      // Use the new dedicated API endpoint
      final response = await http.get(
        Uri.parse("http://10.0.2.2:8000/api/employee-project-spending/")
            .replace(queryParameters: {
          'employee_id': _employeeIdForProjectReport,
          'project_identifier': _projectIdForEmployeeReport,
          'period': _employeeProjectPeriod,
        }),
        headers: {
          "Authorization": "Token ${widget.authToken}",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("✅ Employee-Project API response received");

        if (data['total_requests'] == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("No reimbursement data found for:\n"
                  "Employee: ${_employeeIdForProjectReport}\n"
                  "Project: ${_projectIdForEmployeeReport}\n\n"
                  "Please check:\n"
                  "• Employee ID spelling\n"
                  "• Project ID/Code/Name\n"
                  "• If reimbursements exist for this combination"),
              backgroundColor: Colors.orange[800],
              duration: Duration(seconds: 6),
            ),
          );
          setState(() {
            _isGeneratingEmployeeProjectReport = false;
          });
          return;
        } // Calculate totals from API response
        double totalSpending = (data['total_amount'] ?? 0).toDouble();
        int totalRequests = data['total_requests'] ?? 0;
        int reimbursementCount = data['reimbursement_count'] ?? 0;
        int advanceCount = data['advance_count'] ?? 0;

        // Count by status
        int approvedCount = 0;
        int paidCount = 0;
        int pendingCount = 0;

        for (var request in data['requests']) {
          final status = request['status']?.toString().toLowerCase() ?? '';
          if (status == 'approved') approvedCount++;
          if (status == 'paid') paidCount++;
          if (status == 'pending') pendingCount++;
        }

        // Create comprehensive CSV report
        List<List<dynamic>> csvData = [];

        // Add summary header
        csvData.add(['EMPLOYEE-PROJECT SPENDING REPORT']);
        csvData.add(['Generated on', DateTime.now().toString().split(' ')[0]]);
        csvData.add(['Employee ID', data['employee_id']]);
        csvData.add(['Employee Name', data['employee_name'] ?? 'Unknown']);
        csvData.add(['Project Identifier', data['project_identifier']]);
        csvData.add(
            ['Report Period', _employeeProjectPeriod.replaceAll('_', ' ')]);
        csvData.add([]);

        // Add financial summary
        csvData.add(['FINANCIAL SUMMARY']);
        csvData.add(['Total Requests', totalRequests]);
        csvData.add(['Reimbursements', reimbursementCount]);
        csvData.add(['Advances', advanceCount]);
        csvData.add(['Approved Requests', approvedCount]);
        csvData.add(['Paid Requests', paidCount]);
        csvData.add(['Pending Requests', pendingCount]);
        csvData.add(['Total Spending', '₹${totalSpending.toStringAsFixed(2)}']);
        csvData.add([]);

        // Add detailed transactions header
        csvData.add(['DETAILED REQUEST RECORDS']);
        csvData.add([
          'Request ID',
          'Type',
          'Amount',
          'Description',
          'Status',
          'Submitted Date',
          'Approved Date',
          'Payment Date',
          'Project ID',
          'Project Name'
        ]);

        // Add request rows
        for (var request in data['requests']) {
          csvData.add([
            request['id'] ?? '',
            request['request_type'] ?? '',
            '₹${(request['amount'] ?? 0).toStringAsFixed(2)}',
            request['description'] ?? '',
            request['status'] ?? '',
            request['submitted_date'] ?? '',
            request['approved_date'] ?? '',
            request['payment_date'] ?? '',
            request['project_id'] ?? '',
            request['project_name'] ?? '',
          ]);
        }

        // Convert to CSV
        String csv = const ListToCsvConverter().convert(csvData);

        // Save file
        final directory = await getTemporaryDirectory();
        final filePath =
            '${directory.path}/employee_project_spending_${_employeeIdForProjectReport}_${_projectIdForEmployeeReport}_${DateTime.now().millisecondsSinceEpoch}.csv';

        final file = File(filePath);
        await file.writeAsString(csv);

        print("✅ Employee-Project CSV file created at: $filePath");
        print("✅ Report contains $totalRequests requests");

        // Share file with detailed information
        await Share.shareXFiles([XFile(filePath)],
            text: 'Employee-Project Spending Report\n\n'
                '👤 Employee: ${data['employee_name']} (${data['employee_id']})\n'
                '📁 Project ID: ${data['project_identifier']}\n'
                '💰 Total Spending: ₹${totalSpending.toStringAsFixed(2)}\n'
                '📊 Total Requests: $totalRequests\n'
                '🧾 Reimbursements: $reimbursementCount | 💰 Advances: $advanceCount\n'
                '✅ Approved: $approvedCount | 💳 Paid: $paidCount | ⏳ Pending: $pendingCount\n'
                '📅 Period: ${_employeeProjectPeriod.replaceAll('_', ' ')}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Employee-Project report generated successfully!"),
                SizedBox(height: 4),
                Text("Total Spending: ₹${totalSpending.toStringAsFixed(2)}"),
                Text(
                    "Requests: $totalRequests (${reimbursementCount}R + ${advanceCount}A)"),
              ],
            ),
            backgroundColor: Colors.green[800],
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Failed to load data: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print("❌ Error generating employee-project report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error generating report: ${e.toString()}"),
          backgroundColor: Colors.red[800],
        ),
      );
    } finally {
      setState(() {
        _isGeneratingEmployeeProjectReport = false;
      });
    }
  }

  // ✅ IMPROVED: REQUEST CARD WITH BETTER AVATAR DISPLAY
  Widget _buildRequestCard(dynamic request, bool isPaid) {
    const Color pastelGreen = Color(0xFFA5D6A7);
    const Color pastelTeal = Color(0xFF80CBC4);
    const Color pastelOrange = Color(0xFFFFAB91);

    int paymentCount =
        request['payments'] != null ? (request['payments'] as List).length : 0;

    int attachmentCount = 0;
    if (request['attachments'] != null && request['attachments'] is List) {
      attachmentCount = (request['attachments'] as List).length;
    }

    bool isReimbursement =
        request['request_type']?.toLowerCase().contains('reimbursement') ??
            false;

    String formattedApprovedDate =
        DateFormatter.formatBackendDate(request['approved_date']);
    String formattedPaymentDate =
        DateFormatter.formatBackendDate(request['payment_date']);
    String formattedSubmittedDate =
        DateFormatter.formatBackendDate(request['submitted_date']);

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: 120,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ IMPROVED: Avatar row with better layout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // ✅ IMPROVED: Avatar with better error handling
                        _buildAvatar(request['employee_avatar'], radius: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request['employee_name'] ?? 'Unknown Employee',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                'ID: ${request['employee_id'] ?? 'Unknown'}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
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
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isReimbursement ? pastelTeal : pastelOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      request['request_type'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Dates and Amount row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (request['approved_date'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CEO Approved',
                                  style: TextStyle(
                                    color: Colors.green[300],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  formattedApprovedDate,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        if (isPaid && request['payment_date'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Paid on',
                                  style: TextStyle(
                                    color: Colors.green[300],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  formattedPaymentDate,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        if (request['submitted_date'] != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Submitted',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                formattedSubmittedDate,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${(request['amount'] ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.end,
                        ),
                        Text(
                          '$paymentCount payment${paymentCount != 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.end,
                        ),
                        if (attachmentCount > 0)
                          Text(
                            '$attachmentCount attachment${attachmentCount != 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.blue[300],
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.end,
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              if (request['description'] != null &&
                  request['description'].toString().isNotEmpty)
                Container(
                  constraints: BoxConstraints(maxHeight: 40),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Text(
                      request['description'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Action buttons
              if (!isPaid &&
                  (_tabController.index == 0 || _tabController.index == 1))
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FinanceRequestDetails(
                              request: _convertToFinanceRequest(request),
                              authToken: widget.authToken,
                              isPaymentTab: true,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Details',
                        style: TextStyle(color: Color(0xFF80CBC4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _markAsPaid(
                        request['id'],
                        request['request_type'],
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pastelGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Mark as Paid',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ],
                ),

              // Status for paid requests
              if (isPaid || _tabController.index == 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        'Payment Completed',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDialog() {
    return AlertDialog(
      backgroundColor: Color(0xFF1E1E1E),
      title: Text("Filter Requests", style: TextStyle(color: Colors.white)),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Search Employee:", style: TextStyle(color: Colors.grey[400])),
            SizedBox(height: 8),
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: "Search by ID or Name",
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue)),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 16),
            Text("Sort By:", style: TextStyle(color: Colors.grey[400])),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _sortFilter,
              dropdownColor: Color(0xFF2D2D2D),
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue)),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
              ),
              items: [
                DropdownMenuItem(value: 'Latest', child: Text('Latest First')),
                DropdownMenuItem(value: 'Oldest', child: Text('Oldest First')),
              ],
              onChanged: (value) => setState(() => _sortFilter = value!),
            ),
            SizedBox(height: 16),
            Text("Amount Filter:", style: TextStyle(color: Colors.grey[400])),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _amountFilter,
              dropdownColor: Color(0xFF2D2D2D),
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue)),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
              ),
              items: [
                DropdownMenuItem(value: 'All', child: Text('All Amounts')),
                DropdownMenuItem(
                    value: 'Above 2000', child: Text('Above ₹2000')),
                DropdownMenuItem(
                    value: 'Below 2000', child: Text('Below ₹2000')),
              ],
              onChanged: (value) => setState(() => _amountFilter = value!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _searchQuery = '';
              _sortFilter = 'Latest';
              _amountFilter = 'All';
            });
            Navigator.pop(context);
          },
          child: Text("Reset", style: TextStyle(color: Colors.grey[400])),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Apply"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
        ),
      ],
    );
  }

  // ✅ COMPLETE: INSIGHTS TAB WITH ALL FUNCTIONALITY
  Widget _buildInsightsTab() {
    final readyReimbursements = _readyForPayment
        .where((request) =>
            request['request_type']?.toLowerCase().contains('reimbursement') ??
            false)
        .toList();
    final readyAdvances = _readyForPayment
        .where((request) =>
            request['request_type']?.toLowerCase().contains('advance') ?? false)
        .toList();
    final paidReimbursements = _paidRequests
        .where((request) =>
            request['request_type']?.toLowerCase().contains('reimbursement') ??
            false)
        .toList();
    final paidAdvances = _paidRequests
        .where((request) =>
            request['request_type']?.toLowerCase().contains('advance') ?? false)
        .toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Payment Insights",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 15),

          // Insight Cards
          LayoutBuilder(
            builder: (context, constraints) {
              double crossAxisCount = 2;
              double childAspectRatio = 0.8;

              // Responsive adjustments
              if (constraints.maxWidth < 400) {
                crossAxisCount = 2;
                childAspectRatio = 0.7;
              } else if (constraints.maxWidth > 600) {
                crossAxisCount = 4;
                childAspectRatio = 1.0;
              }

              return GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount.toInt(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 6,
                childAspectRatio: childAspectRatio,
                children: [
                  _buildInsightCard(
                    "Ready for Payment",
                    _readyForPayment.length.toString(),
                    Icons.payment,
                    Colors.orange,
                  ),
                  _buildInsightCard(
                    "Paid Requests (Monthly)",
                    _getMonthlyPaidRequests().toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildInsightCard(
                    "Total Amount Ready",
                    "₹${_calculateTotalAmount(_readyForPayment)}",
                    Icons.attach_money,
                    Colors.blue,
                  ),
                  _buildInsightCard(
                    "Total Amount Paid (Monthly)",
                    "₹${_getMonthlyPaidAmount().toStringAsFixed(2)}",
                    Icons.currency_rupee,
                    Colors.purple,
                  ),
                ],
              );
            },
          ),

          SizedBox(height: 24),

          // Payment Statistics
          Card(
            color: Color(0xFF2D2D2D),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bar_chart, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        "Payment Overview",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildStatItem("Reimbursements Ready",
                      readyReimbursements.length.toString()),
                  _buildStatItem(
                      "Advances Ready", readyAdvances.length.toString()),
                  _buildStatItem("Reimbursements Paid",
                      paidReimbursements.length.toString()),
                  _buildStatItem(
                      "Advances Paid", paidAdvances.length.toString()),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Report Generation Section
          Card(
            color: Color(0xFF2D2D2D),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assignment, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        "Generate Reports",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Report Type Selection
                  Text(
                    "Report Type:",
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 400) {
                        return Column(
                          children: [
                            RadioListTile<String>(
                              title: Text(
                                "By Employee",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                              value: 'employee',
                              groupValue: _reportType,
                              onChanged: (value) {
                                setState(() {
                                  _reportType = value!;
                                  _reportIdentifier = '';
                                });
                              },
                              activeColor: Colors.blue,
                            ),
                            RadioListTile<String>(
                              title: Text(
                                "By Project",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                              value: 'project',
                              groupValue: _reportType,
                              onChanged: (value) {
                                setState(() {
                                  _reportType = value!;
                                  _reportIdentifier = '';
                                });
                              },
                              activeColor: Colors.blue,
                            ),
                          ],
                        );
                      } else {
                        return Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text(
                                  "By Employee",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                                value: 'employee',
                                groupValue: _reportType,
                                onChanged: (value) {
                                  setState(() {
                                    _reportType = value!;
                                    _reportIdentifier = '';
                                  });
                                },
                                activeColor: Colors.blue,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text(
                                  "By Project",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                                value: 'project',
                                groupValue: _reportType,
                                onChanged: (value) {
                                  setState(() {
                                    _reportType = value!;
                                    _reportIdentifier = '';
                                  });
                                },
                                activeColor: Colors.blue,
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),

                  // Time Period Selection
                  SizedBox(height: 12),
                  Text(
                    "Time Period:",
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _reportPeriod,
                    dropdownColor: Color(0xFF2D2D2D),
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: '1_month', child: Text('Last 1 Month')),
                      DropdownMenuItem(
                          value: '3_months', child: Text('Last 3 Months')),
                      DropdownMenuItem(
                          value: '6_months', child: Text('Last 6 Months')),
                      DropdownMenuItem(
                          value: 'all_time', child: Text('All Time')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _reportPeriod = value!;
                      });
                    },
                  ),

                  // Identifier Input
                  SizedBox(height: 12),
                  Text(
                    _reportType == 'employee'
                        ? "Employee ID:"
                        : "Project ID/Code/Name:",
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        _reportIdentifier = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: _reportType == 'employee'
                          ? "Enter Employee ID"
                          : "Enter Project ID, Code or Name",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                  ),

                  // Generate Report Button
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isGeneratingReport ? null : _generateReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isGeneratingReport
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text("Generating Report..."),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.download),
                                SizedBox(width: 8),
                                Text("Generate CSV Report"),
                              ],
                            ),
                    ),
                  ),

                  // Employee-Project Spending Report Section
                  SizedBox(height: 24),
                  Divider(color: Colors.grey[700]),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.people, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        "Employee-Project Spending Report",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Employee-Project Time Period
                  Text(
                    "Time Period:",
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _employeeProjectPeriod,
                    dropdownColor: Color(0xFF2D2D2D),
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.green),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: '1_month', child: Text('Last 1 Month')),
                      DropdownMenuItem(
                          value: '3_months', child: Text('Last 3 Months')),
                      DropdownMenuItem(
                          value: '6_months', child: Text('Last 6 Months')),
                      DropdownMenuItem(
                          value: 'all_time', child: Text('All Time')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _employeeProjectPeriod = value!;
                      });
                    },
                  ),

                  // Employee ID Input
                  SizedBox(height: 12),
                  Text(
                    "Employee ID:",
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        _employeeIdForProjectReport = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Enter Employee ID",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.green),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                  ),

                  // Project ID Input
                  SizedBox(height: 12),
                  Text(
                    "Project ID/Code/Name:",
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        _projectIdForEmployeeReport = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Enter Project ID, Code or Name",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.green),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                  ),

                  // Generate Employee-Project Report Button
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isGeneratingEmployeeProjectReport
                          ? null
                          : _generateEmployeeProjectReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isGeneratingEmployeeProjectReport
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text("Generating Report..."),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.analytics),
                                SizedBox(width: 8),
                                Text("Generate Spending Report"),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      color: Color(0xFF2D2D2D),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[400]),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateTotalAmount(List<dynamic> requests) {
    double total = 0;
    for (var request in requests) {
      total += (request['amount'] ?? 0).toDouble();
    }
    return total.toStringAsFixed(2);
  }

  List<dynamic> _getFilteredRequests(List<dynamic> requests, String tabType) {
    List<dynamic> filtered = List.from(requests);

    if (tabType == 'reimbursement') {
      filtered = filtered.where((request) {
        final requestType =
            request['request_type']?.toString().toLowerCase() ?? '';
        return requestType.contains('reimbursement');
      }).toList();
    } else if (tabType == 'advance') {
      filtered = filtered.where((request) {
        final requestType =
            request['request_type']?.toString().toLowerCase() ?? '';
        return requestType.contains('advance');
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((request) {
        final employeeId =
            request['employee_id']?.toString().toLowerCase() ?? '';
        final employeeName =
            request['employee_name']?.toString().toLowerCase() ?? '';
        return employeeId.contains(_searchQuery.toLowerCase()) ||
            employeeName.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_amountFilter == 'Above 2000') {
      filtered = filtered.where((request) {
        final amount = (request['amount'] ?? 0).toDouble();
        return amount > 2000;
      }).toList();
    } else if (_amountFilter == 'Below 2000') {
      filtered = filtered.where((request) {
        final amount = (request['amount'] ?? 0).toDouble();
        return amount <= 2000;
      }).toList();
    }

    if (_sortFilter == 'Latest') {
      filtered.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['approved_date'] ?? a['payment_date'] ?? '') ??
                DateTime(0);
        final dateB =
            DateTime.tryParse(b['approved_date'] ?? b['payment_date'] ?? '') ??
                DateTime(0);
        return dateB.compareTo(dateA);
      });
    } else if (_sortFilter == 'Oldest') {
      filtered.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['approved_date'] ?? a['payment_date'] ?? '') ??
                DateTime(0);
        final dateB =
            DateTime.tryParse(b['approved_date'] ?? b['payment_date'] ?? '') ??
                DateTime(0);
        return dateA.compareTo(dateB);
      });
    }

    return filtered;
  }

  Widget _buildTabContent(String tabType, String tabName) {
    List<dynamic> requests = [];
    bool isPaid = false;

    if (tabType == 'reimbursement' || tabType == 'advance') {
      requests = _readyForPayment;
      isPaid = false;
    } else if (tabType == 'history') {
      requests = _paidRequests;
      isPaid = true;
    }

    final filteredRequests = _getFilteredRequests(requests, tabType);

    return Column(
      children: [
        if (_searchQuery.isNotEmpty || _amountFilter != 'All')
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.filter_alt, color: Colors.blue, size: 16),
                SizedBox(width: 4),
                Text("Filters applied",
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _amountFilter = 'All';
                    });
                  },
                  child: Text("Clear", style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
          ),
        Expanded(
          child: filteredRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getTabIcon(tabType),
                          color: Colors.grey[600], size: 64),
                      SizedBox(height: 16),
                      Text(_getEmptyStateText(tabType, tabName),
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 16)),
                      if (_searchQuery.isNotEmpty || _amountFilter != 'All')
                        Text("Try adjusting your filters",
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    return _buildRequestCard(filteredRequests[index], isPaid);
                  },
                ),
        ),
      ],
    );
  }

  IconData _getTabIcon(String tabType) {
    switch (tabType) {
      case 'reimbursement':
        return Icons.receipt;
      case 'advance':
        return Icons.forward;
      case 'insights':
        return Icons.analytics;
      case 'history':
        return Icons.history;
      default:
        return Icons.payment;
    }
  }

  String _getEmptyStateText(String tabType, String tabName) {
    switch (tabType) {
      case 'reimbursement':
        return "No reimbursement requests ready for payment";
      case 'advance':
        return "No advance requests ready for payment";
      case 'insights':
        return "Insights will be available soon";
      case 'history':
        return "No payment history";
      default:
        return "No data available";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            return Text(
              "Finance Payment",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: constraints.maxWidth < 400 ? 18 : 20,
              ),
            );
          },
        ),
        backgroundColor: Color.fromARGB(255, 12, 15, 49),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          // Logout Icon - Moved to first position
          IconButton(
            icon: Icon(Icons.logout, size: 22),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Color(0xFF1E1E1E),
                  title: Text("Logout", style: TextStyle(color: Colors.white)),
                  content: Text("Are you sure you want to logout?",
                      style: TextStyle(color: Colors.grey[400])),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel",
                          style: TextStyle(color: Colors.grey[400])),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onLogout();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700]),
                      child: Text("Logout"),
                    ),
                  ],
                ),
              );
            },
            tooltip: "Logout",
          ),
          // Filter Icon
          IconButton(
            icon: Icon(Icons.filter_list, size: 22),
            onPressed: () => showDialog(
                context: context, builder: (context) => _buildFilterDialog()),
            tooltip: "Filter Requests",
          ),
          // Refresh Icon
          IconButton(
            icon: Icon(Icons.refresh, size: 22),
            onPressed: _loadAllData,
            tooltip: "Refresh Data",
          ),
          // Avatar with proper spacing
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: _buildAvatar(widget.userData['avatar'],
                radius: 18, isAppBar: true),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.0),
          child: Container(
            color: Color.fromARGB(255, 12, 15, 49),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.white,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey[400],
                      labelStyle: TextStyle(
                        fontSize: constraints.maxWidth < 400 ? 10 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: constraints.maxWidth < 400 ? 10 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorWeight: 3.0,
                      indicatorPadding: EdgeInsets.symmetric(horizontal: 4),
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      isScrollable: constraints.maxWidth < 400,
                      tabs: [
                        Tab(
                          icon: constraints.maxWidth < 400
                              ? Icon(Icons.receipt, size: 16)
                              : null,
                          text: constraints.maxWidth < 400
                              ? "Reimb."
                              : "Reimbursement",
                        ),
                        Tab(
                          icon: constraints.maxWidth < 400
                              ? Icon(Icons.forward, size: 16)
                              : null,
                          text: constraints.maxWidth < 400
                              ? "Advance"
                              : "Advance",
                        ),
                        Tab(
                          icon: constraints.maxWidth < 400
                              ? Icon(Icons.analytics, size: 16)
                              : null,
                          text: constraints.maxWidth < 400
                              ? "Insights"
                              : "Insights",
                        ),
                        Tab(
                          icon: constraints.maxWidth < 400
                              ? Icon(Icons.history, size: 16)
                              : null,
                          text: constraints.maxWidth < 400
                              ? "History"
                              : "History",
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(_errorMessage,
                      style: TextStyle(color: Colors.white)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTabContent('reimbursement', 'Reimbursement'),
                    _buildTabContent('advance', 'Advance'),
                    _buildInsightsTab(),
                    _buildTabContent('history', 'History'),
                  ],
                ),
    );
  }
}
