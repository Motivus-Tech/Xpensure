import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Backend service fully connected to your Django API
class EmployeeService {
  static const String baseUrl =
      "http://10.0.2.2:8000/api"; // Replace with your actual Django API URL

  static Map<String, String> getHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  // Employee Login
  static Future<Map<String, dynamic>> login(
      String employeeId, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login/'),
      headers: getHeaders(null),
      body: json.encode({
        'employee_id': employeeId,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
          'Failed to login: ${response.statusCode} - ${response.body}');
    }
  }

  // Fetch all employees (Admin only)
  static Future<List<Map<String, dynamic>>> getEmployees(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/employees/'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to fetch employees: ${response.statusCode}');
    }
  }

  // Add a new employee (Admin only)
  static Future<Map<String, dynamic>> addEmployee(
      Map<String, dynamic> employee, String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/employees/'),
      headers: getHeaders(token),
      body: json.encode(employee),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
          'Failed to add employee: ${response.statusCode} - ${response.body}');
    }
  }

  // Delete an employee (Admin only)
  static Future<bool> deleteEmployee(String employeeId, String token) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/employees/$employeeId/'),
      headers: getHeaders(token),
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return true;
    } else {
      throw Exception('Failed to delete employee: ${response.statusCode}');
    }
  }

  // Update employee status (Admin only)
  static Future<bool> updateEmployeeStatus(
      String employeeId, bool isActive, String token) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/employees/$employeeId/'),
      headers: getHeaders(token),
      body: json.encode({'is_active': isActive}),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception(
          'Failed to update employee status: ${response.statusCode}');
    }
  }

  // Update an employee (Admin only)
  static Future<bool> updateEmployee(String employeeId,
      Map<String, dynamic> employeeData, String token) async {
    final response = await http.put(
      Uri.parse('$baseUrl/employees/$employeeId/'),
      headers: getHeaders(token),
      body: json.encode(employeeData),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to update employee: ${response.statusCode}');
    }
  }
}

class HRDashboard extends StatefulWidget {
  final String authToken;
  final Map<String, dynamic> userData;

  const HRDashboard(
      {super.key, required this.authToken, required this.userData});

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String searchQuery = "";
  String employeeFilter = "All"; // "All", "Active", "Inactive"
  List<Map<String, dynamic>> employees = [];
  bool isLoading = true;
  Map<String, dynamic>? selectedEmployee;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final employeesData =
          await EmployeeService.getEmployees(widget.authToken);

