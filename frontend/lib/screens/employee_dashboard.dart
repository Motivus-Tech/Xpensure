import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'request_history.dart';

// Request model
class Request {
  final String type; // "Reimbursement" or "Advance"
  final int amount;
  final String description;
  String status; // "Pending", "Approved", "Rejected"

  Request({
    required this.type,
    required this.amount,
    required this.description,
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
  List<Request> requests = []; // dynamic request list

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

  // Quick Action Card (UI same as original)
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
              Color.fromARGB(255, 174, 135, 184), // purple
              Color.fromARGB(255, 127, 152, 250), // blue
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

  // Request Card
  Widget _requestCard(Request request, int index) {
    Gradient gradient;

    switch (request.status) {
      case "Pending":
        gradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 255, 176, 80),
            Color.fromARGB(255, 227, 182, 85),
          ],
        );
        break;
      case "Approved":
        gradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.fromARGB(255, 125, 193, 100), Color(0xFFA5D6A7)],
        );
        break;
      case "Rejected":
        gradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
          "₹${request.amount} • ${request.description}",
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
                amount: request.amount,
                description: request.description,
              ),
            ),
          );
        },
      ),
    );
  }

  // Filter requests by status
  List<Request> _filterRequests(String status) {
    return requests.where((r) => r.status == status).toList();
  }

  // Open form to create new request
  void _createRequest(String type) {
    final _amountController = TextEditingController();
    final _descController = TextEditingController();
    final _projectController = TextEditingController();
    DateTime? _selectedDate;
    String? _attachmentPath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1F222B),
          title: Text(
            "New $type Request",
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (type == "Reimbursement") ...[
                  // Date Picker
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: DateTime(now.year - 5),
                        lastDate: DateTime(now.year + 5),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: const Color(0xFF849CFC),
                                onPrimary: Colors.white,
                                surface: const Color(0xFF1F222B),
                                onSurface: Colors.white,
                              ),
                              dialogBackgroundColor: const Color(0xFF1F222B),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null)
                        setStateDialog(() => _selectedDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Date",
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                      ),
                      child: Text(
                        _selectedDate == null
                            ? "Select Date"
                            : "${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Project ID
                  TextField(
                    controller: _projectController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Project ID",
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Attachment picker
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF849CFC),
                        ),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['jpg', 'jpeg', 'pdf'],
                          );
                          if (result != null && result.files.isNotEmpty) {
                            setStateDialog(() {
                              _attachmentPath = result.files.first.path;
                            });
                          }
                        },
                        child: const Text("Pick Attachment"),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _attachmentPath != null
                              ? _attachmentPath!.split('/').last
                              : "No file selected",
                          style: const TextStyle(color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Amount
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Amount",
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                TextField(
                  controller: _descController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Description",
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (_amountController.text.isEmpty ||
                    _descController.text.isEmpty)
                  return;

                if (type == "Reimbursement" && _selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please select a date")),
                  );
                  return;
                }

                setState(() {
                  String desc = _descController.text;
                  if (type == "Reimbursement") {
                    desc +=
                        " | Project ID: ${_projectController.text} | Date: ${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}";
                    if (_attachmentPath != null)
                      desc +=
                          " | Attachment: ${_attachmentPath!.split('/').last}";
                  }
                  requests.add(
                    Request(
                      type: type,
                      amount: int.parse(_amountController.text),
                      description: desc,
                    ),
                  );
                });
                Navigator.pop(context);
              },
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
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

          // Tabs
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

          // Tab Views
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
