import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

import 'reimbursement_form.dart';
import 'request_history.dart';
import 'advance_form.dart';
import 'change_password.dart';
import 'edit_profile.dart';
import '../services/api_service.dart'; // ApiService

class Request {
  final int id; // ✅ ADD THIS
  final String type;
  final List<Map<String, dynamic>> payments;
  String status;
  final int currentStep;
  final String? rejectionReason;
  final DateTime requestDate;

  Request({
    required this.id, // ✅ ADD THIS
    required this.type,
    required this.payments,
    this.status = "Pending",
    this.currentStep = 0,
    this.rejectionReason,
    required this.requestDate,
  });
}

class EmployeeDashboard extends StatefulWidget {
  final String employeeName;
  final String employeeId;
  final String email;
  final String mobile;
  final String avatarUrl;
  final String department;
  final String aadhaar;

  const EmployeeDashboard({
    super.key,
    required this.employeeName,
    required this.employeeId,
    required this.email,
    required this.mobile,
    required this.avatarUrl,
    required this.department,
    required this.aadhaar,
  });

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Request> requests = [];
  final ApiService apiService = ApiService();
  String? authToken;
  bool _isLoading = true;

  String? currentAvatarUrl;

  // Filter variables
  String _selectedFilter = "All";
  String _searchQuery = "";
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    currentAvatarUrl = widget.avatarUrl.isNotEmpty
        ? (widget.avatarUrl.startsWith("http")
            ? widget.avatarUrl
            : "http://10.0.2.2:8000${widget.avatarUrl}")
        : null;

    _loadAuthTokenAndRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthTokenAndRequests() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      authToken = prefs.getString('authToken');

