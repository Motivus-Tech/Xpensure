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

class FinanceVerificationDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String authToken;

  const FinanceVerificationDashboard({
    Key? key,
    required this.userData,
    required this.authToken,
  }) : super(key: key);

  @override
  State<FinanceVerificationDashboard> createState() =>
      _FinanceVerificationDashboardState();
}

class _FinanceVerificationDashboardState
    extends State<FinanceVerificationDashboard>
    with SingleTickerProviderStateMixin {
  List<dynamic> _pendingRequests = [];
  List<dynamic> _verifiedRequests = [];
  List<dynamic> _reimbursementRequests = [];
  List<dynamic> _advanceRequests = [];
  bool _isLoading = true;
  String _errorMessage = '';
  late TabController _tabController;

  // Filter variables
  String _searchQuery = '';
  String _dateFilter = 'All';
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

    // Auto-refresh every 30 seconds for real-time updates
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    Future.delayed(Duration(seconds: 30), () {
      if (mounted) {
        _loadAllData();
        _startAutoRefresh();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ALL DATA LOADING WITH REAL-TIME APIS
  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadPendingVerifications(),
        _loadVerifiedHistory(),
        _loadVerificationInsights(),
      ]);
    } catch (e) {
      print("Error loading all data: $e");
      setState(() {
        _errorMessage = "Failed to load data: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Pending requests loading
  Future<void> _loadPendingVerifications() async {
    try {
      final response = await http.get(
        Uri.parse("http://10.0.2.2:8000/api/finance-verification/dashboard/"),
        headers: {
          "Authorization": "Token ${widget.authToken}",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _pendingRequests = data['pending_verification'] ?? [];

            // Sort by latest first
            _pendingRequests.sort((a, b) {
              final dateA =
                  DateTime.tryParse(a['submitted_date'] ?? '') ?? DateTime(0);
              final dateB =
                  DateTime.tryParse(b['submitted_date'] ?? '') ?? DateTime(0);
              return dateB.compareTo(dateA);
            });

            _reimbursementRequests = _pendingRequests
                .where((request) =>
                    request['request_type']
                        ?.toLowerCase()
                        .contains('reimbursement') ??
                    false)
                .toList();
            _advanceRequests = _pendingRequests
                .where((request) =>
                    request['request_type']
                        ?.toLowerCase()
                        .contains('advance') ??
                    false)
                .toList();
          });
        }
      } else {
        print("Failed to load pending verifications: ${response.statusCode}");
        setState(() {
          _errorMessage = "Failed to load pending requests";
        });
      }
    } catch (e) {
      print("Error loading pending verifications: $e");
      setState(() {
        _errorMessage = "Error loading requests: $e";
      });
    }
  }

  // LOAD VERIFIED HISTORY FOR HISTORY TAB
  Future<void> _loadVerifiedHistory() async {
    try {
      final response = await http.get(
        Uri.parse("http://10.0.2.2:8000/api/finance-verification/history/"),
        headers: {
          "Authorization": "Token ${widget.authToken}",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _verifiedRequests = data['verified_requests'] ?? [];

            // Sort by verification date (newest first)
            _verifiedRequests.sort((a, b) {
              final dateA = DateTime.tryParse(
                      a['verification_date'] ?? a['updated_at'] ?? '') ??
                  DateTime(0);
              final dateB = DateTime.tryParse(
                      b['verification_date'] ?? b['updated_at'] ?? '') ??
                  DateTime(0);
              return dateB.compareTo(dateA);
            });
          });
        }
      } else {
        print("History API not available, status: ${response.statusCode}");
        if (mounted) {
          setState(() {
            _verifiedRequests = [];
          });
        }
      }
    } catch (e) {
      print("Error loading verification history: $e");
      if (mounted) {
        setState(() {
          _verifiedRequests = [];
        });
      }
    }
  }

  // PROPER INSIGHTS WITH REAL-TIME DATA
  Future<void> _loadVerificationInsights() async {
    try {
      final response = await http.get(
        Uri.parse("http://10.0.2.2:8000/api/finance-verification/insights/"),
        headers: {
          "Authorization": "Token ${widget.authToken}",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _insightsData = data;
          });
        }
      } else {
        print("Insights API failed: ${response.statusCode}");
        _calculateLocalInsights();
      }
    } catch (e) {
      print("Error loading verification insights: $e");
      _calculateLocalInsights();
    }
  }

  // IMPROVED LOCAL INSIGHTS CALCULATION
  void _calculateLocalInsights() {
    try {
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      // Monthly pending (current month submissions)
      int monthlyPending = _pendingRequests.where((request) {
        final submittedDate =
            DateTime.tryParse(request['submitted_date'] ?? '');
        return submittedDate != null &&
            submittedDate.isAfter(firstDayOfMonth) &&
            submittedDate.isBefore(now.add(Duration(days: 1)));
      }).length;

      // Monthly amount (current month)
      double monthlyAmount = 0;
      for (var request in _pendingRequests) {
        final submittedDate =
            DateTime.tryParse(request['submitted_date'] ?? '');
        if (submittedDate != null &&
            submittedDate.isAfter(firstDayOfMonth) &&
            submittedDate.isBefore(now.add(Duration(days: 1)))) {
          monthlyAmount += (request['amount'] ?? 0).toDouble();
        }
      }

      // Monthly verified (from history)
      int monthlyVerified = _verifiedRequests.where((request) {
        final verificationDate = DateTime.tryParse(
            request['verification_date'] ??
                request['updated_at'] ??
                request['submitted_date'] ??
                '');
        return verificationDate != null &&
            verificationDate.isAfter(firstDayOfMonth) &&
            verificationDate.isBefore(now.add(Duration(days: 1)));
      }).length;

      // Verified amount (current month)
      double monthlyVerifiedAmount = 0;
      for (var request in _verifiedRequests) {
        final verificationDate = DateTime.tryParse(
            request['verification_date'] ??
                request['updated_at'] ??
                request['submitted_date'] ??
                '');
        if (verificationDate != null &&
            verificationDate.isAfter(firstDayOfMonth) &&
            verificationDate.isBefore(now.add(Duration(days: 1)))) {
          monthlyVerifiedAmount += (request['amount'] ?? 0).toDouble();
        }
      }

      if (mounted) {
        setState(() {
          _insightsData = {
            'monthly_pending': monthlyPending,
            'monthly_amount': monthlyAmount,
            'monthly_verified': monthlyVerified,
            'monthly_verified_amount': monthlyVerifiedAmount,
            'total_pending': _pendingRequests.length,
            'total_verified': _verifiedRequests.length,
            'reimbursement_count': _reimbursementRequests.length,
            'advance_count': _advanceRequests.length,
            'avg_processing_time': _calculateAverageProcessingTime(),
            'total_pending_amount': _calculateTotalAmount(_pendingRequests),
            'total_verified_amount': _calculateTotalAmount(_verifiedRequests),
            'success_rate': _calculateSuccessRate(),
            'source': 'local_fallback',
          };
        });
      }
    } catch (e) {
      print("Error in local insights calculation: $e");
    }
  }

  // AVERAGE PROCESSING TIME CALCULATION
  double _calculateAverageProcessingTime() {
    if (_verifiedRequests.isEmpty) return 0.0;

    double totalHours = 0;
    int count = 0;

    for (var request in _verifiedRequests) {
      final submittedDate = DateTime.tryParse(request['submitted_date'] ?? '');
      final verificationDate = DateTime.tryParse(request['verification_date'] ??
          request['updated_at'] ??
          request['submitted_date'] ??
          '');

      if (submittedDate != null && verificationDate != null) {
        final difference = verificationDate.difference(submittedDate);
        totalHours += difference.inHours.toDouble();
        count++;
      }
    }

    return count > 0 ? totalHours / count : 0.0;
  }

  // APPROVE REQUEST WITH REAL-TIME UPDATE
  Future<void> _approveRequest(int requestId, String requestType) async {
    try {
      final response = await http.post(
        Uri.parse("http://10.0.2.2:8000/api/finance-verification/approve/"),
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
            content: Text("✅ Request approved and sent to CEO"),
            backgroundColor: Colors.green[800],
          ),
        );
        await _loadAllData();
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "❌ Failed to approve: ${errorData['error'] ?? 'Unknown error'}"),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error: $e"),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  // REJECT REQUEST WITH REAL-TIME UPDATE
  Future<void> _rejectRequest(int requestId, String requestType) async {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text("Reject Request", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: "Reason for rejection",
            labelStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(),
            focusedBorder:
                OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
            enabledBorder:
                OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
          ),
          style: TextStyle(color: Colors.white),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Please provide a reason"),
                    backgroundColor: Colors.orange[800],
                  ),
                );
                return;
              }

              Navigator.pop(context);

              try {
                final response = await http.post(
                  Uri.parse(
                      "http://10.0.2.2:8000/api/finance-verification/reject/"),
                  headers: {
                    "Authorization": "Token ${widget.authToken}",
                    "Content-Type": "application/json",
                  },
                  body: jsonEncode({
                    'request_id': requestId,
                    'request_type': requestType,
                    'reason': reasonController.text,
                  }),
                );

                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("✅ Request rejected"),
                      backgroundColor: Colors.red[800],
                    ),
                  );
                  await _loadAllData();
                } else {
                  final errorData = jsonDecode(response.body);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          "❌ Failed to reject: ${errorData['error'] ?? 'Unknown error'}"),
                      backgroundColor: Colors.red[800],
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("❌ Error: $e"),
                    backgroundColor: Colors.red[800],
                  ),
                );
              }
            },
            child: Text("Reject"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
          ),
        ],
      ),
    );
  }

  // BETTER AVATAR DISPLAY WIDGET
  Widget _buildAvatar(String? avatarUrl,
      {double radius = 16, bool isAppBar = false}) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
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

  // CONVERT TO FINANCE REQUEST WITH ALL DATE FIELDS
  FinanceRequest _convertToFinanceRequest(dynamic requestData) {
    List<dynamic> payments = [];
    List<dynamic> mainAttachments = [];

    // Handle payments field
    if (requestData['payments'] != null) {
      if (requestData['payments'] is String) {
        try {
          payments = jsonDecode(requestData['payments']);
        } catch (e) {
          print("❌ Failed to parse payments JSON: $e");
        }
      } else if (requestData['payments'] is List) {
        payments = requestData['payments'];
      }
    }

    // Handle attachments
    if (requestData['attachments'] != null) {
      if (requestData['attachments'] is List) {
        mainAttachments = requestData['attachments'];
      } else if (requestData['attachments'] is String) {
        try {
          mainAttachments = jsonDecode(requestData['attachments']);
        } catch (e) {
          mainAttachments = [requestData['attachments']];
        }
      }
    }

    // If payments is still empty, create from main request data
    if (payments.isEmpty) {
      Map<String, dynamic> mainPayment = {
        'amount': requestData['amount'] ?? 0,
        'description': requestData['description'] ?? '',
        'date': requestData['submitted_date'] ?? requestData['date'] ?? '',
        'claimType': requestData['claim_type'] ?? '',
        'attachmentPaths': mainAttachments,
      };
      payments.add(mainPayment);
    }

    FinanceRequest financeRequest = FinanceRequest(
      id: requestData['id'] ?? 0,
      employeeId: requestData['employee_id']?.toString() ?? 'Unknown',
      employeeName: requestData['employee_name']?.toString() ?? 'Unknown',
      avatarUrl: requestData['employee_avatar'],
      submissionDate: requestData['submitted_date']?.toString() ?? 'Unknown',
      amount: (requestData['amount'] ?? 0).toDouble(),
      description: requestData['description']?.toString() ?? '',
      payments: payments,
      attachments: mainAttachments,
      requestType: requestData['request_type']?.toString() ?? 'Unknown',
      status: requestData['status'] ?? 'pending',
      approvedBy: requestData['approved_by'],
      approvalDate: requestData['approval_date'],
      projectId: requestData['project_id'] ?? requestData['projectId'],
      projectName: requestData['project_name'] ?? requestData['projectName'],
      reimbursementDate: requestData['reimbursement_date']?.toString(),
      requestDate: requestData['request_date']?.toString(),
      projectDate: requestData['project_date']?.toString(),
      paymentDate: requestData['payment_date']?.toString(),
    );

    return financeRequest;
  }

  // HISTORY REQUEST CARD
  Widget _buildHistoryCard(dynamic request) {
    bool isApproved = request['status']?.toLowerCase() == 'approved' ||
        request['verification_status']?.toLowerCase() == 'approved' ||
        (request['rejection_reason'] == null ||
            request['rejection_reason'].toString().isEmpty);

    String verificationDate = DateFormatter.formatBackendDate(
        request['verification_date'] ??
            request['updated_at'] ??
            request['submitted_date']);

    return Card(
      color: Color(0xFF1E1E1E),
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Employee Info
            Row(
              children: [
                _buildAvatar(request['employee_avatar'], radius: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['employee_name'] ?? 'Unknown Employee',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'ID: ${request['employee_id'] ?? 'Unknown'}',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isApproved ? Colors.green[800] : Colors.red[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isApproved ? 'Approved' : 'Rejected',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 10),

            // Dates and Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submitted',
                      style: TextStyle(color: Colors.green[300], fontSize: 11),
                    ),
                    Text(
                      DateFormatter.formatBackendDate(
                          request['submitted_date']),
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Verified',
                      style: TextStyle(color: Colors.blue[300], fontSize: 11),
                    ),
                    Text(
                      verificationDate,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${(request['amount'] ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      request['request_type'] ?? 'Unknown',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),

            // Rejection Reason (if rejected)
            if (!isApproved && request['rejection_reason'] != null)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "Reason: ${request['rejection_reason']}",
                  style: TextStyle(color: Colors.red[300], fontSize: 12),
                ),
              ),

            SizedBox(height: 12),

            // View Details Button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FinanceRequestDetails(
                        request: _convertToFinanceRequest(request),
                        authToken: widget.authToken,
                        isPaymentTab: false,
                      ),
                    ),
                  );
                },
                child: Text(
                  'View Details',
                  style: TextStyle(color: Color(0xFF80CBC4)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // REQUEST CARD FOR PENDING REQUESTS
  Widget _buildRequestCard(dynamic request) {
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
              // Avatar row with better layout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
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
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Submitted',
                                style: TextStyle(
                                  color: Colors.green[300],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                formattedSubmittedDate,
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
                        Text(
                          'Pending Verification',
                          style: TextStyle(
                            color: Colors.orange[300],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
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
                            isPaymentTab: false,
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
                    onPressed: () => _approveRequest(
                      request['id'],
                      request['request_type'],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pastelTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Approve'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _rejectRequest(
                      request['id'],
                      request['request_type'],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pastelOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // BUILD TAB CONTENT WITH HISTORY SUPPORT
  Widget _buildTabContent(String tabType, String tabName) {
    List<dynamic> requests = [];

    if (tabType == 'reimbursement') {
      requests = _reimbursementRequests;
    } else if (tabType == 'advance') {
      requests = _advanceRequests;
    } else if (tabType == 'history') {
      requests = _verifiedRequests;
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
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    return tabType == 'history'
                        ? _buildHistoryCard(filteredRequests[index])
                        : _buildRequestCard(filteredRequests[index]);
                  },
                ),
        ),
      ],
    );
  }

  // EMPTY STATE TEXTS
  String _getEmptyStateText(String tabType, String tabName) {
    switch (tabType) {
      case 'reimbursement':
        return "No reimbursement requests pending verification";
      case 'advance':
        return "No advance requests pending verification";
      case 'insights':
        return "Loading insights...";
      case 'history':
        return "No verification history yet";
      default:
        return "No data available";
    }
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
        return Icons.verified;
    }
  }

  // INSIGHTS TAB WITH REAL-TIME DATA
  Widget _buildInsightsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Real-time Verification Insights",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 15),

          // Real-time Insight Cards
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 6,
            childAspectRatio: 0.8,
            children: [
              _buildInsightCard(
                "Pending Verification",
                _pendingRequests.length.toString(),
                Icons.pending_actions,
                Colors.orange,
              ),
              _buildInsightCard(
                "Monthly Pending",
                (_insightsData['monthly_pending']?.toString() ?? '0'),
                Icons.calendar_today,
                Colors.blue,
              ),
              _buildInsightCard(
                "Monthly Verified",
                (_insightsData['monthly_verified']?.toString() ?? '0'),
                Icons.verified,
                Colors.green,
              ),
              _buildInsightCard(
                "Avg Processing Time",
                "${(_insightsData['avg_processing_time']?.toStringAsFixed(1) ?? '0')}h",
                Icons.timer,
                Colors.purple,
              ),
            ],
          ),

          SizedBox(height: 24),

          // Financial Summary
          Card(
            color: Color(0xFF2D2D2D),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.currency_rupee, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        "Financial Summary",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildStatItem("Total Pending Amount",
                      "₹${_calculateTotalAmount(_pendingRequests)}"),
                  _buildStatItem("Monthly Pending Amount",
                      "₹${(_insightsData['monthly_amount']?.toStringAsFixed(2) ?? '0.00')}"),
                  _buildStatItem("Monthly Verified Amount",
                      "₹${(_insightsData['monthly_verified_amount']?.toStringAsFixed(2) ?? '0.00')}"),
                  _buildStatItem("Average Request Amount",
                      "₹${_calculateAverageAmount()}"),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Verification Statistics
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
                        "Verification Overview",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildStatItem("Reimbursements Pending",
                      _reimbursementRequests.length.toString()),
                  _buildStatItem(
                      "Advances Pending", _advanceRequests.length.toString()),
                  _buildStatItem("Total Verified Requests",
                      _verifiedRequests.length.toString()),
                  _buildStatItem("Success Rate", "${_calculateSuccessRate()}%"),
                ],
              ),
            ),
          ),

          // Report Generation Section
          SizedBox(height: 16),
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

                  // Employee-Project Verification Report Section
                  SizedBox(height: 24),
                  Divider(color: Colors.grey[700]),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.people, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        "Employee-Project Verification Report",
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
                                Text("Generate Verification Report"),
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

  String _calculateAverageAmount() {
    if (_pendingRequests.isEmpty) return "0.00";
    double total = 0;
    for (var request in _pendingRequests) {
      total += (request['amount'] ?? 0).toDouble();
    }
    return (total / _pendingRequests.length).toStringAsFixed(2);
  }

  String _calculateSuccessRate() {
    if (_verifiedRequests.isEmpty) return "0";
    int approvedCount = _verifiedRequests.where((request) {
      return request['status']?.toLowerCase() == 'approved' ||
          request['verification_status']?.toLowerCase() == 'approved' ||
          (request['rejection_reason'] == null ||
              request['rejection_reason'].toString().isEmpty);
    }).length;

    return ((approvedCount / _verifiedRequests.length) * 100)
        .toStringAsFixed(1);
  }

  List<dynamic> _getFilteredRequests(List<dynamic> requests, String tabType) {
    List<dynamic> filtered = List.from(requests);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((request) {
        final employeeId =
            request['employee_id']?.toString().toLowerCase() ?? '';
        final employeeName =
            request['employee_name']?.toString().toLowerCase() ?? '';
        final projectName =
            request['project_name']?.toString().toLowerCase() ?? '';
        return employeeId.contains(_searchQuery.toLowerCase()) ||
            employeeName.contains(_searchQuery.toLowerCase()) ||
            projectName.contains(_searchQuery.toLowerCase());
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
            DateTime.tryParse(a['submitted_date'] ?? '') ?? DateTime(0);
        final dateB =
            DateTime.tryParse(b['submitted_date'] ?? '') ?? DateTime(0);
        return dateB.compareTo(dateA);
      });
    } else if (_sortFilter == 'Oldest') {
      filtered.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['submitted_date'] ?? '') ?? DateTime(0);
        final dateB =
            DateTime.tryParse(b['submitted_date'] ?? '') ?? DateTime(0);
        return dateA.compareTo(dateB);
      });
    }

    return filtered;
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

  // FIXED: REPORT GENERATION FUNCTION FOR VERIFICATION
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
      print("🔄 Generating finance verification report...");

      // Try to use backend API first
      final response = await http.get(
        Uri.parse("http://10.0.2.2:8000/api/finance-verification/csv-report/")
            .replace(queryParameters: {
          'report_type': _reportType,
          'period': _reportPeriod,
          'identifier': _reportIdentifier,
        }),
        headers: {
          "Authorization": "Token ${widget.authToken}",
        },
      );

      if (response.statusCode == 200) {
        // Save and share CSV file from backend
        final directory = await getTemporaryDirectory();
        final file = File(
            '${directory.path}/finance_verification_report_${DateTime.now().millisecondsSinceEpoch}.csv');
        await file.writeAsBytes(response.bodyBytes);

        await Share.shareXFiles([XFile(file.path)],
            text:
                'Finance Verification Report - ${_reportType == 'employee' ? 'Employee: $_reportIdentifier' : 'Project: $_reportIdentifier'}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ CSV report generated successfully"),
            backgroundColor: Colors.green[800],
          ),
        );
      } else {
        // Fallback to local generation if API fails
        print("⚠️ CSV API failed, falling back to local generation");
        await _generateLocalReport();
      }
    } catch (e) {
      print("❌ Error generating report via API: $e");
      // Fallback to local generation
      await _generateLocalReport();
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingReport = false;
        });
      }
    }
  }

  // FIXED: LOCAL REPORT GENERATION FALLBACK
  Future<void> _generateLocalReport() async {
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
          startDate = DateTime(2000);
          break;
        default:
          startDate = DateTime(now.year, now.month - 1, now.day);
      }

      // Filter data based on report type and period
      List<dynamic> reportData = [];

      if (_reportType == 'employee') {
        reportData = _pendingRequests.where((request) {
          final employeeId = request['employee_id']?.toString() ?? '';
          final submittedDate =
              DateTime.tryParse(request['submitted_date'] ?? '');
          return employeeId.contains(_reportIdentifier) &&
              submittedDate != null &&
              submittedDate.isAfter(startDate);
        }).toList();
      } else {
        reportData = _pendingRequests.where((request) {
          final projectId = request['project_id']?.toString() ?? '';
          final projectName = request['project_name']?.toString() ?? '';
          final submittedDate =
              DateTime.tryParse(request['submitted_date'] ?? '');
          return (projectId.contains(_reportIdentifier) ||
                  projectName
                      .toLowerCase()
                      .contains(_reportIdentifier.toLowerCase())) &&
              submittedDate != null &&
              submittedDate.isAfter(startDate);
        }).toList();
      }

      if (reportData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No data found for the specified criteria"),
            backgroundColor: Colors.orange[800],
          ),
        );
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
        'Submitted Date',
        'Project ID',
        'Project Name',
        'Status',
        'Current Approver'
      ]);

      // Add rows
      for (var request in reportData) {
        csvData.add([
          request['id'] ?? '',
          request['employee_id'] ?? '',
          request['employee_name'] ?? '',
          request['request_type'] ?? '',
          '₹${(request['amount'] ?? 0).toStringAsFixed(2)}',
          request['description'] ?? '',
          request['submitted_date'] ?? '',
          request['project_id'] ?? '',
          request['project_name'] ?? '',
          'Pending Verification',
          request['current_approver_id'] ?? ''
        ]);
      }

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(csvData);

      // Save file
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/verification_report_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(filePath);
      await file.writeAsString(csv);

      print("✅ Local CSV file created at: $filePath");
      print("✅ Report contains ${reportData.length} records");

      // Share file
      await Share.shareXFiles([XFile(filePath)],
          text:
              'Finance Verification Report - ${_reportType == 'employee' ? 'Employee: $_reportIdentifier' : 'Project: $_reportIdentifier'}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Report generated successfully with ${reportData.length} records"),
          backgroundColor: Colors.green[800],
        ),
      );
    } catch (e) {
      print("❌ Error in local report generation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error generating report: ${e.toString()}"),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  // FIXED: EMPLOYEE-PROJECT VERIFICATION REPORT
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
      print("🔄 Fetching employee-project verification data...");

      // Use the correct endpoint for finance verification
      final response = await http.get(
        Uri.parse("http://10.0.2.2:8000/api/employee-project-report/")
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
        print("✅ Employee-Project Verification API response received");

        // Get all requests (pending + verified)
        final allRequests = (data['requests'] as List?) ?? [];

        if (allRequests.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("No requests found for:\n"
                  "Employee: ${_employeeIdForProjectReport}\n"
                  "Project: ${_projectIdForEmployeeReport}"),
              backgroundColor: Colors.orange[800],
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }

        // Separate pending and verified requests
        final pendingRequests = allRequests.where((request) {
          final status = request['status']?.toString().toLowerCase() ?? '';
          return status == 'pending';
        }).toList();

        final verifiedRequests = allRequests.where((request) {
          final status = request['status']?.toString().toLowerCase() ?? '';
          return status != 'pending';
        }).toList();

        // Calculate totals
        double totalPendingAmount = 0;
        double totalVerifiedAmount = 0;

        for (var request in pendingRequests) {
          totalPendingAmount += (request['amount'] ?? 0).toDouble();
        }

        for (var request in verifiedRequests) {
          totalVerifiedAmount += (request['amount'] ?? 0).toDouble();
        }

        int reimbursementCount = allRequests.where((request) {
          return request['request_type']
                  ?.toString()
                  .toLowerCase()
                  .contains('reimbursement') ??
              false;
        }).length;

        int advanceCount = allRequests.where((request) {
          return request['request_type']
                  ?.toString()
                  .toLowerCase()
                  .contains('advance') ??
              false;
        }).length;

        // Create comprehensive CSV report
        List<List<dynamic>> csvData = [];

        // Add summary header
        csvData.add(['FINANCE VERIFICATION - EMPLOYEE PROJECT REPORT']);
        csvData.add(['Generated on', DateTime.now().toString().split(' ')[0]]);
        csvData.add([
          'Employee ID',
          data['employee_id'] ?? _employeeIdForProjectReport
        ]);
        csvData.add(['Employee Name', data['employee_name'] ?? 'Unknown']);
        csvData.add([
          'Project Identifier',
          data['project_identifier'] ?? _projectIdForEmployeeReport
        ]);
        csvData.add(
            ['Report Period', _employeeProjectPeriod.replaceAll('_', ' ')]);
        csvData.add([]);

        // Add verification summary
        csvData.add(['VERIFICATION OVERVIEW']);
        csvData.add(['Total Requests', allRequests.length]);
        csvData.add(['Pending Verification', pendingRequests.length]);
        csvData.add(['Verified/Processed', verifiedRequests.length]);
        csvData.add(['Reimbursement Requests', reimbursementCount]);
        csvData.add(['Advance Requests', advanceCount]);
        csvData.add([
          'Total Pending Amount',
          '₹${totalPendingAmount.toStringAsFixed(2)}'
        ]);
        csvData.add([
          'Total Verified Amount',
          '₹${totalVerifiedAmount.toStringAsFixed(2)}'
        ]);
        csvData.add([
          'Total Amount',
          '₹${(totalPendingAmount + totalVerifiedAmount).toStringAsFixed(2)}'
        ]);
        csvData.add([]);

        // Add detailed transactions
        csvData.add(['DETAILED REQUEST RECORDS']);
        csvData.add([
          'Request ID',
          'Type',
          'Amount',
          'Status',
          'Finance Action',
          'Submitted Date',
          'Verified Date',
          'Description',
          'Project ID',
          'Project Name'
        ]);

        for (var request in allRequests) {
          csvData.add([
            request['id'] ?? '',
            request['request_type'] ?? '',
            '₹${(request['amount'] ?? 0).toStringAsFixed(2)}',
            request['status'] ?? '',
            request['finance_action'] ?? 'pending',
            request['submitted_date'] ?? '',
            request['verification_date'] ?? '',
            request['description'] ?? '',
            request['project_id'] ?? '',
            request['project_name'] ?? '',
          ]);
        }

        // Convert to CSV
        String csv = const ListToCsvConverter().convert(csvData);

        // Save file
        final directory = await getTemporaryDirectory();
        final filePath =
            '${directory.path}/employee_project_verification_${_employeeIdForProjectReport}_${DateTime.now().millisecondsSinceEpoch}.csv';
        final file = File(filePath);
        await file.writeAsString(csv);

        print("✅ Employee-Project Verification CSV created: $filePath");
        print("✅ Report contains ${allRequests.length} total requests");

        // Share file
        await Share.shareXFiles([XFile(filePath)],
            text: 'Finance Verification - Employee Project Report\n\n'
                '👤 Employee: ${data['employee_name'] ?? _employeeIdForProjectReport}\n'
                '📁 Project: ${data['project_identifier'] ?? _projectIdForEmployeeReport}\n'
                '📊 Total Requests: ${allRequests.length}\n'
                '⏳ Pending: ${pendingRequests.length} | ✅ Verified: ${verifiedRequests.length}\n'
                '💰 Pending Amount: ₹${totalPendingAmount.toStringAsFixed(2)}\n'
                '💰 Verified Amount: ₹${totalVerifiedAmount.toStringAsFixed(2)}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Employee-Project verification report generated!"),
                SizedBox(height: 4),
                Text("Total Requests: ${allRequests.length}"),
                Text(
                    "Pending: ${pendingRequests.length} | Verified: ${verifiedRequests.length}"),
                Text(
                    "Total Amount: ₹${(totalPendingAmount + totalVerifiedAmount).toStringAsFixed(2)}"),
              ],
            ),
            backgroundColor: Colors.green[800],
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Failed to load data: ${errorData['error'] ?? 'Unknown error (${response.statusCode})'}');
      }
    } catch (e) {
      print("❌ Error generating employee-project verification report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error generating report: ${e.toString()}"),
          backgroundColor: Colors.red[800],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingEmployeeProjectReport = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: Text("Finance Verification",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        backgroundColor: Color.fromARGB(255, 12, 15, 49),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
              icon: Icon(Icons.filter_list),
              onPressed: () => showDialog(
                  context: context, builder: (context) => _buildFilterDialog()),
              tooltip: "Filter Requests"),
          IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadAllData,
              tooltip: "Refresh Data"),
          Padding(
            padding: EdgeInsets.only(right: 16),
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
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[400],
                  labelStyle:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  unselectedLabelStyle:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorWeight: 3.0,
                  indicatorPadding: EdgeInsets.symmetric(horizontal: 8),
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  isScrollable: false,
                  tabs: [
                    Tab(
                        icon: Icon(Icons.receipt, size: 20),
                        text: "Reimbursement"),
                    Tab(icon: Icon(Icons.forward, size: 20), text: "Advance"),
                    Tab(
                        icon: Icon(Icons.analytics, size: 20),
                        text: "Insights"),
                    Tab(icon: Icon(Icons.history, size: 20), text: "History"),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 64),
                      SizedBox(height: 16),
                      Text(_errorMessage,
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAllData,
                        child: Text("Retry"),
                      ),
                    ],
                  ),
                )
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
