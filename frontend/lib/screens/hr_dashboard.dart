import 'package:flutter/material.dart';

// Mock service to simulate backend API calls
class EmployeeService {
  static List<Map<String, dynamic>> _employees = [
    {
      "id": "1",
      "employeeId": "EMP001",
      "name": "Alice Smith",
      "department": "Finance",
      "position": "Manager",
      "role": "Team Lead",
      "status": "Active",
      "joinDate": "2023-01-10",
      "email": "alice@company.com",
      "phone": "1234567890",
      "aadharNo": "1234-5678-9012",
      "reportTo": "John Director",
    },
    {
      "id": "2",
      "employeeId": "EMP002",
      "name": "Bob Johnson",
      "department": "HR",
      "position": "Executive",
      "role": "Recruiter",
      "status": "Left",
      "joinDate": "2022-05-12",
      "email": "bob@company.com",
      "phone": "9876543210",
      "aadharNo": "9876-5432-1098",
      "reportTo": "HR Head",
    },
  ];

  static List<Map<String, dynamic>> _activities = [
    {
      "id": "1",
      "title": "New hire joined",
      "timestamp": "2 hours ago",
      "icon": Icons.person_add,
      "color": Colors.green,
    },
    {
      "id": "2",
      "title": "Reimbursement request",
      "timestamp": "1 day ago",
      "icon": Icons.request_page,
      "color": Colors.blue,
    },
  ];

  // Simulate API call to fetch employees
  static Future<List<Map<String, dynamic>>> getEmployees() async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    return _employees;
  }

  // Simulate API call to add a new employee
  static Future<bool> addEmployee(Map<String, dynamic> employee) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    employee['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    _employees.add(employee);
    return true;
  }

  // Simulate API call to delete an employee
  static Future<bool> deleteEmployee(String id) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    _employees.removeWhere((employee) => employee['id'] == id);
    return true;
  }

  // Simulate API call to update employee status
  static Future<bool> updateEmployeeStatus(String id, String status) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    int index = _employees.indexWhere((employee) => employee['id'] == id);
    if (index != -1) {
      _employees[index]['status'] = status;
      return true;
    }
    return false;
  }

  // Simulate API call to fetch activities
  static Future<List<Map<String, dynamic>>> getActivities() async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    return _activities;
  }

  // Simulate API call to add a new activity
  static Future<bool> addActivity(Map<String, dynamic> activity) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    activity['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    _activities.insert(0, activity);
    return true;
  }
}

class HRDashboard extends StatefulWidget {
  const HRDashboard({super.key});

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String searchQuery = "";
  String employeeFilter = "All"; // "All", "Active", "Left"
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> activities = [];
  bool isLoading = true;
  Map<String, dynamic>? selectedEmployee;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final employeesData = await EmployeeService.getEmployees();
      final activitiesData = await EmployeeService.getActivities();

