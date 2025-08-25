import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'reimbursement_form.dart';
import 'request_history.dart';
import 'advance_form.dart';
import '../services/api_service.dart'; // ApiService

// Request model
class Request {
  final String type; // "Reimbursement" or "Advance"
  final List<Map<String, dynamic>> payments;
  String status; // "Pending", "Approved", "Rejected"

  Request({
    required this.type,
    required this.payments,
    this.status = "Pending",
  });
}

class EmployeeDashboard extends StatefulWidget {
  final String employeeName;

  const EmployeeDashboard({super.key, required this.employeeName});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Request> requests = []; // All requests
  final ApiService apiService = ApiService(); // API instance
  String? authToken;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAuthTokenAndRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthTokenAndRequests() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString('authToken');

    if (authToken != null) {
      var fetchedReimbursementsRaw = await apiService.fetchReimbursements(
        authToken!,
      );
      var fetchedAdvancesRaw = await apiService.fetchAdvances(authToken!);

      List<Map<String, dynamic>> fetchedReimbursements =
          List<Map<String, dynamic>>.from(fetchedReimbursementsRaw);
      List<Map<String, dynamic>> fetchedAdvances =
          List<Map<String, dynamic>>.from(fetchedAdvancesRaw);

      setState(() {
        requests = [
          ...fetchedReimbursements.map(
            (r) => Request(
              type: "Reimbursement",
              payments: List<Map<String, dynamic>>.from(r["payments"]),
              status: r["status"] ?? "Pending",
            ),
          ),
          ...fetchedAdvances.map(
            (r) => Request(
              type: "Advance",
              payments: List<Map<String, dynamic>>.from(r["payments"]),
              status: r["status"] ?? "Pending",
            ),
          ),
        ];
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
              offset: Offset(0, 4),
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
        subtitle: Text(
          "Payments: ${request.payments.length}",
          style: const TextStyle(color: Colors.white70),
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
                payments: request.payments,
              ),
            ),
          );
        },
      ),
    );
  }

  List<Request> _filterRequests(String status) =>
      requests.where((r) => r.status == status).toList();

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

              for (var payment in paymentsList) {
                String amount = payment["amount"];
                String description = payment["description"];
                String date = payment["paymentDate"].toString().split(" ")[0];
                File? attachment = payment["attachmentPath"] != null
                    ? File(payment["attachmentPath"])
                    : null;

                String result = await apiService.submitReimbursement(
                  authToken: authToken!,
                  amount: amount,
                  description: description,
                  attachment: attachment,
                  date: date,
                );

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(result)));
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
                  List<Map<String, dynamic>>.from(advanceData["payments"]);
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
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: CircleAvatar(
              backgroundColor: const Color(0xFF849CFC),
              child: Text(
                widget.employeeName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
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
              children: [
                _filterRequests("Pending").isEmpty
                    ? const Center(
                        child: Text(
                          "No pending requests",
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: _filterRequests("Pending").length,
                        itemBuilder: (context, index) => _requestCard(
                          _filterRequests("Pending")[index],
                          index,
                        ),
                      ),
                _filterRequests("Approved").isEmpty
                    ? const Center(
                        child: Text(
                          "No approved requests",
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: _filterRequests("Approved").length,
                        itemBuilder: (context, index) => _requestCard(
                          _filterRequests("Approved")[index],
                          index,
                        ),
                      ),
                _filterRequests("Rejected").isEmpty
                    ? const Center(
                        child: Text(
                          "No rejected requests",
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: _filterRequests("Rejected").length,
                        itemBuilder: (context, index) => _requestCard(
                          _filterRequests("Rejected")[index],
                          index,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