      setState(() {
        employees = employeesData;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _addEmployee(Map<String, dynamic> newEmployee) async {
    setState(() => isLoading = true);
    try {
      await EmployeeService.addEmployee(newEmployee, widget.authToken);
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${newEmployee['fullName']} added successfully'),
            backgroundColor: Colors.green),
      );
      _tabController.animateTo(2);
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to add employee: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _toggleEmployeeStatus(
      String employeeId, String name, bool currentStatus) async {
    setState(() => isLoading = true);
    try {
      await EmployeeService.updateEmployeeStatus(
          employeeId, !currentStatus, widget.authToken);
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$name status updated'),
            backgroundColor: Colors.orange),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update employee status: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _deleteEmployee(String employeeId, String name) async {
    setState(() => isLoading = true);
    try {
      await EmployeeService.deleteEmployee(employeeId, widget.authToken);
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$name deleted successfully'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to delete employee: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _showEmployeeDetails(Map<String, dynamic> employee) {
    setState(() => selectedEmployee = employee);
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
          onToggleStatus: () {
            Navigator.of(context).pop();
            _toggleEmployeeStatus(employee['employee_id'], employee['fullName'],
                employee['is_active']);
          },
          onDelete: () {
            Navigator.of(context).pop();
            _showDeleteConfirmation(
                employee['employee_id'], employee['fullName']);
          },
          onEdit: () {
            Navigator.of(context).pop();
            _showEditEmployeeDialog(context, employee);
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(String employeeId, String name) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Confirm Delete",
              style: TextStyle(color: Colors.white)),
          content: Text(
              "Are you sure you want to delete $name? This action cannot be undone.",
              style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteEmployee(employeeId, name);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showEditEmployeeDialog(
      BuildContext context, Map<String, dynamic> employee) {
    final employeeIdController =
        TextEditingController(text: employee["employee_id"]);
    final emailController = TextEditingController(text: employee["email"]);
    final fullNameController =
        TextEditingController(text: employee["fullName"]);
    final departmentController =
        TextEditingController(text: employee["department"] ?? "");
    final phoneController =
        TextEditingController(text: employee["phone_number"] ?? "");
    final aadharController =
        TextEditingController(text: employee["aadhar_card"] ?? "");
    final reportingIdController =
        TextEditingController(text: employee["report_to"] ?? "");
    String selectedRole = employee["role"] ?? "Common";

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
                      "Edit Employee",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // All fields in a single column
                  _buildTextField(
                    employeeIdController,
                    "Employee ID",
                    Icons.badge,
                    enabled: false, // Employee ID should not be editable
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    fullNameController,
                    "Full Name",
                    Icons.person,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    emailController,
                    "Email ID",
                    Icons.email,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    phoneController,
                    "Phone No",
                    Icons.phone,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    departmentController,
                    "Department",
                    Icons.business,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    aadharController,
                    "Aadhar No",
                    Icons.credit_card,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    reportingIdController,
                    "Reporting ID",
                    Icons.supervisor_account,
                  ),
                  const SizedBox(height: 12),
                  // Role dropdown
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E1E1E),
                    value: selectedRole,
                    items:
                        ["Common", "HR", "CEO", "Finance"].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      selectedRole = newValue!;
                    },
                    decoration: InputDecoration(
                      labelText: "Role",
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(
                        Icons.work,
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
                          onPressed: () async {
                            if (fullNameController.text.isEmpty ||
                                emailController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Full Name and Email are required',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            final updatedEmployee = {
                              "employee_id": employeeIdController.text,
                              "email": emailController.text,
                              "fullName": fullNameController.text,
                              "department": departmentController.text,
                              "phone_number": phoneController.text,
                              "aadhar_card": aadharController.text,
                              "report_to": reportingIdController.text,
                              "role": selectedRole,
                              "is_active":
                                  employee["is_active"], // Preserve status
                            };

                            setState(() => isLoading = true);
                            try {
                              await EmployeeService.updateEmployee(
                                  employee["employee_id"],
                                  updatedEmployee,
                                  widget.authToken);
                              await _loadData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '${fullNameController.text} updated successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              Navigator.of(context).pop();
                            } catch (e) {
                              setState(() => isLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Failed to update employee: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Update Employee",
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
            child: Center(
              child: Text(
                widget.userData['role'] ?? "HR",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
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
        employees.where((e) => e["is_active"] == true).length;
    final inactiveEmployees =
        employees.where((e) => e["is_active"] == false).length;

    final stats = [
      {
        "title": "Total Employees",
        "value": employees.length,
        "color": const Color.fromARGB(255, 61, 166, 182),
        "icon": Icons.group,
      },
      {
        "title": "Active Employees",
        "value": activeEmployees,
        "color": const Color.fromARGB(255, 87, 178, 68),
        "icon": Icons.check_circle,
      },
      {
        "title": "Left Employees",
        "value": inactiveEmployees,
        "color": const Color.fromARGB(255, 209, 111, 104),
        "icon": Icons.exit_to_app,
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
              e["fullName"].toLowerCase().contains(searchQuery.toLowerCase()) ||
              e["department"]
                      ?.toLowerCase()
                      .contains(searchQuery.toLowerCase()) ==
                  true ||
              e["employee_id"]
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()),
        )
        .toList();

    // Apply status filter
    // Apply status/department filter
    if (employeeFilter != "All") {
      if (["Active", "Inactive"].contains(employeeFilter)) {
        filteredEmployees = filteredEmployees
            .where((e) => employeeFilter == "Active"
                ? e["is_active"] == true
                : e["is_active"] == false)
            .toList();
      } else {
        // Department filter
        filteredEmployees = filteredEmployees
            .where(
                (e) => (e["department"] ?? "").toUpperCase() == employeeFilter)
            .toList();
      }
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
                    border: Border.all(color: Colors.white12),
                  ),
                  child: PopupMenuButton<String>(
                    onSelected: (value) {
                      setState(() {
                        employeeFilter = value;
                      });
                    },
                    color: const Color(0xFF2A2A2A), // Dark popup background
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 4), // internal padding
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: "All",
                        height: 36,
                        child: Text(
                          "All Employees",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ), // white text)),
                      const PopupMenuItem<String>(
                        value: "Active",
                        height: 36,
                        child: Text(
                          "Active Only",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ), // white text)),
                      const PopupMenuItem<String>(
                        value: "Inactive",
                        height: 36,
                        child: Text(
                          "Inactive Only",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ), // )),
                      const PopupMenuItem<String>(
                        value: "MIPL",
                        height: 36,
                        child: Text(
                          "MIPL",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ), // )),
                      const PopupMenuItem<String>(
                          value: "MIPPL",
                          height: 36,
                          child: Text(
                            "MIPPL",
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          )),
                      const PopupMenuItem<String>(
                        value: "MINPL",
                        height: 36,
                        child: Text(
                          "MINPL",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ), // )),
                      const PopupMenuItem<String>(
                        value: "MTIPL",
                        height: 36,
                        child: Text(
                          "MTIPL",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ), // )),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Text(employeeFilter,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              )),
                          const Icon(Icons.arrow_drop_down,
                              color: Colors.white),
                        ],
                      ),
                    ),
                  )),
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
                    e["fullName"],
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${e["role"] ?? "Employee"} - ${e["department"] ?? "No Department"}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        "ID: ${e["employee_id"]}",
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
                      color: e["is_active"] == true ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      e["is_active"] == true ? "Active" : "Inactive",
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
    final employeeIdController = TextEditingController();
    final emailController = TextEditingController();
    final fullNameController = TextEditingController();
    final departmentController = TextEditingController();
    final phoneController = TextEditingController();
    final aadharController = TextEditingController();
    final reportingIdController = TextEditingController();
    String selectedRole = "Common";

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
                  // All fields in a single column
                  _buildTextField(
                    employeeIdController,
                    "Employee ID",
                    Icons.badge,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    fullNameController,
                    "Full Name",
                    Icons.person,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    emailController,
                    "Email ID",
                    Icons.email,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    phoneController,
                    "Phone No",
                    Icons.phone,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    departmentController,
                    "Department",
                    Icons.business,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    aadharController,
                    "Aadhar No",
                    Icons.credit_card,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    reportingIdController,
                    "Reporting ID",
                    Icons.supervisor_account,
                  ),
                  const SizedBox(height: 12),
                  // Role dropdown
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E1E1E),
                    value: selectedRole,
                    items:
                        ["Common", "HR", "CEO", "Finance"].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      selectedRole = newValue!;
                    },
                    decoration: InputDecoration(
                      labelText: "Role",
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(
                        Icons.work,
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
                            if (employeeIdController.text.isEmpty ||
                                fullNameController.text.isEmpty ||
                                emailController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Employee ID, Full Name, and Email are required',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            final newEmployee = {
                              "employee_id": employeeIdController.text,
                              "email": emailController.text,
                              "fullName": fullNameController.text,
                              "department": departmentController.text,
                              "phone_number": phoneController.text,
                              "aadhar_card": aadharController.text,
                              "report_to": reportingIdController.text,
                              "role": selectedRole,
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
    IconData icon, {
    bool isPassword = false,
    bool enabled = true, //
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
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
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          "No recent activity",
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      ),
    );
  }
}

class EmployeeDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;
  final VoidCallback onEdit; // Add this callback

  const EmployeeDetailsSheet({
    super.key,
    required this.employee,
    required this.onToggleStatus,
    required this.onDelete,
    required this.onEdit, // Add this parameter
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
                    backgroundColor: employee["is_active"] == true
                        ? Colors.green
                        : Colors.red,
                    child: Text(
                      employee["fullName"].substring(0, 1),
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
                          employee["fullName"],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${employee["role"] ?? "Employee"} - ${employee["department"] ?? "No Department"}",
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
                            color: employee["is_active"] == true
                                ? Colors.green
                                : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            employee["is_active"] == true
                                ? "Active"
                                : "Inactive",
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
              _buildDetailRow("Employee ID", employee["employee_id"]),
              _buildDetailRow("Email", employee["email"]),
              _buildDetailRow(
                  "Phone", employee["phone_number"] ?? "Not provided"),
              _buildDetailRow(
                  "Aadhar No", employee["aadhar_card"] ?? "Not provided"),
              _buildDetailRow(
                  "Department", employee["department"] ?? "Not assigned"),
              _buildDetailRow("Role", employee["role"] ?? "Employee"),
              _buildDetailRow(
                  "Reporting ID", employee["report_to"] ?? "Not assigned"),
              const SizedBox(height: 24),
              // EDIT BUTTON - Added here
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 161, 125, 224),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Edit Employee",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onToggleStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: employee["is_active"] == true
                        ? const Color.fromARGB(255, 219, 127, 74)
                        : const Color.fromARGB(255, 109, 226, 113),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    employee["is_active"] == true
                        ? "Deactivate Employee"
                        : "Activate Employee",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 233, 107, 98),
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
              // REMOVED the Close button as requested
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
        ));
  }
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
      ));
}