      setState(() {
        employees = employeesData;
        activities = activitiesData;
        isLoading = false;
      });
    } catch (e) {
      // Handle error
      setState(() {
        isLoading = false;
      });
    }
  }

  void _addEmployee(Map<String, dynamic> newEmployee) async {
    setState(() {
      isLoading = true;
    });

    try {
      final success = await EmployeeService.addEmployee(newEmployee);

      if (success) {
        // Add activity for new hire
        await EmployeeService.addActivity({
          "title": "New hire: ${newEmployee['name']}",
          "timestamp": "Just now",
          "icon": Icons.person_add,
          "color": Colors.green,
        });

        // Refresh data
        await _loadData();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newEmployee['name']} added successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Switch to employees tab
        _tabController.animateTo(2);
      }
    } catch (e) {
      // Handle error
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add employee'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _markEmployeeAsLeft(String id, String name) async {
    setState(() {
      isLoading = true;
    });

    try {
      final success = await EmployeeService.updateEmployeeStatus(id, "Left");

      if (success) {
        // Add activity for employee leaving
        await EmployeeService.addActivity({
          "title": "Employee left: $name",
          "timestamp": "Just now",
          "icon": Icons.person_remove,
          "color": Colors.red,
        });

        // Refresh data
        await _loadData();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name marked as left'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      // Handle error
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update employee status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteEmployee(String id, String name) async {
    setState(() {
      isLoading = true;
    });

    try {
      final success = await EmployeeService.deleteEmployee(id);

      if (success) {
        // Add activity for employee deletion
        await EmployeeService.addActivity({
          "title": "Employee deleted: $name",
          "timestamp": "Just now",
          "icon": Icons.delete,
          "color": Colors.red,
        });

        // Refresh data
        await _loadData();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Handle error
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete employee'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEmployeeDetails(Map<String, dynamic> employee) {
    setState(() {
      selectedEmployee = employee;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return EmployeeDetailsSheet(
          employee: employee,
          onMarkAsLeft: () {
            Navigator.of(context).pop();
            _markEmployeeAsLeft(employee['id'], employee['name']);
          },
          onDelete: () {
            Navigator.of(context).pop();
            _showDeleteConfirmation(employee['id'], employee['name']);
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(String id, String name) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            "Confirm Delete",
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            "Are you sure you want to delete $name? This action cannot be undone.",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteEmployee(id, name);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        leadingWidth: 0,
        title: Row(
          children: [
            Container(
              width: 120,
              height: 40,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple, Colors.purpleAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: const Center(
                child: Text(
                  "Xpensure",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "HR Dashboard",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {},
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.redAccent, Colors.deepOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Text(
                "HR",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.deepPurpleAccent,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: "Overview"),
            Tab(icon: Icon(Icons.bar_chart), text: "Charts"),
            Tab(icon: Icon(Icons.group), text: "Employees"),
            Tab(icon: Icon(Icons.history), text: "Activity"),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildChartsTab(),
                _buildEmployeesTab(),
                _buildActivityTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final activeEmployees =
        employees.where((e) => e["status"] == "Active").length;
    final leftEmployees = employees.where((e) => e["status"] == "Left").length;
    final newHires = employees
        .where(
          (e) =>
              e["joinDate"] != null &&
              DateTime.parse(
                e["joinDate"],
              ).isAfter(DateTime.now().subtract(const Duration(days: 30))),
        )
        .length;

    final stats = [
      {
        "title": "Total Employees",
        "value": employees.length,
        "color": Colors.blue,
        "icon": Icons.group,
      },
      {
        "title": "Active Employees",
        "value": activeEmployees,
        "color": Colors.green,
        "icon": Icons.check_circle,
      },
      {
        "title": "Employees Left",
        "value": leftEmployees,
        "color": Colors.red,
        "icon": Icons.exit_to_app,
      },
      {
        "title": "New Hires",
        "value": newHires,
        "color": Colors.purple,
        "icon": Icons.person_add,
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Statistics Overview",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              itemCount: stats.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              itemBuilder: (context, index) {
                final stat = stats[index];
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: stat["color"] as Color,
                            child: Icon(
                              stat["icon"] as IconData,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        (stat["value"] as int).toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stat["title"] as String,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsTab() {
    return const Center(
      child: Text(
        "Charts temporarily disabled",
        style: TextStyle(color: Colors.white54, fontSize: 16),
      ),
    );
  }

  Widget _buildEmployeesTab() {
    List<Map<String, dynamic>> filteredEmployees = employees
        .where(
          (e) =>
              e["name"].toLowerCase().contains(searchQuery.toLowerCase()) ||
              e["department"].toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
              e["employeeId"].toLowerCase().contains(searchQuery.toLowerCase()),
        )
        .toList();

    // Apply status filter
    if (employeeFilter != "All") {
      filteredEmployees = filteredEmployees
          .where((e) => e["status"] == employeeFilter)
          .toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => searchQuery = val),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search employees...",
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF1F1F1F),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F1F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      employeeFilter = value;
                    });
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: "All",
                      child: Text("All Employees"),
                    ),
                    const PopupMenuItem<String>(
                      value: "Active",
                      child: Text("Active Only"),
                    ),
                    const PopupMenuItem<String>(
                      value: "Left",
                      child: Text("Left Only"),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          employeeFilter == "All"
                              ? "All"
                              : employeeFilter == "Active"
                                  ? "Active"
                                  : "Left",
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.deepPurple, Colors.purpleAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  onPressed: () {
                    _showAddEmployeeDialog(context);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredEmployees.length,
            itemBuilder: (context, index) {
              final e = filteredEmployees[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F1F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  onTap: () => _showEmployeeDetails(e),
                  title: Text(
                    e["name"],
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${e["position"]} - ${e["department"]}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        "ID: ${e["employeeId"]}",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          e["status"] == "Active" ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      e["status"],
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddEmployeeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final employeeIdController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final departmentController = TextEditingController();
    final aadharController = TextEditingController();
    final reportToController = TextEditingController();
    final roleController = TextEditingController();
    String selectedStatus = "Active";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "Add New Employee",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // First row of fields
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          nameController,
                          "Full Name",
                          Icons.person,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          employeeIdController,
                          "Employee ID",
                          Icons.badge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Second row of fields
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          emailController,
                          "Email ID",
                          Icons.email,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          phoneController,
                          "Phone No",
                          Icons.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Third row of fields
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          departmentController,
                          "Department",
                          Icons.business,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          aadharController,
                          "Aadhar No",
                          Icons.credit_card,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Fourth row of fields
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          reportToController,
                          "Report To",
                          Icons.supervisor_account,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          roleController,
                          "Role",
                          Icons.work,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Status dropdown
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E1E1E),
                    value: selectedStatus,
                    items: ["Active", "Left"].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      selectedStatus = newValue!;
                    },
                    decoration: InputDecoration(
                      labelText: "Status",
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(
                        Icons.circle,
                        color: Colors.white54,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1F1F1F),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.deepPurple, Colors.purpleAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            if (nameController.text.isEmpty ||
                                employeeIdController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Name and Employee ID are required',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            final newEmployee = {
                              "name": nameController.text,
                              "employeeId": employeeIdController.text,
                              "email": emailController.text,
                              "phone": phoneController.text,
                              "department": departmentController.text,
                              "aadharNo": aadharController.text,
                              "reportTo": reportToController.text,
                              "position": roleController.text,
                              "status": selectedStatus,
                              "joinDate": DateTime.now().toString().split(
                                    " ",
                                  )[0],
                            };

                            _addEmployee(newEmployee);
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Add Employee",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: const Color(0xFF1F1F1F),
      ),
    );
  }

  Widget _buildActivityTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: activities.length,
        itemBuilder: (context, index) {
          final a = activities[index];
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: a["color"],
                child: Icon(a["icon"], color: Colors.white, size: 20),
              ),
              title: Text(
                a["title"],
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                a["timestamp"],
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          );
        },
      ),
    );
  }
}

class EmployeeDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onMarkAsLeft;
  final VoidCallback onDelete;

  const EmployeeDetailsSheet({
    super.key,
    required this.employee,
    required this.onMarkAsLeft,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (_, controller) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: employee["status"] == "Active"
                        ? Colors.green
                        : Colors.red,
                    child: Text(
                      employee["name"].substring(0, 1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee["name"],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${employee["position"]} - ${employee["department"]}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: employee["status"] == "Active"
                                ? Colors.green
                                : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            employee["status"],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                "Employee Details",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow("Employee ID", employee["employeeId"]),
              _buildDetailRow("Email", employee["email"]),
              _buildDetailRow("Phone", employee["phone"]),
              _buildDetailRow("Aadhar No", employee["aadharNo"]),
              _buildDetailRow("Reports To", employee["reportTo"]),
              _buildDetailRow("Join Date", employee["joinDate"]),
              const SizedBox(height: 24),
              if (employee["status"] == "Active") ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onMarkAsLeft,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Mark as Left",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Delete Employee",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Close",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
