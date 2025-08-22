import 'package:flutter/material.dart';
import 'request_history.dart';

class EmployeeDashboard extends StatefulWidget {
  final String employeeName;

  const EmployeeDashboard({super.key, required this.employeeName});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Quick Action Card with gradient
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
              Color(0xFFC196CC), // purple
              Color(0xFF849CFC), // blue
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

  // Request Card with gradient background
  Widget _requestCard(String type, int index, Gradient gradient) {
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
          "$type Request #${index + 1}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: const Text(
          "₹5,000 • Travel Expenses",
          style: TextStyle(color: Colors.white70),
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
                requestTitle: "$type Request #${index + 1}",
                amount: 5000,
                description: "Travel Expenses",
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A20), // Dark background
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
          // Welcome Header
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

          // Quick Actions Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: _quickActionCard(
                    icon: Icons.request_page,
                    title: "Reimbursement",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Reimbursement Form Coming Soon"),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionCard(
                    icon: Icons.payments,
                    title: "Advance Request",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Advance Request Form Coming Soon"),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tabs for Pending, Approved, Rejected
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.purpleAccent[100],
            labelColor: Colors.purpleAccent[100],
            unselectedLabelColor: Colors.grey[400],
            tabs: const [
              Tab(text: "Pending"),
              Tab(text: "Approved"),
              Tab(text: "Rejected"),
            ],
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Pending - gradient purple → pink
                ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: 3,
                  itemBuilder: (context, index) => _requestCard(
                    "Pending",
                    index,
                    const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.fromARGB(255, 204, 158, 61), // purple
                        Color.fromARGB(255, 229, 162, 80), // light purple
                      ],
                    ),
                  ),
                ),
                // Approved - gradient teal → green
                ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: 2,
                  itemBuilder: (context, index) => _requestCard(
                    "Approved",
                    index,
                    const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.fromARGB(255, 125, 193, 100), // teal
                        Color(0xFFA5D6A7), // light green
                      ],
                    ),
                  ),
                ),
                // Rejected - gradient red → orange
                ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: 1,
                  itemBuilder: (context, index) => _requestCard(
                    "Rejected",
                    index,
                    const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.fromARGB(255, 174, 72, 72), // red
                        Color.fromARGB(255, 198, 140, 124), // orange
                      ],
                    ),
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
