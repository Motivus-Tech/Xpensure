import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'reimbursement_form.dart';
import 'request_history.dart';
import 'advance_form.dart';
import 'change_password.dart';
import 'edit_profile.dart';
import '../services/api_service.dart'; // ApiService

class Request {
  final String type;
  final List<Map<String, dynamic>> payments;
  String status;
  final int currentStep;
  final String? rejectionReason; // 👈 add this

  Request({
    required this.type,
    required this.payments,
    this.status = "Pending",
    this.currentStep = 0,
    this.rejectionReason,
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Use the avatar URL from the backend if available
    currentAvatarUrl = widget.avatarUrl.isNotEmpty
        ? (widget.avatarUrl.startsWith("http")
            ? widget.avatarUrl
            : "http://10.0.2.2:8000${widget.avatarUrl}") // replace with real backend base URL
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
        // ✅ FIXED: Use the dashboard endpoint that includes ALL statuses
        dynamic dashboardResponse = await apiService.getPendingApprovals(
          authToken: authToken!,
        );

        List<Map<String, dynamic>> fetchedReimbursements = [];
        List<Map<String, dynamic>> fetchedAdvances = [];

        try {
          if (dashboardResponse is Map &&
              dashboardResponse.containsKey('my_reimbursements')) {
            fetchedReimbursements = List<Map<String, dynamic>>.from(
              dashboardResponse['my_reimbursements'],
            );
          }
        } catch (_) {
          fetchedReimbursements = [];
        }

        try {
          if (dashboardResponse is Map &&
              dashboardResponse.containsKey('my_advances')) {
            fetchedAdvances = List<Map<String, dynamic>>.from(
              dashboardResponse['my_advances'],
            );
          }
        } catch (_) {
          fetchedAdvances = [];
        }

        setState(() {
          requests = [
            ...fetchedReimbursements.map((r) {
              List<Map<String, dynamic>> paymentsList = [];
              if (r.containsKey('payments') && r['payments'] != null) {
                try {
                  paymentsList = List<Map<String, dynamic>>.from(r['payments']);
                } catch (_) {
                  paymentsList = [];
                }
              } else {
                paymentsList = [
                  {
                    "amount": r["amount"],
                    "description": r["description"],
                    "requestDate": r["date"] ?? r["created_at"] ?? null,
                  },
                ];
              }
              return Request(
                type: "Reimbursement",
                payments: paymentsList,
                status:
                    (r["status"] != null && r["status"].toString().isNotEmpty)
                        ? r["status"].toString()
                        : "Pending",
                currentStep: r["currentStep"] is int ? r["currentStep"] : 0,
                rejectionReason:
                    r["rejection_reason"] ?? r["reason"] ?? "", // ✅ Added
              );
            }),
            ...fetchedAdvances.map((r) {
              List<Map<String, dynamic>> paymentsList = [];
              if (r.containsKey('payments') && r['payments'] != null) {
                try {
                  paymentsList = List<Map<String, dynamic>>.from(r['payments']);
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
                  },
                ];
              }
              return Request(
                type: "Advance",
                payments: paymentsList,
                status:
                    (r["status"] != null && r["status"].toString().isNotEmpty)
                        ? r["status"].toString()
                        : "Pending",
                currentStep: r["currentStep"] is int ? r["currentStep"] : 0,
                rejectionReason:
                    r["rejection_reason"] ?? r["rejectionReason"], // 👈 new
              );
            }),
          ];
          _isLoading = false;
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
    switch (request.status) {
      case "Pending":
        gradient = const LinearGradient(
          colors: [
            Color.fromARGB(255, 255, 176, 80),
            Color.fromARGB(255, 227, 182, 85),
          ],
        );
        break;
      case "Approved":
        gradient = const LinearGradient(
          colors: [Color.fromARGB(255, 125, 193, 100), Color(0xFFA5D6A7)],
        );
        break;
      case "Paid": // ✅ ADDED PAID STATUS
        gradient = const LinearGradient(
          colors: [Color.fromARGB(255, 86, 157, 229), Color(0xFF90CAF9)],
        );
        break;
      case "Rejected":
        gradient = const LinearGradient(
          colors: [
            Color.fromARGB(255, 174, 72, 72),
            Color.fromARGB(255, 198, 140, 124),
          ],
        );
        break;
      default:
        gradient = const LinearGradient(colors: [Colors.grey, Colors.grey]);
    }

    double totalAmount = 0;
    for (var p in request.payments) {
      totalAmount += double.tryParse(p["amount"]?.toString() ?? "0") ?? 0;
    }

    String requestDateStr = "-";
    if (request.payments.isNotEmpty) {
      List<DateTime> dates = request.payments.map((p) {
        final rd = p["requestDate"];
        if (rd is DateTime) return rd;
        if (rd is String) {
          try {
            return DateTime.parse(rd);
          } catch (_) {
            return DateTime.now();
          }
        }
        return DateTime.now();
      }).toList();
      dates.sort((a, b) => a.compareTo(b));
      final earliest = dates.first;
      requestDateStr =
          "${earliest.year}-${earliest.month.toString().padLeft(2, '0')}-${earliest.day.toString().padLeft(2, '0')}";
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
          "${request.type} Request #${index + 1}",
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
            ),
            Text(
              "Date: $requestDateStr",
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              "Status: ${request.status}", // ✅ ADDED STATUS DISPLAY
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white70,
          size: 18,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RequestHistoryScreen(
                employeeName: widget.employeeName,
                requestTitle: "${request.type} Request #${index + 1}",
                payments: request.payments.isNotEmpty ? request.payments : [],
                currentStep: request.currentStep,
                status: request.status, // 👈 add this line
                rejectionReason: request.rejectionReason, // 👈 add this
              ),
            ),
          );
        },
      ),
    );
  }

  List<Request> _filterRequests(String status) {
    if (status == "Approved") {
      // ✅ FIXED: Show both "Approved" and "Paid" in Approved tab
      return requests
          .where((r) => r.status == "Approved" || r.status == "Paid")
          .toList();
    }
    return requests.where((r) => r.status == status).toList();
  }

  Future<void> _createRequest(String type) async {
    if (authToken == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Auth token missing!")));
      return;
    }

    if (type == "Reimbursement") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReimbursementFormScreen(
            onSubmit: (submittedPayments) async {
              List<Map<String, dynamic>> paymentsList = [];
              if (submittedPayments["payments"] != null) {
                paymentsList = List<Map<String, dynamic>>.from(
                  submittedPayments["payments"],
                );
              } else {
                paymentsList = [submittedPayments];
              }
              setState(() {
                requests.add(
                  Request(type: "Reimbursement", payments: paymentsList),
                );
              });
              Navigator.pop(context);
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
              List<Map<String, dynamic>> paymentsList =
                  advanceData["payments"] != null
                      ? List<Map<String, dynamic>>.from(advanceData["payments"])
                      : [];
              setState(() {
                requests.add(Request(type: "Advance", payments: paymentsList));
              });
              Navigator.pop(context);
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
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Colors.grey[300]),
            onPressed: () {},
          ),
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
                            "Edit Profile",
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
                if (_isLoading)
                  return const Center(child: CircularProgressIndicator());
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
