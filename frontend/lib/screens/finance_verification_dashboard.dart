import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'finance_request_details.dart';
import '../models/finance_request.dart';
import '../utils/date_formatter.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await _loadPendingVerifications();
    await _loadInsights();
  }

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
        print("API Response: ${jsonEncode(data)}");

        setState(() {
          _pendingRequests = data['pending_verification'] ?? [];

          // Debug: Print first request to see what fields we're getting
          if (_pendingRequests.isNotEmpty) {
            print("First request data: ${jsonEncode(_pendingRequests.first)}");
          }

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
                  request['request_type']?.toLowerCase().contains('advance') ??
                  false)
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load data: ${response.statusCode}";
          _isLoading = false;
        });
        print("Error response: ${response.body}");
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
        _isLoading = false;
      });
      print("Exception: $e");
    }
  }

  Future<void> _loadInsights() async {
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
        setState(() {
          _insightsData = data;
        });
      }
    } catch (e) {
      print("Error loading insights: $e");
    }
  }

  // ✅ FIXED: APPROVE REQUEST WITH CORRECT ENDPOINT
  Future<void> _approveRequest(int requestId, String requestType) async {
    try {
      final response = await http.post(
        Uri.parse(
            "http://10.0.2.2:8000/api/finance-verification/approve/"), // ✅ CORRECT ENDPOINT
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
            content: Text("Request approved and sent to CEO"),
            backgroundColor: Colors.green[800],
          ),
        );
        _loadAllData(); // Refresh all data
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Failed to approve request: ${errorData['error'] ?? 'Unknown error'}"),
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

  // ✅ FIXED: REJECT REQUEST WITH CORRECT ENDPOINT
  Future<void> _rejectRequest(int requestId, String requestType) async {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text(
          "Reject Request",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: "Reason for rejection",
            labelStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
          ),
          style: TextStyle(color: Colors.white),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.grey[400]),
            ),
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
                      "http://10.0.2.2:8000/api/finance-verification/reject/"), // ✅ CORRECT ENDPOINT
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
                      content: Text("Request rejected"),
                      backgroundColor: Colors.red[800],
                    ),
                  );
                  _loadAllData();
                } else {
                  final errorData = jsonDecode(response.body);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          "Failed to reject request: ${errorData['error'] ?? 'Unknown error'}"),
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
            },
            child: Text("Reject"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
          ),
        ],
      ),
    );
  }

  List<dynamic> _getFilteredRequests(List<dynamic> requests) {
    List<dynamic> filtered = List.from(requests);

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

  // ✅ FIXED: CONVERT TO FINANCE REQUEST WITH ALL DATE FIELDS
  FinanceRequest _convertToFinanceRequest(dynamic requestData) {
    print("=== Converting Request Data ===");
    print("Request ID: ${requestData['id']}");
    print("Request Type: ${requestData['request_type']}");
    print("Full request data: ${jsonEncode(requestData)}");

    List<dynamic> payments = [];
    List<dynamic> mainAttachments = [];

    // DEBUG: Check payments field properly
    print("🔍 Checking payments field...");
    if (requestData['payments'] != null) {
      print("Payments field exists: ${requestData['payments']}");
      print("Payments field type: ${requestData['payments'].runtimeType}");

      if (requestData['payments'] is String) {
        try {
          payments = jsonDecode(requestData['payments']);
          print("✅ Parsed payments from JSON string: ${payments.length} items");
        } catch (e) {
          print("❌ Failed to parse payments JSON: $e");
        }
      } else if (requestData['payments'] is List) {
        payments = requestData['payments'];
        print("✅ Payments is already a list: ${payments.length} items");
      }
    } else {
      print("❌ No payments field found in request data");
    }

    // Handle attachments
    if (requestData['attachments'] != null) {
      if (requestData['attachments'] is List) {
        mainAttachments = requestData['attachments'];
        print("✅ Found attachments list: ${mainAttachments.length} items");
      } else if (requestData['attachments'] is String) {
        try {
          mainAttachments = jsonDecode(requestData['attachments']);
          print(
              "✅ Parsed attachments from JSON string: ${mainAttachments.length} items");
        } catch (e) {
          mainAttachments = [requestData['attachments']];
          print("✅ Treated attachments as single string");
        }
      }
    }

    // If payments is still empty, create from main request data
    if (payments.isEmpty) {
      print("🔄 Creating payment from main request data...");

      Map<String, dynamic> mainPayment = {
        'amount': requestData['amount'] ?? 0,
        'description': requestData['description'] ?? '',
        'date': requestData['submitted_date'] ?? requestData['date'] ?? '',
        'claimType': requestData['claim_type'] ?? '',
        'attachmentPaths': mainAttachments,
      };

      payments.add(mainPayment);
      print(
          "✅ Created synthetic payment with ${mainAttachments.length} attachments");
    }

    // ✅ CRITICAL FIX: EXTRACT ALL DATE FIELDS PROPERLY
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
      // ✅ FIXED: PROPERLY EXTRACT ALL DATE FIELDS
      reimbursementDate: requestData['reimbursement_date']?.toString(),
      requestDate: requestData['request_date']?.toString(),
      projectDate: requestData['project_date']?.toString(),
      paymentDate:
          requestData['payment_date']?.toString(), // ✅ ADD PAYMENT DATE
    );

    print("=== Final FinanceRequest ===");
    print("Reimbursement Date: ${financeRequest.reimbursementDate}");
    print("Request Date: ${financeRequest.requestDate}");
    print("Project Date: ${financeRequest.projectDate}");
    print("Payment Date: ${financeRequest.paymentDate}");

    return financeRequest;
  }

  // UPDATED REQUEST CARD WIDGET - Matching CommonDashboard style
  Widget _buildRequestCard(dynamic request) {
    const Color pastelTeal = Color(0xFF80CBC4);
    const Color pastelOrange = Color(0xFFFFAB91);

    // Calculate payment count
    int paymentCount =
        request['payments'] != null ? (request['payments'] as List).length : 0;
    bool isReimbursement =
        request['request_type']?.toLowerCase().contains('reimbursement') ??
            false;

    // ✅ FORMATTED DATE USE KAREIN
    String formattedDate =
        DateFormatter.formatBackendDate(request['submitted_date']);
    String relativeTime =
        DateFormatter.formatRelativeTime(request['submitted_date']);

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

            // Second row: Submission date and Amount with payment count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    Text(
                      relativeTime,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
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

            // Action buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    print("Viewing details for request: ${request['id']}");
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Financial Insights",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),

          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  "Pending Requests",
                  _pendingRequests.length.toString(),
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  "Reimbursements",
                  _reimbursementRequests.length.toString(),
                  Icons.receipt,
                  Colors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  "Advance Requests",
                  _advanceRequests.length.toString(),
                  Icons.forward,
                  Colors.purple,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  "Total Amount",
                  "₹${_calculateTotalAmount()}",
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Monthly Statistics
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
                        "Monthly Overview",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildStatItem("Approved this month",
                      _insightsData['monthly_approved']?.toString() ?? '0'),
                  _buildStatItem("Rejected this month",
                      _insightsData['monthly_rejected']?.toString() ?? '0'),
                  _buildStatItem("Pending review",
                      _insightsData['monthly_pending']?.toString() ?? '0'),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Amount Distribution
          Card(
            color: Color(0xFF2D2D2D),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pie_chart, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(
                        "Amount Distribution",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildStatItem("Total Reimbursement Amount",
                      "₹${_calculateTypeAmount(_reimbursementRequests)}"),
                  _buildStatItem("Total Advance Amount",
                      "₹${_calculateTypeAmount(_advanceRequests)}"),
                  _buildStatItem("Average Request Amount",
                      "₹${_calculateAverageAmount()}"),
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
                        avatar: Icon(Icons.check_circle, size: 16),
                        label: Text("View All Approved"),
                        onPressed: () {
                          // Navigate to approved requests page
                        },
                        backgroundColor: Colors.green[800],
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.cancel, size: 16),
                        label: Text("View Rejected"),
                        onPressed: () {
                          // Navigate to rejected requests page
                        },
                        backgroundColor: Colors.red[800],
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

  String _calculateTotalAmount() {
    double total = 0;
    for (var request in _pendingRequests) {
      total += (request['amount'] ?? 0).toDouble();
    }
    return total.toStringAsFixed(2);
  }

  String _calculateTypeAmount(List<dynamic> requests) {
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

  @override
  Widget build(BuildContext context) {
    final filteredReimbursements = _getFilteredRequests(_reimbursementRequests);
    final filteredAdvances = _getFilteredRequests(_advanceRequests);

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          "Finance Verification",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Color.fromARGB(255, 12, 15, 49),
        foregroundColor: Colors.white,
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          tabs: [
            Tab(
              icon: Icon(Icons.receipt),
              text: "Reimbursement (${filteredReimbursements.length})",
            ),
            Tab(
              icon: Icon(Icons.forward),
              text: "Advance (${filteredAdvances.length})",
            ),
            Tab(
              icon: Icon(Icons.insights),
              text: "Insights",
            ),
          ],
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
                    Column(
                      children: [
                        if (_searchQuery.isNotEmpty || _amountFilter != 'All')
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.filter_alt,
                                    color: Colors.blue, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  "Filters applied",
                                  style: TextStyle(
                                      color: Colors.grey[400], fontSize: 12),
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
                          child: filteredReimbursements.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.receipt_long,
                                        color: Colors.grey[600],
                                        size: 64,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        "No reimbursement requests",
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 16),
                                      ),
                                      if (_searchQuery.isNotEmpty ||
                                          _amountFilter != 'All')
                                        Text(
                                          "Try adjusting your filters",
                                          style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12),
                                        ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filteredReimbursements.length,
                                  itemBuilder: (context, index) {
                                    return _buildRequestCard(
                                        filteredReimbursements[index]);
                                  },
                                ),
                        ),
                      ],
                    ),

                    // Advance Tab
                    Column(
                      children: [
                        if (_searchQuery.isNotEmpty || _amountFilter != 'All')
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.filter_alt,
                                    color: Colors.blue, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  "Filters applied",
                                  style: TextStyle(
                                      color: Colors.grey[400], fontSize: 12),
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
                          child: filteredAdvances.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.forward,
                                        color: Colors.grey[600],
                                        size: 64,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        "No advance requests",
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 16),
                                      ),
                                      if (_searchQuery.isNotEmpty ||
                                          _amountFilter != 'All')
                                        Text(
                                          "Try adjusting your filters",
                                          style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12),
                                        ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filteredAdvances.length,
                                  itemBuilder: (context, index) {
                                    return _buildRequestCard(
                                        filteredAdvances[index]);
                                  },
                                ),
                        ),
                      ],
                    ),

                    // Insights Tab
                    _buildInsightsTab(),
                  ],
                ),
    );
  }
}