      if (authToken != null) {
        dynamic dashboardResponse = await apiService.getPendingApprovals(
          authToken: authToken!,
        );

        // ✅ DEBUG: Check the actual API response
        print("=== RAW API RESPONSE ===");
        print(dashboardResponse.toString());

        List<Map<String, dynamic>> fetchedReimbursements = [];
        List<Map<String, dynamic>> fetchedAdvances = [];

        try {
          if (dashboardResponse is Map &&
              dashboardResponse.containsKey('my_reimbursements')) {
            fetchedReimbursements = List<Map<String, dynamic>>.from(
                dashboardResponse['my_reimbursements']);

            // ✅ DEBUG: Check what's in reimbursements
            print("=== REIMBURSEMENTS FROM API ===");
            for (int i = 0; i < fetchedReimbursements.length; i++) {
              var r = fetchedReimbursements[i];
              print(
                  "Reimbursement $i - projectId: '${r['projectId']}', project_id: '${r['project_id']}'");
            }
          }
        } catch (_) {
          fetchedReimbursements = [];
        }

        try {
          if (dashboardResponse is Map &&
              dashboardResponse.containsKey('my_advances')) {
            fetchedAdvances = List<Map<String, dynamic>>.from(
                dashboardResponse['my_advances']);

            // ✅ DEBUG: Check what's in advances
            print("=== ADVANCES FROM API ===");
            for (int i = 0; i < fetchedAdvances.length; i++) {
              var a = fetchedAdvances[i];
              print(
                  "Advance $i - projectId: '${a['projectId']}', projectName: '${a['projectName']}'");
            }
          }
        } catch (_) {
          fetchedAdvances = [];
        }

        setState(() {
          requests = [
            // For Reimbursements:
            ...fetchedReimbursements.map((r) {
              List<Map<String, dynamic>> paymentsList = [];

              // ✅ FIXED: Better project ID extraction
              String projectId = "Not specified";

              // Check multiple possible field names
              if (r['projectId'] != null &&
                  r['projectId'].toString().isNotEmpty &&
                  r['projectId'].toString() != "null") {
                projectId = r['projectId'].toString();
                print("✅ Using projectId: $projectId");
              } else if (r['project_id'] != null &&
                  r['project_id'].toString().isNotEmpty &&
                  r['project_id'].toString() != "null") {
                projectId = r['project_id'].toString();
                print("✅ Using project_id: $projectId");
              } else if (r['projectId'] == "NOT_SPECIFIED" ||
                  r['project_id'] == "NOT_SPECIFIED") {
                projectId = "Not specified";
              } else {
                print("❌ No project ID found in reimbursement: ${r['id']}");
                print("Available keys: ${r.keys}");
              }

              if (r.containsKey('payments') && r['payments'] != null) {
                try {
                  paymentsList = List<Map<String, dynamic>>.from(r['payments']);
                  // ✅ ADD PROJECT ID TO EACH PAYMENT
                  for (var payment in paymentsList) {
                    payment['projectId'] = projectId;
                  }
                } catch (_) {
                  paymentsList = [];
                }
              } else {
                paymentsList = [
                  {
                    "amount": r["amount"],
                    "description": r["description"],
                    "requestDate": r["date"] ?? r["created_at"] ?? null,
                    "projectId": projectId,
                  },
                ];
              }

              DateTime requestDate = _parseRequestDate(r);

              return Request(
                id: r['id'] ?? 0,
                type: "Reimbursement",
                payments: paymentsList,
                status:
                    (r["status"] != null && r["status"].toString().isNotEmpty)
                        ? r["status"].toString()
                        : "Pending",
                currentStep: r["currentStep"] is int ? r["currentStep"] : 0,
                rejectionReason: r["rejection_reason"] ?? r["reason"] ?? "",
                requestDate: requestDate,
              );
            }),

            // For Advances:
            ...fetchedAdvances.map((r) {
              List<Map<String, dynamic>> paymentsList = [];

              // ✅ FIXED: Better project data extraction
              String projectId = "Not specified";
              String projectName = "Not specified";

              // Check multiple possible field names for projectId
              if (r['projectId'] != null &&
                  r['projectId'].toString().isNotEmpty &&
                  r['projectId'].toString() != "null") {
                projectId = r['projectId'].toString();
              } else if (r['project_id'] != null &&
                  r['project_id'].toString().isNotEmpty &&
                  r['project_id'].toString() != "null") {
                projectId = r['project_id'].toString();
              } else if (r['projectId'] == "NOT_SPECIFIED" ||
                  r['project_id'] == "NOT_SPECIFIED") {
                projectId = "Not specified";
              }

              // Check multiple possible field names for projectName
              if (r['projectName'] != null &&
                  r['projectName'].toString().isNotEmpty &&
                  r['projectName'].toString() != "null") {
                projectName = r['projectName'].toString();
              } else if (r['project_name'] != null &&
                  r['project_name'].toString().isNotEmpty &&
                  r['project_name'].toString() != "null") {
                projectName = r['project_name'].toString();
              } else if (r['projectName'] == "Not Specified" ||
                  r['project_name'] == "Not Specified") {
                projectName = "Not specified";
              }

              print(
                  "✅ Advance Project Data - ID: $projectId, Name: $projectName");

              if (r.containsKey('payments') && r['payments'] != null) {
                try {
                  paymentsList = List<Map<String, dynamic>>.from(r['payments']);
                  // ✅ ADD PROJECT ID AND NAME TO EACH PAYMENT
                  for (var payment in paymentsList) {
                    payment['projectId'] = projectId;
                    payment['projectName'] = projectName;
                  }
                } catch (_) {
                  paymentsList = [];
                }
              } else {
                paymentsList = [
                  {
                    "amount": r["amount"],
                    "description": r["description"],
                    "requestDate": r["request_date"] ?? r["created_at"] ?? null,
                    "projectDate": r["project_date"] ?? null,
                    "projectId": projectId,
                    "projectName": projectName,
                  },
                ];
              }

              DateTime requestDate = _parseRequestDate(r);

              return Request(
                id: r['id'] ?? 0,
                type: "Advance",
                payments: paymentsList,
                status:
                    (r["status"] != null && r["status"].toString().isNotEmpty)
                        ? r["status"].toString()
                        : "Pending",
                currentStep: r["currentStep"] is int ? r["currentStep"] : 0,
                rejectionReason: r["rejection_reason"] ?? r["rejectionReason"],
                requestDate: requestDate,
              );
            }),
          ];
          _isLoading = false;

          // ✅ FINAL DEBUG: Check what's in the requests
          print("=== FINAL REQUESTS DATA ===");
          for (int i = 0; i < requests.length; i++) {
            var request = requests[i];
            print("Request $i - Type: ${request.type}");
            if (request.payments.isNotEmpty) {
              print("  Payment projectId: ${request.payments[0]['projectId']}");
              if (request.type == "Advance") {
                print(
                    "  Payment projectName: ${request.payments[0]['projectName']}");
              }
            }
          }
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      print("Error loading requests: $error");
      setState(() {
        _isLoading = false;
      });
    }
  }

// ✅ ADD HELPER METHODS FOR PROJECT DATA EXTRACTION
  String _getProjectId(Map<String, dynamic> data) {
    // Try multiple possible field names
    if (data['projectId'] != null &&
        data['projectId'].toString().isNotEmpty &&
        data['projectId'].toString() != "null") {
      return data['projectId'].toString();
    } else if (data['project_id'] != null &&
        data['project_id'].toString().isNotEmpty &&
        data['project_id'].toString() != "null") {
      return data['project_id'].toString();
    } else {
      return "Not specified";
    }
  }

  String _getProjectName(Map<String, dynamic> data) {
    // Try multiple possible field names
    if (data['projectName'] != null &&
        data['projectName'].toString().isNotEmpty &&
        data['projectName'].toString() != "null") {
      return data['projectName'].toString();
    } else if (data['project_name'] != null &&
        data['project_name'].toString().isNotEmpty &&
        data['project_name'].toString() != "null") {
      return data['project_name'].toString();
    } else {
      return "Not specified";
    }
  }

  DateTime _parseRequestDate(Map<String, dynamic> requestData) {
    try {
      String? dateString = requestData["created_at"] ??
          requestData["date"] ??
          requestData["request_date"] ??
          requestData["updated_at"];

      if (dateString != null) {
        return DateTime.parse(dateString);
      }
    } catch (e) {
      print("Error parsing date: $e");
    }

    return DateTime.now();
  }

  List<Request> _sortRequestsByDate(List<Request> requests) {
    requests.sort((a, b) => b.requestDate.compareTo(a.requestDate));
    return requests;
  }

  List<Request> _filterRequests(String status) {
    List<Request> filtered = requests.where((r) {
      String requestStatus = r.status.toLowerCase();

      if (status == "Pending") {
        // ✅ SHOW ALL PENDING STATUSES (Pending, Pending Finance, Pending CEO, etc.)
        return requestStatus.contains('pending');
      } else if (status == "Approved") {
        return requestStatus == "approved" || requestStatus == "paid";
      } else if (status == "Rejected") {
        return requestStatus == "rejected";
      }
      return false;
    }).toList();

    // Rest of your filter logic remains the same...
    if (_selectedFilter != "All") {
      filtered = filtered.where((r) => r.type == _selectedFilter).toList();
    }

    if (_selectedDate != null) {
      filtered = filtered.where((r) {
        return r.requestDate.year == _selectedDate!.year &&
            r.requestDate.month == _selectedDate!.month &&
            r.requestDate.day == _selectedDate!.day;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((r) {
        double totalAmount = 0;
        for (var p in r.payments) {
          totalAmount += double.tryParse(p["amount"]?.toString() ?? "0") ?? 0;
        }
        return totalAmount.toString().contains(_searchQuery);
      }).toList();
    }

    return _sortRequestsByDate(filtered);
  }

  // 👇 Enhanced CSV Download function with backend integration
  Future<void> _downloadCSV(String period) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      if (authToken == null) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication required")),
        );
        return;
      }

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
          'Authorization': 'Token $authToken',
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
          'Authorization': 'Token $authToken',
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

  // 👇 Update the CSV download menu in app bar
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
      color: Color(0xFF1F222B),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1F222B),
              title: const Text(
                "Filter Requests",
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedFilter,
                    dropdownColor: const Color(0xFF1F222B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Type",
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                    items: ["All", "Reimbursement", "Advance"]
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedFilter = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    readOnly: true,
                    controller: TextEditingController(
                        text: _selectedDate != null
                            ? _formatDate(_selectedDate!)
                            : ""),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Date",
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                      suffixIcon:
                          Icon(Icons.calendar_today, color: Colors.white70),
                    ),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        setDialogState(() {
                          _selectedDate = pickedDate;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    onChanged: (value) {
                      setDialogState(() {
                        _searchQuery = value;
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Search by Amount",
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search, color: Colors.white70),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      _selectedFilter = "All";
                      _selectedDate = null;
                      _searchQuery = "";
                    });
                  },
                  child:
                      const Text("Reset", style: TextStyle(color: Colors.red)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: const Text("Apply",
                      style: TextStyle(color: Colors.green)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 174, 135, 184),
              Color.fromARGB(255, 127, 152, 250),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestCard(Request request, int index) {
    Gradient gradient;
    String statusLower = request.status.toLowerCase();

    if (statusLower.contains('pending')) {
      // ✅ ALL PENDING STATUSES (Pending, Pending Finance, Pending CEO, etc.)
      gradient = const LinearGradient(
        colors: [
          Color.fromARGB(255, 255, 176, 80),
          Color.fromARGB(255, 227, 182, 85),
        ],
      );
    } else if (statusLower == "approved") {
      gradient = const LinearGradient(
        colors: [Color.fromARGB(255, 125, 193, 100), Color(0xFFA5D6A7)],
      );
    } else if (statusLower == "paid") {
      gradient = const LinearGradient(
        colors: [Color.fromARGB(255, 86, 157, 229), Color(0xFF90CAF9)],
      );
    } else if (statusLower == "rejected") {
      gradient = const LinearGradient(
        colors: [
          Color.fromARGB(255, 174, 72, 72),
          Color.fromARGB(255, 198, 140, 124),
        ],
      );
    } else {
      gradient = const LinearGradient(colors: [Colors.grey, Colors.grey]);
    }

    double totalAmount = 0;
    for (var p in request.payments) {
      totalAmount += double.tryParse(p["amount"]?.toString() ?? "0") ?? 0;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        title: Text(
          "${request.type} Request",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Total Amount: ₹${totalAmount.toStringAsFixed(2)}",
              style: const TextStyle(color: Colors.white70),
              overflow: TextOverflow.ellipsis, // ✅ ADD THIS
            ),
            Text(
              "Date: ${_formatDate(request.requestDate)}",
              style: const TextStyle(color: Colors.white70),
              overflow: TextOverflow.ellipsis, // ✅ ADD THIS
            ),
            Text(
              "Status: ${request.status}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis, // ✅ ADD THIS
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white70,
          size: 18,
        ),
        onTap: () {
          print("=== NAVIGATING TO HISTORY SCREEN ===");
          print("Request Type: ${request.type}");
          print("Payments count: ${request.payments.length}");
          if (request.payments.isNotEmpty) {
            print(
                "First payment projectId: ${request.payments[0]['projectId']}");
            if (request.type == "Advance") {
              print(
                  "First payment projectName: ${request.payments[0]['projectName']}");
            }
          }
          // ✅ FIXED: Pass all required fields including missing ones
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RequestHistoryScreen(
                employeeName: widget.employeeName,
                requestTitle: "${request.type} Request",
                payments: _preparePaymentsData(request.payments, request.type),
                requestType:
                    request.type.toLowerCase(), // "reimbursement" or "advance"
                requestId: request.id
                    .toString(), // ADD THIS LINE - request ID for dynamic data
                authToken: authToken!, // Pass the auth token
                currentStep: request.currentStep,
                status: request.status,
                rejectionReason: request.rejectionReason,
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _preparePaymentsData(
      List<Map<String, dynamic>> originalPayments, String requestType) {
    // ✅ ADD DEBUG LOGGING
    print("=== PREPARING PAYMENTS DATA ===");
    print("Request Type: $requestType");
    print("Original payments count: ${originalPayments.length}");

    if (originalPayments.isNotEmpty) {
      print("Original first payment keys: ${originalPayments[0].keys}");
      print(
          "Original first payment projectId: ${originalPayments[0]['projectId']}");
      if (requestType == "Advance") {
        print(
            "Original first payment projectName: ${originalPayments[0]['projectName']}");
      }
    }

    return originalPayments.map((payment) {
      Map<String, dynamic> preparedPayment = Map.from(payment);

      if (requestType == "Reimbursement") {
        // ✅ PRESERVE ALL REIMBURSEMENT FIELDS
        preparedPayment['description'] =
            payment['description'] ?? 'No description';
        preparedPayment['claimType'] = payment['claimType'] ?? 'Not specified';
        preparedPayment['paymentDate'] =
            payment['paymentDate'] ?? payment['date'] ?? DateTime.now();
        preparedPayment['projectId'] =
            payment['projectId'] ?? 'Not specified'; // ✅ PRESERVE PROJECT ID

        // Map to expected fields for the screen
        preparedPayment['particulars'] =
            payment['description'] ?? 'No description';
        preparedPayment['projectDate'] =
            payment['paymentDate'] ?? DateTime.now();
      } else {
        // ✅ PRESERVE ALL ADVANCE FIELDS
        preparedPayment['particulars'] = payment['particulars'] ??
            payment['description'] ??
            'No particulars';
        preparedPayment['projectDate'] =
            payment['projectDate'] ?? DateTime.now();
        preparedPayment['projectId'] =
            payment['projectId'] ?? 'Not specified'; // ✅ PRESERVE PROJECT ID
        preparedPayment['projectName'] = payment['projectName'] ??
            'Not specified'; // ✅ PRESERVE PROJECT NAME
      }

      // Common fields
      preparedPayment['amount'] = payment['amount'] ?? '0';
      preparedPayment['requestDate'] =
          payment['requestDate'] ?? payment['date'] ?? DateTime.now();
      preparedPayment['Submittion Date'] =
          payment['Submittion Date'] ?? payment['date'] ?? DateTime.now();
      preparedPayment['attachmentPaths'] = payment['attachmentPaths'] ??
          (payment['attachmentPath'] != null
              ? [payment['attachmentPath']]
              : []);

      // ✅ DEBUG: Check prepared payment
      print("Prepared payment projectId: ${preparedPayment['projectId']}");
      if (requestType == "Advance") {
        print(
            "Prepared payment projectName: ${preparedPayment['projectName']}");
      }

      return preparedPayment;
    }).toList();
  }

  Future<void> _createRequest(String type) async {
    if (authToken == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Auth token missing!")));
      return;
    }

    if (type == "Reimbursement") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReimbursementFormScreen(
            onSubmit: (submittedPayments) async {
              // ✅ FORCE REFRESH AND SHOW SUCCESS
              await _loadAuthTokenAndRequests();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text("Reimbursement submitted successfully!")),
              );
            },
          ),
        ),
      );
    } else if (type == "Advance") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdvanceRequestFormScreen(
            onSubmit: (advanceData) {
              // ✅ FORCE REFRESH AND SHOW SUCCESS
              _loadAuthTokenAndRequests();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text("Advance request submitted successfully!")),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F222B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Xpensure",
          style: TextStyle(
            color: Colors.grey[300],
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          _buildCSVDownloadMenu(),
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.grey[300]),
            onPressed: _showFilterDialog,
          ),
          // IconButton(
          // icon: Icon(Icons.notifications_outlined, color: Colors.grey[300]),
          // onPressed: () {},
          // ),
          IconButton(
            icon: CircleAvatar(
              backgroundColor: const Color(0xFF849CFC),
              backgroundImage: currentAvatarUrl != null
                  ? NetworkImage(currentAvatarUrl!)
                  : null,
              child: currentAvatarUrl == null
                  ? Text(
                      (widget.employeeName.isNotEmpty
                              ? widget.employeeName[0]
                              : '?')
                          .toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            onPressed: () async {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) {
                  return Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F222B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit, color: Colors.white),
                          title: const Text(
                            "Profile",
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            final updatedAvatarUrl = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(
                                  employeeId: widget.employeeId,
                                  authToken: authToken ?? '',
                                ),
                              ),
                            );
                            if (updatedAvatarUrl != null &&
                                updatedAvatarUrl is String) {
                              setState(() {
                                currentAvatarUrl = updatedAvatarUrl;
                              });
                            }
                          },
                        ),
                        const Divider(color: Colors.grey),
                        ListTile(
                          leading: const Icon(Icons.lock, color: Colors.white),
                          title: const Text(
                            "Change Password",
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChangePasswordScreen(
                                  employeeId: widget.employeeId,
                                  authToken: authToken ?? '',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Welcome, ${widget.employeeName}",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[200],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: _quickActionCard(
                    icon: Icons.request_page,
                    title: "Reimbursement",
                    onTap: () => _createRequest("Reimbursement"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionCard(
                    icon: Icons.payments,
                    title: "Advance Request",
                    onTap: () => _createRequest("Advance"),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            indicatorColor: const Color.fromARGB(255, 136, 122, 139),
            labelColor: const Color.fromARGB(255, 133, 130, 134),
            unselectedLabelColor: Colors.grey[400],
            tabs: const [
              Tab(text: "Pending"),
              Tab(text: "Approved"),
              Tab(text: "Rejected"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: ["Pending", "Approved", "Rejected"].map((status) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                var filtered = _filterRequests(status);
                return filtered.isEmpty
                    ? const Center(
                        child: Text(
                          "No requests",
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            _requestCard(filtered[index], index),
                      );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
