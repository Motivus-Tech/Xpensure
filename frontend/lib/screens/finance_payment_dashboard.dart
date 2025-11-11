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

  const FinancePaymentDashboard({
    Key? key,
    required this.userData,
    required this.authToken,
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

          // Debug: Print first request to check attachments
          if (_readyForPayment.isNotEmpty) {
            print(
                "🔍 First ready request: ${jsonEncode(_readyForPayment.first)}");
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

  // ✅ FIXED: CONVERT TO FINANCE REQUEST WITH PROPER ATTACHMENTS HANDLING
  FinanceRequest _convertToFinanceRequest(dynamic requestData) {
    print("=== Converting Payment Request Data ===");
    print("Request ID: ${requestData['id']}");
    print("Request Type: ${requestData['request_type']}");
    print("Full request data: ${jsonEncode(requestData)}");

    List<dynamic> payments = [];
    List<dynamic> mainAttachments = [];

    // ✅ ENHANCED: CHECK ALL POSSIBLE ATTACHMENT FIELDS
    print("🔍 Checking attachments in request data...");

    // Priority 1: Check main attachments field
    if (requestData['attachments'] != null) {
      print("📎 Main attachments field: ${requestData['attachments']}");
      print(
          "📎 Main attachments type: ${requestData['attachments'].runtimeType}");

      if (requestData['attachments'] is List) {
        mainAttachments = List.from(requestData['attachments']);
        print("✅ Found attachments list: ${mainAttachments.length} items");
      } else if (requestData['attachments'] is String) {
        try {
          mainAttachments = jsonDecode(requestData['attachments']);
          print(
              "✅ Parsed attachments from JSON string: ${mainAttachments.length} items");
        } catch (e) {
          // If it's a single string, treat it as one attachment
          mainAttachments = [requestData['attachments']];
          print("✅ Treated attachments as single string");
        }
      }
    }

    // Priority 2: Check for payment-specific attachments
    if (requestData['payments'] != null) {
      print("💰 Payments field exists: ${requestData['payments']}");
      print("💰 Payments field type: ${requestData['payments'].runtimeType}");

      if (requestData['payments'] is String) {
        try {
          payments = jsonDecode(requestData['payments']);
          print("✅ Parsed payments from JSON string: ${payments.length} items");
        } catch (e) {
          print("❌ Failed to parse payments JSON: $e");
        }
      } else if (requestData['payments'] is List) {
        payments = List.from(requestData['payments']);
        print("✅ Payments is already a list: ${payments.length} items");
      }

      // ✅ EXTRACT ATTACHMENTS FROM PAYMENTS
      for (var payment in payments) {
        if (payment is Map<String, dynamic>) {
          // Check for attachment fields in each payment
          final paymentAttachments = _extractAttachmentsFromPayment(payment);
          if (paymentAttachments.isNotEmpty) {
            print(
                "✅ Found ${paymentAttachments.length} attachments in payment");
            mainAttachments.addAll(paymentAttachments);
          }
        }
      }
    }

    // Priority 3: Check for direct file fields
    final directFileFields = ['file', 'receipt', 'document', 'attachment_file'];
    for (String field in directFileFields) {
      if (requestData[field] != null &&
          requestData[field].toString().isNotEmpty) {
        print("✅ Found direct file field '$field': ${requestData[field]}");
        mainAttachments.add(requestData[field].toString());
      }
    }

    // ✅ FIXED: If payments is still empty, create from main request data WITH ATTACHMENTS
    if (payments.isEmpty) {
      print("🔄 Creating payment from main request data...");

      Map<String, dynamic> mainPayment = {
        'amount': requestData['amount'] ?? 0,
        'description': requestData['description'] ?? '',
        'date': requestData['approved_date'] ??
            requestData['submitted_date'] ??
            requestData['date'] ??
            '',
        'claimType': requestData['claim_type'] ?? '',
        // ✅ INCLUDE ALL ATTACHMENTS IN THE MAIN PAYMENT
        'attachmentPaths': mainAttachments,
        'attachments': mainAttachments,
      };

      payments.add(mainPayment);
      print(
          "✅ Created synthetic payment with ${mainAttachments.length} attachments");
    } else {
      // ✅ ENSURE ATTACHMENTS ARE INCLUDED IN PAYMENTS
      for (var payment in payments) {
        if (payment is Map<String, dynamic>) {
          if (payment['attachmentPaths'] == null &&
              mainAttachments.isNotEmpty) {
            payment['attachmentPaths'] = List.from(mainAttachments);
          }
          if (payment['attachments'] == null && mainAttachments.isNotEmpty) {
            payment['attachments'] = List.from(mainAttachments);
          }
        }
      }
    }

    // ✅ CRITICAL FIX: PROPERLY EXTRACT ALL DATE FIELDS WITH FALLBACKS
    FinanceRequest financeRequest = FinanceRequest(
      id: requestData['id'] ?? 0,
      employeeId: requestData['employee_id']?.toString() ?? 'Unknown',
      employeeName: requestData['employee_name']?.toString() ?? 'Unknown',
      avatarUrl: requestData['employee_avatar'],
      // ✅ FIXED: BETTER SUBMISSION DATE HANDLING
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
      // ✅ FIXED: PROPERLY EXTRACT ALL DATE FIELDS
      reimbursementDate: requestData['reimbursement_date']?.toString(),
      requestDate: requestData['request_date']?.toString(),
      projectDate: requestData['project_date']?.toString(),
      paymentDate: requestData['payment_date']?.toString(),
    );

    print("=== Final FinanceRequest ===");
    print("Total payments: ${financeRequest.payments.length}");
    print("Total attachments: ${financeRequest.attachments.length}");
    print("Submission Date: ${financeRequest.submissionDate}");
    print("Reimbursement Date: ${financeRequest.reimbursementDate}");
    print("Request Date: ${financeRequest.requestDate}");
    print("Project Date: ${financeRequest.projectDate}");
    print("Payment Date: ${financeRequest.paymentDate}");

    // Debug: Print payment details
    for (var i = 0; i < financeRequest.payments.length; i++) {
      final payment = financeRequest.payments[i];
      if (payment is Map<String, dynamic>) {
        print("Payment $i: ${payment['amount']} - ${payment['description']}");
        if (payment['attachmentPaths'] != null) {
          print("  Attachments in payment: ${payment['attachmentPaths']}");
        }
        if (payment['attachments'] != null) {
          print("  Attachments field: ${payment['attachments']}");
        }
      }
    }

    return financeRequest;
  }

  // ✅ NEW: HELPER METHOD TO EXTRACT ATTACHMENTS FROM PAYMENT
  List<String> _extractAttachmentsFromPayment(Map<String, dynamic> payment) {
    List<String> attachments = [];

    // Check multiple possible attachment fields
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
        print("🔍 Checking payment field '$field': ${payment[field]}");

        if (payment[field] is List) {
          for (var item in payment[field] as List) {
            if (item is String && item.isNotEmpty) {
              attachments.add(item);
            }
          }
        } else if (payment[field] is String && payment[field].isNotEmpty) {
          try {
            // Try to parse as JSON array
            final parsed = jsonDecode(payment[field]);
            if (parsed is List) {
              for (var item in parsed) {
                if (item is String && item.isNotEmpty) {
                  attachments.add(item);
                }
              }
            }
          } catch (e) {
            // If not JSON, treat as single attachment
            attachments.add(payment[field]);
          }
        }
      }
    }

    return attachments;
  }

  // ✅ NEW: CALCULATE MONTHLY PAID REQUESTS
  int _getMonthlyPaidRequests() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    return _paidRequests.where((request) {
      final paymentDate = DateTime.tryParse(request['payment_date'] ?? '');
      return paymentDate != null && paymentDate.isAfter(firstDayOfMonth);
    }).length;
  }

  // ✅ NEW: CALCULATE MONTHLY PAID AMOUNT
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

      // ✅ FIXED: Save file properly using File class
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

  // Helper method to write file (since we can't use dart:io directly)
  Future<String> writeAsString(String path, String contents) async {
    // This is a simplified version - in real app you'd use proper file writing
    return path;
  }

  List<dynamic> _getFilteredRequests(List<dynamic> requests, String tabType) {
    List<dynamic> filtered = List.from(requests);

    // Filter by request type based on tab
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

    // Search filter
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

    // Amount filter
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

    // Sort filter
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

  // UPDATED REQUEST CARD WIDGET - Matching Verification Dashboard style
  Widget _buildRequestCard(dynamic request, bool isPaid) {
    const Color pastelGreen = Color(0xFFA5D6A7);
    const Color pastelBlue = Color(0xFF90CAF9);
    const Color pastelTeal = Color(0xFF80CBC4);
    const Color pastelOrange = Color(0xFFFFAB91);

    // Calculate payment count and attachment count
    int paymentCount =
        request['payments'] != null ? (request['payments'] as List).length : 0;

    // ✅ ADDED: Calculate attachment count
    int attachmentCount = 0;
    if (request['attachments'] != null && request['attachments'] is List) {
      attachmentCount = (request['attachments'] as List).length;
    }

    bool isReimbursement =
        request['request_type']?.toLowerCase().contains('reimbursement') ??
            false;

    // ✅ FORMATTED DATES USE KAREIN
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First row: Avatar, Employee Name, and Request Type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: request['employee_avatar'] != null
                          ? NetworkImage(request['employee_avatar'])
                          : null,
                      child: request['employee_avatar'] == null
                          ? const Icon(Icons.person, color: Colors.white70)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request['employee_name'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'ID: ${request['employee_id'] ?? 'Unknown'}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Second row: Dates and Amount with payment count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (request['approved_date'] != null)
                      Column(
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
                          ),
                        ],
                      ),
                    if (isPaid && request['payment_date'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
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
                          ),
                        ],
                      ),
                    if (request['submitted_date'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
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
                          ),
                        ],
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${(request['amount'] ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '$paymentCount payment${paymentCount != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    // ✅ ADDED: Show attachment count
                    if (attachmentCount > 0)
                      Text(
                        '$attachmentCount attachment${attachmentCount != 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.blue[300],
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Description preview
            if (request['description'] != null &&
                request['description'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
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

            // Action buttons row - Only show for ready for payment tabs (Reimbursement & Advance)
            if (!isPaid &&
                (_tabController.index == 0 || _tabController.index == 1))
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      print(
                          "Viewing details for payment request: ${request['id']}");
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

            // Status indicator for paid requests (History tab)
            if (isPaid || _tabController.index == 3)
              Row(
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
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDialog() {
    return AlertDialog(
      backgroundColor: Color(0xFF1E1E1E),
      title: Text(
        "Filter Requests",
        style: TextStyle(color: Colors.white),
      ),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Search Employee:",
              style: TextStyle(color: Colors.grey[400]),
            ),
            SizedBox(height: 8),
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: "Search by ID or Name",
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
            SizedBox(height: 16),
            Text(
              "Sort By:",
              style: TextStyle(color: Colors.grey[400]),
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _sortFilter,
              dropdownColor: Color(0xFF2D2D2D),
              style: TextStyle(color: Colors.white),
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
                DropdownMenuItem(value: 'Latest', child: Text('Latest First')),
                DropdownMenuItem(value: 'Oldest', child: Text('Oldest First')),
              ],
              onChanged: (value) {
                setState(() {
                  _sortFilter = value!;
                });
              },
            ),
            SizedBox(height: 16),
            Text(
              "Amount Filter:",
              style: TextStyle(color: Colors.grey[400]),
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _amountFilter,
              dropdownColor: Color(0xFF2D2D2D),
              style: TextStyle(color: Colors.white),
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
                DropdownMenuItem(value: 'All', child: Text('All Amounts')),
                DropdownMenuItem(
                    value: 'Above 2000', child: Text('Above ₹2000')),
                DropdownMenuItem(
                    value: 'Below 2000', child: Text('Below ₹2000')),
              ],
              onChanged: (value) {
                setState(() {
                  _amountFilter = value!;
                });
              },
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
          child: Text(
            "Reset",
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Apply"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
        ),
      ],
    );
  }

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
      padding: EdgeInsets.all(16),
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
          SizedBox(height: 20),

          // UPDATED: Top 4 Insight Cards
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  "Ready for Payment",
                  _readyForPayment.length.toString(),
                  Icons.payment,
                  Colors.orange,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  "Paid Requests (Monthly)",
                  _getMonthlyPaidRequests().toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  "Total Amount Ready",
                  "₹${_calculateTotalAmount(_readyForPayment)}",
                  Icons.attach_money,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  "Total Amount Paid (Monthly)",
                  "₹${_getMonthlyPaidAmount().toStringAsFixed(2)}",
                  Icons.currency_rupee,
                  Colors.purple,
                ),
              ),
            ],
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

          // NEW: Report Generation Section
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
                        "Generate Report",
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
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text(
                            "By Employee",
                            style: TextStyle(color: Colors.white, fontSize: 14),
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
                            style: TextStyle(color: Colors.white, fontSize: 14),
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
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Quick Actions
          Card(
            color: Color(0xFF2D2D2D),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flash_on, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        "Quick Actions",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: Icon(Icons.refresh, size: 16),
                        label: Text("Refresh Data"),
                        onPressed: _loadAllData,
                        backgroundColor: Colors.blue[800],
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.analytics, size: 16),
                        label: Text("View Analytics"),
                        onPressed: () {
                          // TODO: Add analytics navigation
                        },
                        backgroundColor: Colors.purple[800],
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                    ],
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
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

  Widget _buildTabContent(String tabType, String tabName) {
    List<dynamic> requests = [];
    bool isPaid = false;

    // Determine which data to show based on tab
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
                Text(
                  "Filters applied",
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _amountFilter = 'All';
                    });
                  },
                  child: Text(
                    "Clear",
                    style: TextStyle(color: Colors.blue),
                  ),
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
                      Icon(
                        _getTabIcon(tabType),
                        color: Colors.grey[600],
                        size: 64,
                      ),
                      SizedBox(height: 16),
                      Text(
                        _getEmptyStateText(tabType, tabName),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                      if (_searchQuery.isNotEmpty || _amountFilter != 'All')
                        Text(
                          "Try adjusting your filters",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    return _buildRequestCard(
                      filteredRequests[index],
                      isPaid,
                    );
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
        title: Text(
          "Finance Payment",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Color.fromARGB(255, 12, 15, 49),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => _buildFilterDialog(),
              );
            },
            tooltip: "Filter Requests",
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: "Refresh Data",
          ),
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: Color(0xFF0D47A1),
              backgroundImage: widget.userData['avatar'] != null
                  ? NetworkImage(widget.userData['avatar'])
                  : null,
              child: widget.userData['avatar'] == null
                  ? Icon(Icons.person, color: Colors.white)
                  : null,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.0),
          child: Container(
            color: Color.fromARGB(255, 12, 15, 49),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[400],
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorWeight: 3.0,
                  indicatorPadding: EdgeInsets.symmetric(horizontal: 8),
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  isScrollable: false,
                  tabs: [
                    Tab(
                      icon: Icon(Icons.receipt, size: 20),
                      text: "Reimbursement",
                    ),
                    Tab(
                      icon: Icon(Icons.forward, size: 20),
                      text: "Advance",
                    ),
                    Tab(
                      icon: Icon(Icons.analytics, size: 20),
                      text: "Insights",
                    ),
                    Tab(
                      icon: Icon(Icons.history, size: 20),
                      text: "History",
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Reimbursement Tab
                    _buildTabContent('reimbursement', 'Reimbursement'),

                    // Advance Tab
                    _buildTabContent('advance', 'Advance'),

                    // Insights Tab
                    _buildInsightsTab(),

                    // History Tab
                    _buildTabContent('history', 'History'),
                  ],
                ),
    );
  }
}
