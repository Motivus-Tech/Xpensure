import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'hr_request_details.dart';
import 'common_dashboard.dart';

// Activity Service
class ActivityService {
  static const String _activityKey = 'hr_activities';

  static Future<void> saveActivities(List<ActivityItem> activities) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> activityStrings = activities.map((activity) {
        return json.encode({
          'description': activity.description,
          'iconCode': Icons.history.codePoint,
          'colorValue': activity.color.value,
          'timestamp': activity.timestamp.toIso8601String(),
        });
      }).toList();

      await prefs.setStringList(_activityKey, activityStrings);
    } catch (e) {
      debugPrint('Failed to save activities: $e');
    }
  }

  static Future<List<ActivityItem>> loadActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? activityStrings = prefs.getStringList(_activityKey);

      if (activityStrings == null) return [];

      return activityStrings.map((String activityString) {
        final Map<String, dynamic> activityMap = json.decode(activityString);
        return ActivityItem(
          description: activityMap['description'],
          icon: Icons.history,
          color: Color(activityMap['colorValue']),
          timestamp: DateTime.parse(activityMap['timestamp']),
        );
      }).toList();
    } catch (e) {
      debugPrint('Failed to load activities: $e');
      return [];
    }
  }

  static Future<void> addActivity(ActivityItem activity) async {
    final List<ActivityItem> existingActivities = await loadActivities();
    existingActivities.insert(0, activity);

    if (existingActivities.length > 100) {
      existingActivities.removeRange(100, existingActivities.length);
    }

    await saveActivities(existingActivities);
  }

  static Future<void> clearActivities() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activityKey);
  }
}

// Notification Service
class NotificationService {
  static const String _notificationKey = 'hr_notifications';

  static Future<void> saveNotifications(
      List<NotificationItem> notifications) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> notificationStrings =
          notifications.map((notification) {
        return json.encode({
          'title': notification.title,
          'message': notification.message,
          'type': notification.type,
          'timestamp': notification.timestamp.toIso8601String(),
          'isRead': notification.isRead,
        });
      }).toList();

      await prefs.setStringList(_notificationKey, notificationStrings);
    } catch (e) {
      debugPrint('Failed to save notifications: $e');
    }
  }

  static Future<List<NotificationItem>> loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? notificationStrings =
          prefs.getStringList(_notificationKey);

      if (notificationStrings == null) return [];

      return notificationStrings.map((String notificationString) {
        final Map<String, dynamic> notificationMap =
            json.decode(notificationString);
        return NotificationItem(
          title: notificationMap['title'],
          message: notificationMap['message'],
          type: notificationMap['type'],
          timestamp: DateTime.parse(notificationMap['timestamp']),
          isRead: notificationMap['isRead'] ?? false,
        );
      }).toList();
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
      return [];
    }
  }

  static Future<void> addNotification(NotificationItem notification) async {
    final List<NotificationItem> existingNotifications =
        await loadNotifications();
    existingNotifications.insert(0, notification);

    if (existingNotifications.length > 50) {
      existingNotifications.removeRange(50, existingNotifications.length);
    }

    await saveNotifications(existingNotifications);
  }

  static Future<void> markAsRead(int index) async {
    final List<NotificationItem> notifications = await loadNotifications();
    if (index >= 0 && index < notifications.length) {
      notifications[index].isRead = true;
      await saveNotifications(notifications);
    }
  }

  static Future<void> markAllAsRead() async {
    final List<NotificationItem> notifications = await loadNotifications();
    for (var notification in notifications) {
      notification.isRead = true;
    }
    await saveNotifications(notifications);
  }

  static Future<void> clearAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationKey);
  }

  static Future<int> getUnreadCount() async {
    final List<NotificationItem> notifications = await loadNotifications();
    return notifications.where((notification) => !notification.isRead).length;
  }
}

// CSV Service
class CSVService {
  static Future<File> generateEmployeeCSV(List<Map<String, dynamic>> employees,
      {String period = 'All Time'}) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/employee_report_$timestamp.csv');

    final csvHeader = [
      'Employee ID',
      'Full Name',
      'Email',
      'Department',
      'Role',
      'Phone Number',
      'Aadhar Card',
      'Reporting To',
      'Status',
      'Join Date',
      'Last Updated'
    ].join(',');

    final csvRows = employees.map((employee) {
      return [
        _escapeCSV(employee['employee_id']?.toString() ?? ''),
        _escapeCSV(employee['fullName']?.toString() ?? ''),
        _escapeCSV(employee['email']?.toString() ?? ''),
        _escapeCSV(employee['department']?.toString() ?? 'Not Assigned'),
        _escapeCSV(employee['role']?.toString() ?? 'Employee'),
        _escapeCSV(employee['phone_number']?.toString() ?? 'Not Provided'),
        _escapeCSV(employee['aadhar_card']?.toString() ?? 'Not Provided'),
        _escapeCSV(employee['report_to']?.toString() ?? 'Not Assigned'),
        employee['is_active'] == true ? 'Active' : 'Inactive',
        _formatDate(employee['created_at']?.toString()),
        _formatDate(employee['updated_at']?.toString()),
      ].join(',');
    }).toList();

    final reportHeader = [
      'Xpensure HR Employee Report',
      'Generated on: ${DateTime.now().toString()}',
      'Report Period: $period',
      'Total Employees: ${employees.length}',
      'Active Employees: ${employees.where((e) => e['is_active'] == true).length}',
      'Inactive Employees: ${employees.where((e) => e['is_active'] == false).length}',
      '',
    ].join('\n');

    final csvContent = '$reportHeader\n$csvHeader\n${csvRows.join('\n')}';

    await file.writeAsString(csvContent);
    return file;
  }

  static String _escapeCSV(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  static String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Not Available';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  static List<Map<String, dynamic>> filterEmployeesByPeriod(
      List<Map<String, dynamic>> employees, String period) {
    final now = DateTime.now();

    switch (period) {
      case 'Last 6 Months':
        final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
        return employees.where((employee) {
          final createdAt = _parseDate(employee['created_at']?.toString());
          return createdAt != null && createdAt.isAfter(sixMonthsAgo);
        }).toList();

      case 'Last 1 Year':
        final oneYearAgo = DateTime(now.year - 1, now.month, now.day);
        return employees.where((employee) {
          final createdAt = _parseDate(employee['created_at']?.toString());
          return createdAt != null && createdAt.isAfter(oneYearAgo);
        }).toList();

      case 'All Time':
      default:
        return employees;
    }
  }

  static DateTime? _parseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }
}

// Backend Service
class EmployeeService {
  static const String baseUrl = "http://10.0.2.2:8000/api";

  static Map<String, String> getHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

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

  static Future<Map<String, dynamic>> uploadEmployeeAvatar(
    String employeeId,
    File imageFile,
    String token,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/employees/$employeeId/upload-avatar/'),
      );

      request.headers['Authorization'] = 'Token $token';
      request.files.add(
        await http.MultipartFile.fromPath(
          'avatar',
          imageFile.path,
          filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to upload avatar: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Avatar upload error: $e');
    }
  }

  static Future<Map<String, dynamic>> updateEmployeeWithAvatar(
    String employeeId,
    Map<String, dynamic> employeeData,
    File? avatarFile,
    String token,
  ) async {
    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/employees/$employeeId/'),
      );

      request.headers['Authorization'] = 'Token $token';
      final Map<String, String> processedData = {};

      if (employeeData['email'] != null) {
        processedData['email'] = employeeData['email'].toString();
      }
      if (employeeData['fullName'] != null) {
        processedData['fullName'] = employeeData['fullName'].toString();
      }
      if (employeeData['department'] != null) {
        processedData['department'] = employeeData['department'].toString();
      }
      if (employeeData['phone_number'] != null) {
        processedData['phone_number'] = employeeData['phone_number'].toString();
      }
      if (employeeData['aadhar_card'] != null) {
        processedData['aadhar_card'] = employeeData['aadhar_card'].toString();
      }
      if (employeeData['report_to'] != null) {
        processedData['report_to'] = employeeData['report_to'].toString();
      }
      if (employeeData['role'] != null) {
        processedData['role'] = employeeData['role'].toString();
      }
      if (employeeData['is_active'] != null) {
        processedData['is_active'] = employeeData['is_active'].toString();
      }
      if (employeeData['employee_id'] != null) {
        processedData['employee_id'] = employeeData['employee_id'].toString();
      }

      processedData.forEach((key, value) {
        request.fields[key] = value;
      });

      if (avatarFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            avatarFile.path,
            filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Failed to update employee: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Update employee error: $e');
    }
  }

  static Future<Map<String, dynamic>> addEmployeeWithAvatar(
    Map<String, dynamic> employeeData,
    File? avatarFile,
    String token,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/employees/'),
      );

      request.headers['Authorization'] = 'Token $token';
      final Map<String, String> processedData = {};

      if (employeeData['employee_id'] != null) {
        processedData['employee_id'] = employeeData['employee_id'].toString();
      }
      if (employeeData['email'] != null) {
        processedData['email'] = employeeData['email'].toString();
      }
      if (employeeData['fullName'] != null) {
        processedData['fullName'] = employeeData['fullName'].toString();
      }
      if (employeeData['department'] != null) {
        processedData['department'] = employeeData['department'].toString();
      }
      if (employeeData['phone_number'] != null) {
        processedData['phone_number'] = employeeData['phone_number'].toString();
      } else {
        processedData['phone_number'] = '';
      }
      if (employeeData['aadhar_card'] != null) {
        processedData['aadhar_card'] = employeeData['aadhar_card'].toString();
      } else {
        processedData['aadhar_card'] = '';
      }
      if (employeeData['report_to'] != null) {
        processedData['report_to'] = employeeData['report_to'].toString();
      } else {
        processedData['report_to'] = '';
      }
      if (employeeData['role'] != null) {
        processedData['role'] = employeeData['role'].toString();
      } else {
        processedData['role'] = 'Common';
      }

      processedData['password'] = 'DefaultPassword123!';
      processedData['confirm_password'] = 'DefaultPassword123!';

      processedData.forEach((key, value) {
        request.fields[key] = value;
      });

      if (avatarFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            avatarFile.path,
            filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Failed to add employee: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Add employee error: $e');
    }
  }
}

// HR Approval Service
class HRApprovalService {
  static const String baseUrl = "http://10.0.2.2:8000/api";

  static Map<String, String> getHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  static Future<Map<String, dynamic>> getRequestDetails(
      String requestId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/requests/$requestId/details/'),
        headers: getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data;
      } else {
        throw Exception(
            'Failed to fetch request details: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Request details fetch error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getHRPendingApprovals(
      String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/requests/hr-pending/'),
        headers: getHeaders(token),
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);

        if (data is List) {
          return data.map((e) => e as Map<String, dynamic>).toList();
        } else if (data is Map<String, dynamic>) {
          if (data.containsKey('results')) {
            final List<dynamic> results = data['results'];
            return results.map((e) => e as Map<String, dynamic>).toList();
          } else {
            return [];
          }
        } else {
          return [];
        }
      } else {
        throw Exception(
            'Failed to fetch HR pending approvals: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('HR approval fetch error: $e');
    }
  }

  static Future<bool> approveRequest(String requestId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/requests/$requestId/hr-approve/'),
        headers: getHeaders(token),
        body: json.encode({
          'comments': 'Approved by HR',
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
            'Failed to approve request: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('HR approval error: $e');
    }
  }

  static Future<bool> rejectRequest(String requestId, String token,
      {required String rejectionReason}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/requests/$requestId/hr-reject/'),
        headers: getHeaders(token),
        body: json.encode({
          'rejection_reason': rejectionReason,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
            'Failed to reject request: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('HR rejection error: $e');
    }
  }
}

class HRDashboard extends StatefulWidget {
  final String authToken;
  final Map<String, dynamic> userData;
  final VoidCallback onLogout;

  const HRDashboard({
    super.key,
    required this.authToken,
    required this.userData,
    required this.onLogout,
  });

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String searchQuery = "";
  String employeeFilter = "All";
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> hrPendingApprovals = [];
  bool isLoading = true;
  Map<String, dynamic>? selectedEmployee;
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  String? _selectedImagePath;
  List<ActivityItem> activityLog = [];
  List<NotificationItem> notifications = [];
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
    _loadHRApprovals();
    _loadActivities();
    _loadNotifications();
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

  Future<void> _loadHRApprovals() async {
    try {
      if (widget.userData['role'] == 'HR') {
        final approvals =
            await HRApprovalService.getHRPendingApprovals(widget.authToken);
        setState(() {
          hrPendingApprovals = approvals;
        });
      }
    } catch (e) {
      debugPrint('Failed to load HR approvals: $e');
    }
  }

  Future<void> _loadActivities() async {
    try {
      final List<ActivityItem> savedActivities =
          await ActivityService.loadActivities();
      setState(() {
        activityLog = savedActivities;
      });
    } catch (e) {
      debugPrint('Failed to load activities: $e');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final List<NotificationItem> savedNotifications =
          await NotificationService.loadNotifications();
      final int unread = await NotificationService.getUnreadCount();
      setState(() {
        notifications = savedNotifications;
        unreadCount = unread;
      });
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _selectedImagePath = pickedFile.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addEmployee(Map<String, dynamic> newEmployee, File? avatarFile) async {
    setState(() => isLoading = true);
    try {
      await EmployeeService.addEmployeeWithAvatar(
          newEmployee, avatarFile, widget.authToken);
      await _loadData();

      _addActivity(
        "Added new employee: ${newEmployee['fullName']}",
        Icons.person_add,
        Colors.green,
      );

      _addNotification(
        "New Employee Added",
        "${newEmployee['fullName']} has been added to the system.",
        "success",
      );

      setState(() {
        _selectedImage = null;
        _selectedImagePath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newEmployee['fullName']} added successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _tabController.animateTo(2);
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add employee: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateEmployee(String employeeId, Map<String, dynamic> employeeData,
      File? avatarFile) async {
    setState(() => isLoading = true);
    try {
      await EmployeeService.updateEmployeeWithAvatar(
        employeeId,
        employeeData,
        avatarFile,
        widget.authToken,
      );
      await _loadData();

      _addActivity(
        "Updated employee: ${employeeData['fullName']}",
        Icons.edit,
        Colors.blue,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${employeeData['fullName']} updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update employee: $e'),
          backgroundColor: Colors.red,
        ),
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

      _addActivity(
        "${!currentStatus ? 'Activated' : 'Deactivated'} employee: $name",
        !currentStatus ? Icons.check_circle : Icons.remove_circle,
        !currentStatus ? Colors.green : Colors.orange,
      );

      _addNotification(
        "Employee Status Updated",
        "$name has been ${!currentStatus ? 'activated' : 'deactivated'}.",
        "warning",
      );

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

      _addActivity(
        "Deleted employee: $name",
        Icons.delete,
        Colors.red,
      );

      _addNotification(
        "Employee Deleted",
        "$name has been removed from the system.",
        "error",
      );

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

  void _approveHRRequest(String requestId, String employeeName) async {
    setState(() => isLoading = true);
    try {
      await HRApprovalService.approveRequest(requestId, widget.authToken);
      await _loadHRApprovals();

      _addActivity(
        "Approved advance request for: $employeeName",
        Icons.check_circle,
        Colors.green,
      );

      _addNotification(
        "Advance Request Approved",
        "Advance request for $employeeName has been approved by HR.",
        "success",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Advance request for $employeeName approved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _rejectHRRequest(
      String requestId, String employeeName, String reason) async {
    setState(() => isLoading = true);
    try {
      await HRApprovalService.rejectRequest(requestId, widget.authToken,
          rejectionReason: reason);
      await _loadHRApprovals();

      _addActivity(
        "Rejected advance request for: $employeeName",
        Icons.cancel,
        Colors.red,
      );

      _addNotification(
        "Advance Request Rejected",
        "Advance request for $employeeName has been rejected by HR.",
        "error",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Advance request for $employeeName rejected'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRejectDialog(String requestId, String employeeName) {
    final TextEditingController reasonController = TextEditingController();

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Reject Advance Request",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Please provide reason for rejecting $employeeName's advance request:",
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Enter rejection reason...",
                    hintStyle: const TextStyle(color: Colors.white54),
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
                    ElevatedButton(
                      onPressed: () {
                        if (reasonController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please provide rejection reason'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).pop();
                        _rejectHRRequest(
                            requestId, employeeName, reasonController.text);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Reject",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadAndShareReport(String period) async {
    try {
      setState(() => isLoading = true);
      final filteredEmployees =
          CSVService.filterEmployeesByPeriod(employees, period);

      if (filteredEmployees.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('No employees found for the selected period: $period'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => isLoading = false);
        return;
      }

      final csvFile = await CSVService.generateEmployeeCSV(filteredEmployees,
          period: period);

      _addActivity(
        "Generated $period employee report (${filteredEmployees.length} employees)",
        Icons.download,
        Colors.purple,
      );

      _addNotification(
        "Report Generated",
        "$period employee report has been generated successfully.",
        "info",
      );

      await Share.shareXFiles(
        [XFile(csvFile.path, mimeType: 'text/csv')],
        text:
            'Xpensure HR Employee Report - $period\n\nTotal Employees: ${filteredEmployees.length}\nGenerated on: ${DateTime.now().toString()}',
        subject: 'Xpensure Employee Report - $period',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$period report generated and shared successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showReportOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            "Generate Employee Report",
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "Select the time period for the employee report:",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            _buildReportOptionButton("Last 6 Months", context),
            _buildReportOptionButton("Last 1 Year", context),
            _buildReportOptionButton("All Time", context),
          ],
        );
      },
    );
  }

  Widget _buildReportOptionButton(String period, BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.of(context).pop();
        _downloadAndShareReport(period);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.deepPurple, Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          period,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _addActivity(String description, IconData icon, Color color) async {
    final ActivityItem newActivity = ActivityItem(
      description: description,
      icon: icon,
      color: color,
      timestamp: DateTime.now(),
    );

    setState(() {
      activityLog.insert(0, newActivity);
      if (activityLog.length > 50) {
        activityLog.removeLast();
      }
    });

    try {
      await ActivityService.addActivity(newActivity);
    } catch (e) {
      debugPrint('Failed to save activity to storage: $e');
    }
  }

  void _addNotification(String title, String message, String type) async {
    final NotificationItem newNotification = NotificationItem(
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
    );

    try {
      await NotificationService.addNotification(newNotification);
      await _loadNotifications();
    } catch (e) {
      debugPrint('Failed to save notification: $e');
    }
  }

  Future<void> _clearAllActivities() async {
    try {
      await ActivityService.clearActivities();
      setState(() {
        activityLog.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All activities cleared'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear activities: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      await NotificationService.clearAllNotifications();
      await _loadNotifications();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications cleared'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear notifications: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markAllNotificationsAsRead() async {
    try {
      await NotificationService.markAllAsRead();
      await _loadNotifications();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark notifications as read: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Clear All Activities",
              style: TextStyle(color: Colors.white)),
          content: const Text(
              "Are you sure you want to clear all activity history?",
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearAllActivities();
              },
              child:
                  const Text("Clear All", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Notifications",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (notifications.isNotEmpty) ...[
                        TextButton(
                          onPressed: _markAllNotificationsAsRead,
                          child: const Text(
                            "Mark All Read",
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showClearNotificationsConfirmation();
                          },
                          child: const Text(
                            "Clear All",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: notifications.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_none,
                                size: 64,
                                color: Colors.white54,
                              ),
                              SizedBox(height: 16),
                              Text(
                                "No notifications",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                "Your notifications will appear here",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            return _buildNotificationItem(notification, index);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem(NotificationItem notification, int index) {
    Color getNotificationColor(String type) {
      switch (type) {
        case "success":
          return Colors.green;
        case "warning":
          return Colors.orange;
        case "error":
          return Colors.red;
        default:
          return Colors.blue;
      }
    }

    IconData getNotificationIcon(String type) {
      switch (type) {
        case "success":
          return Icons.check_circle;
        case "warning":
          return Icons.warning;
        case "error":
          return Icons.error;
        default:
          return Icons.info;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: notification.isRead
            ? const Color(0xFF2A2A2A)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: notification.isRead
            ? null
            : Border.all(
                color: getNotificationColor(notification.type), width: 1),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: getNotificationColor(notification.type).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            getNotificationIcon(notification.type),
            color: getNotificationColor(notification.type),
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            color: Colors.white,
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.message,
              style: const TextStyle(color: Colors.white70),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimeAgo(notification.timestamp),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: !notification.isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: getNotificationColor(notification.type),
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () async {
          if (!notification.isRead) {
            await NotificationService.markAsRead(index);
            await _loadNotifications();
          }
        },
      ),
    );
  }

  void _showClearNotificationsConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Clear All Notifications",
              style: TextStyle(color: Colors.white)),
          content: const Text(
              "Are you sure you want to clear all notifications?",
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearAllNotifications();
              },
              child:
                  const Text("Clear All", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
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

    ValueNotifier<File?> editSelectedImage = ValueNotifier<File?>(null);
    ValueNotifier<String?> editSelectedImagePath = ValueNotifier<String?>(null);
    String? currentAvatarUrl = employee['avatar_url'] ?? employee['avatar'];

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
                  Center(
                    child: Column(
                      children: [
                        ValueListenableBuilder<String?>(
                          valueListenable: editSelectedImagePath,
                          builder: (context, imagePath, child) {
                            return Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.deepPurple,
                                      width: 3,
                                    ),
                                  ),
                                  child: imagePath != null
                                      ? ClipOval(
                                          child: Image.file(
                                            File(imagePath),
                                            fit: BoxFit.cover,
                                            width: 94,
                                            height: 94,
                                          ),
                                        )
                                      : (currentAvatarUrl != null &&
                                              currentAvatarUrl.isNotEmpty
                                          ? ClipOval(
                                              child: Image.network(
                                                currentAvatarUrl,
                                                fit: BoxFit.cover,
                                                width: 94,
                                                height: 94,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return _buildFallbackAvatar(
                                                      employee["fullName"],
                                                      true);
                                                },
                                              ),
                                            )
                                          : Container(
                                              decoration: BoxDecoration(
                                                color: Colors.grey[800],
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.person,
                                                size: 50,
                                                color: Colors.grey,
                                              ),
                                            )),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF1E1E1E),
                                        width: 3,
                                      ),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.camera_alt,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      onPressed: () async {
                                        final XFile? pickedFile =
                                            await _imagePicker.pickImage(
                                          source: ImageSource.gallery,
                                          maxWidth: 800,
                                          maxHeight: 800,
                                          imageQuality: 80,
                                        );

                                        if (pickedFile != null) {
                                          editSelectedImage.value =
                                              File(pickedFile.path);
                                          editSelectedImagePath.value =
                                              pickedFile.path;
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<String?>(
                          valueListenable: editSelectedImagePath,
                          builder: (context, imagePath, child) {
                            return Text(
                              imagePath != null
                                  ? "New photo selected"
                                  : currentAvatarUrl != null &&
                                          currentAvatarUrl.isNotEmpty
                                      ? "Current photo"
                                      : "Add profile photo",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    employeeIdController,
                    "Employee ID",
                    Icons.badge,
                    enabled: false,
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
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E1E1E),
                    value: selectedRole,
                    items: [
                      "Common",
                      "HR",
                      "CEO",
                      "Finance Verification",
                      "Finance Payment"
                    ].map((String value) {
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
                              "is_active": employee["is_active"],
                            };

                            _updateEmployee(
                              employee["employee_id"],
                              updatedEmployee,
                              editSelectedImage.value,
                            );
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
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: "Refresh Data",
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _showLogoutConfirmation,
            tooltip: "Logout",
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.redAccent, Color.fromARGB(255, 226, 131, 102)],
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
          labelStyle: TextStyle(
            fontSize: MediaQuery.of(context).size.width < 360 ? 12 : 14,
          ),
          tabs: [
            const Tab(icon: Icon(Icons.dashboard), text: "Overview"),
            const Tab(icon: Icon(Icons.bar_chart), text: "Charts"),
            const Tab(icon: Icon(Icons.group), text: "Employees"),
            if (widget.userData['role'] == 'HR')
              const Tab(icon: Icon(Icons.approval), text: "Review"),
            const Tab(icon: Icon(Icons.history), text: "Activity"),
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
                if (widget.userData['role'] == 'HR') _buildHRApprovalTab(),
                _buildActivityTab(),
              ],
            ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            "Logout",
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "Are you sure you want to logout?",
            style: TextStyle(color: Colors.white70),
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
                widget.onLogout();
              },
              child: const Text(
                "Logout",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
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
      {
        "title": "Generate Report",
        "value": "CSV",
        "color": const Color.fromARGB(255, 147, 112, 219),
        "icon": Icons.download,
        "onTap": _showReportOptions,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;
                return GridView.builder(
                  itemCount: stats.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                  ),
                  itemBuilder: (context, index) {
                    final stat = stats[index];
                    return GestureDetector(
                      onTap: stat['onTap'] as void Function()?,
                      child: Container(
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
                                  radius: constraints.maxWidth < 400 ? 16 : 20,
                                  backgroundColor: stat["color"] as Color,
                                  child: Icon(
                                    stat["icon"] as IconData,
                                    color: Colors.white,
                                    size: constraints.maxWidth < 400 ? 16 : 20,
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              (stat["value"] as dynamic).toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: constraints.maxWidth < 400 ? 20 : 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stat["title"] as String,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: constraints.maxWidth < 400 ? 12 : 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsTab() {
    final departmentData = _getDepartmentData();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Department Distribution",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: MediaQuery.of(context).size.width < 400 ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadData,
                tooltip: "Refresh Charts",
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Real-time employee count by department",
            style: TextStyle(
              color: Colors.white70,
              fontSize: MediaQuery.of(context).size.width < 400 ? 12 : 14,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: PieChart(
                PieChartData(
                  sections: _buildPieChartSections(departmentData),
                  centerSpaceRadius:
                      MediaQuery.of(context).size.width < 400 ? 30 : 40,
                  sectionsSpace: 4,
                  startDegreeOffset: 180,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Department Statistics",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: MediaQuery.of(context).size.width < 400 ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...departmentData.map((dept) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getDepartmentColor(dept.department),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              dept.department,
                              style: const TextStyle(color: Colors.white70),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "${dept.count} employees",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(List<DepartmentData> data) {
    final totalEmployees = data.fold(0, (sum, item) => sum + item.count);

    return data.map((dept) {
      final percentage = (dept.count / totalEmployees * 100).toStringAsFixed(1);

      return PieChartSectionData(
        color: _getDepartmentColor(dept.department),
        value: dept.count.toDouble(),
        title: '${dept.count}',
        radius: MediaQuery.of(context).size.width < 400 ? 50 : 60,
        titleStyle: TextStyle(
          fontSize: MediaQuery.of(context).size.width < 400 ? 12 : 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$percentage%',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width < 400 ? 8 : 10,
              color: Colors.white,
            ),
          ),
        ),
        badgePositionPercentageOffset: 0.98,
      );
    }).toList();
  }

  List<DepartmentData> _getDepartmentData() {
    final departmentCount = <String, int>{};

    for (final employee in employees) {
      final department = employee["department"] ?? "No Department";
      departmentCount[department] = (departmentCount[department] ?? 0) + 1;
    }

    return departmentCount.entries
        .map((entry) => DepartmentData(entry.key, entry.value))
        .toList();
  }

  Color _getDepartmentColor(String department) {
    final colors = {
      "MIPL": const Color.fromARGB(255, 132, 222, 122),
      "MIPPL": const Color.fromARGB(255, 103, 168, 221),
      "MINPL": const Color.fromARGB(255, 249, 222, 52),
      "MTIPL": const Color.fromARGB(255, 238, 99, 89),
      "No Department": const Color.fromARGB(255, 221, 108, 240),
    };

    return colors[department] ?? const Color.fromARGB(255, 146, 84, 239);
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

    if (employeeFilter != "All") {
      if (["Active", "Inactive"].contains(employeeFilter)) {
        filteredEmployees = filteredEmployees
            .where((e) => employeeFilter == "Active"
                ? e["is_active"] == true
                : e["is_active"] == false)
            .toList();
      } else {
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 600;

              if (isSmallScreen) {
                return Column(
                  children: [
                    TextField(
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
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
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
                              color: const Color(0xFF2A2A2A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemBuilder: (BuildContext context) => [
                                const PopupMenuItem<String>(
                                  value: "All",
                                  height: 36,
                                  child: Text(
                                    "All Employees",
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 14),
                                  ),
                                ),
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
                                ),
                                const PopupMenuItem<String>(
                                  value: "Inactive",
                                  height: 36,
                                  child: Text(
                                    "Inactive Only",
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 14),
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: "MIPL",
                                  height: 36,
                                  child: Text(
                                    "MIPL",
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 14),
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                    value: "MIPPL",
                                    height: 36,
                                    child: Text(
                                      "MIPPL",
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 14),
                                    )),
                                const PopupMenuItem<String>(
                                  value: "MINPL",
                                  height: 36,
                                  child: Text(
                                    "MINPL",
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 14),
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: "MTIPL",
                                  height: 36,
                                  child: Text(
                                    "MTIPL",
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              ],
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        employeeFilter,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down,
                                        color: Colors.white),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F1F1F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon:
                                const Icon(Icons.refresh, color: Colors.white),
                            onPressed: _loadData,
                            tooltip: "Refresh Employees",
                          ),
                        ),
                        const SizedBox(width: 8),
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
                            icon: const Icon(Icons.person_add,
                                color: Colors.white),
                            onPressed: () {
                              _showAddEmployeeDialog(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                return Row(
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
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.white54),
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
                          color: const Color(0xFF2A2A2A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem<String>(
                              value: "All",
                              height: 36,
                              child: Text(
                                "All Employees",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                            ),
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
                            ),
                            const PopupMenuItem<String>(
                              value: "Inactive",
                              height: 36,
                              child: Text(
                                "Inactive Only",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: "MIPL",
                              height: 36,
                              child: Text(
                                "MIPL",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                            ),
                            const PopupMenuItem<String>(
                                value: "MIPPL",
                                height: 36,
                                child: Text(
                                  "MIPPL",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14),
                                )),
                            const PopupMenuItem<String>(
                              value: "MINPL",
                              height: 36,
                              child: Text(
                                "MINPL",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: "MTIPL",
                              height: 36,
                              child: Text(
                                "MTIPL",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                            ),
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
                        color: const Color(0xFF1F1F1F),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _loadData,
                        tooltip: "Refresh Employees",
                      ),
                    ),
                    const SizedBox(width: 8),
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
                );
              }
            },
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
                  leading: _buildEmployeeAvatar(e),
                  title: Text(
                    e["fullName"],
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${e["role"] ?? "Employee"} - ${e["department"] ?? "No Department"}",
                        style: const TextStyle(color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildEmployeeAvatar(Map<String, dynamic> employee) {
    final String? avatarUrl = employee['avatar_url'] ?? employee['avatar'];
    final String fullName = employee['fullName'] ?? 'Employee';
    final bool isActive = employee['is_active'] == true;

    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? Colors.green : Colors.red,
              width: 2,
            ),
          ),
          child: avatarUrl != null && avatarUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    width: 46,
                    height: 46,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildFallbackAvatar(fullName, isActive);
                    },
                  ),
                )
              : _buildFallbackAvatar(fullName, isActive),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.red,
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF1F1F1F),
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackAvatar(String fullName, bool isActive) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: isActive
            ? Colors.blue.withOpacity(0.2)
            : Colors.grey.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
          style: TextStyle(
            color: isActive ? Colors.blue : Colors.grey,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHRApprovalTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Advance Requests Pending HR Approval",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: MediaQuery.of(context).size.width < 400 ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadHRApprovals,
                tooltip: "Refresh HR Approvals",
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Review and approve/reject advance requests",
            style: TextStyle(
              color: Colors.white70,
              fontSize: MediaQuery.of(context).size.width < 400 ? 12 : 14,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: hrPendingApprovals.isEmpty
                ? Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1F1F),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF2D2D2D),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange.withOpacity(0.1),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_circle_outline,
                              size: 40,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "All Caught Up!",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "No pending advance requests for approval",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadHRApprovals,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.withOpacity(0.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            icon: const Icon(
                              Icons.refresh,
                              size: 16,
                              color: Colors.orange,
                            ),
                            label: const Text(
                              "Check Again",
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: hrPendingApprovals.length,
                    itemBuilder: (context, index) {
                      final request = hrPendingApprovals[index];
                      return _buildHRApprovalItem(request);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown date';
    try {
      if (date is String) {
        final dateTime = DateTime.parse(date);
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } else if (date is DateTime) {
        return '${date.day}/${date.month}/${date.year}';
      }
      return 'Invalid date format';
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _viewRequestDetails(Map<String, dynamic> requestData) async {
    try {
      setState(() => isLoading = true);
      final detailedRequest = await HRApprovalService.getRequestDetails(
        requestData['id'].toString(),
        widget.authToken,
      );

      setState(() => isLoading = false);
      final request = detailedRequest['request'] as Map<String, dynamic>? ??
          detailedRequest;

      double parseAmount(dynamic amount) {
        if (amount == null) return 0.0;
        if (amount is double) return amount;
        if (amount is int) return amount.toDouble();
        if (amount is String) {
          try {
            return double.parse(amount);
          } catch (e) {
            return 0.0;
          }
        }
        return 0.0;
      }

      final amount = parseAmount(request['amount']);
      final purpose =
          request['purpose'] ?? request['description'] ?? 'Not specified';
      final paymentData = _createPaymentDataFromRequest(detailedRequest);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => HrRequestDetails(
            request: Request(
              id: int.tryParse(request['id']?.toString() ?? '0') ?? 0,
              employeeId: request['employee_id']?.toString() ?? '',
              employeeName: request['employee_name']?.toString() ?? '',
              submissionDate: _formatDate(request['created_at']),
              amount: amount,
              description: purpose,
              payments: paymentData,
              requestType: 'Advance',
              avatarUrl: requestData['employee_avatar'],
            ),
            authToken: widget.authToken,
          ),
        ),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading request details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _createPaymentDataFromRequest(
      dynamic requestData) {
    Map<String, dynamic> data;
    if (requestData is Map<String, dynamic>) {
      data = requestData;
    } else {
      data = requestData as Map<String, dynamic>;
    }

    final request = data['request'] as Map<String, dynamic>? ?? {};

    return [
      {
        'amount': request['amount']?.toString() ?? '0',
        'particulars': request['purpose'] ?? request['description'] ?? '',
        'purpose': request['purpose'] ?? '',
        'description': request['purpose'] ?? '',
        'project_id': request['project_id'] ?? '',
        'project_name': request['project_name'] ?? '',
        'project_date': request['project_date'] ?? '',
        'request_date': request['request_date'] ?? request['created_at'] ?? '',
        'projectId': request['project_id'] ?? '',
        'projectName': request['project_name'] ?? '',
        'projectDate': request['project_date'] ?? '',
        'requestDate': request['request_date'] ?? request['created_at'] ?? '',
        'attachmentPaths': _getAttachmentPathsFromRequest(data),
      }
    ];
  }

  List<String> _getAttachmentPathsFromRequest(dynamic requestData) {
    final attachments = <String>[];
    Map<String, dynamic> data;
    if (requestData is Map<String, dynamic>) {
      data = requestData;
    } else {
      data = requestData as Map<String, dynamic>;
    }

    if (data.containsKey('attachments') && data['attachments'] is List) {
      for (var attachment in data['attachments'] as List) {
        if (attachment != null && attachment.toString().isNotEmpty) {
          attachments.add(attachment.toString());
        }
      }
    }

    return attachments;
  }

  Widget _buildHRApprovalItem(Map<String, dynamic> request) {
    final employeeName = request['employee_name'] ??
        request['employeeName'] ??
        'Unknown Employee';
    final requestId = request['id']?.toString() ?? '';
    final amount = request['amount']?.toString() ?? '0';
    final purpose =
        request['purpose'] ?? request['description'] ?? 'Not specified';
    final double amountValue = double.tryParse(amount) ?? 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2D2D2D),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    employeeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "₹${amountValue.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 8),
                _buildInfoChip(
                  icon: Icons.calendar_today,
                  text: _formatDate(request['created_at']),
                  color: Colors.teal,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.description,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      purpose,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _viewRequestDetails(request);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D2D2D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(
                      Icons.visibility_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "View Details",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _approveHRRequest(requestId, employeeName);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "Approve",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showRejectDialog(requestId, employeeName);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(
                      Icons.cancel_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "Reject",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
      {required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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

    ValueNotifier<File?> dialogSelectedImage = ValueNotifier<File?>(null);
    ValueNotifier<String?> dialogSelectedImagePath =
        ValueNotifier<String?>(null);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
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
                        Center(
                          child: Column(
                            children: [
                              ValueListenableBuilder<String?>(
                                valueListenable: dialogSelectedImagePath,
                                builder: (context, imagePath, child) {
                                  return Stack(
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.deepPurple,
                                            width: 3,
                                          ),
                                        ),
                                        child: imagePath != null
                                            ? ClipOval(
                                                child: Image.file(
                                                  File(imagePath),
                                                  fit: BoxFit.cover,
                                                  width: 94,
                                                  height: 94,
                                                ),
                                              )
                                            : Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[800],
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.person,
                                                  size: 50,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.deepPurple,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF1E1E1E),
                                              width: 3,
                                            ),
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.camera_alt,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                            onPressed: () async {
                                              final XFile? pickedFile =
                                                  await _imagePicker.pickImage(
                                                source: ImageSource.gallery,
                                                maxWidth: 800,
                                                maxHeight: 800,
                                                imageQuality: 80,
                                              );

                                              if (pickedFile != null) {
                                                dialogSelectedImage.value =
                                                    File(pickedFile.path);
                                                dialogSelectedImagePath.value =
                                                    pickedFile.path;
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              ValueListenableBuilder<String?>(
                                valueListenable: dialogSelectedImagePath,
                                builder: (context, imagePath, child) {
                                  return Text(
                                    imagePath != null
                                        ? "Photo selected"
                                        : "Add profile photo",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
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
                        DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF1E1E1E),
                          value: selectedRole,
                          items: [
                            "Common",
                            "HR",
                            "CEO",
                            "Finance Verification",
                            "Finance Payment"
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setDialogState(() {
                              selectedRole = newValue!;
                            });
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
                                  colors: [
                                    Colors.deepPurple,
                                    Colors.purpleAccent
                                  ],
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

                                  _addEmployee(
                                      newEmployee, dialogSelectedImage.value);
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      enabled: enabled,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Recent Activities",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: MediaQuery.of(context).size.width < 400 ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadData,
                tooltip: "Refresh Activities",
              ),
              const SizedBox(width: 8),
              if (activityLog.isNotEmpty)
                TextButton(
                  onPressed: _showClearConfirmation,
                  child: const Text(
                    "Clear All",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Real-time updates of HR actions",
            style: TextStyle(
              color: Colors.white70,
              fontSize: MediaQuery.of(context).size.width < 400 ? 12 : 14,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: activityLog.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.white54,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "No activities yet",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "Your HR activities will appear here",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: activityLog.length,
                    itemBuilder: (context, index) {
                      final activity = activityLog[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F1F1F),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: activity.color.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              activity.icon,
                              color: activity.color,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            activity.description,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _formatTimeAgo(activity.timestamp),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            _formatTime(activity.timestamp),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

class EmployeeDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const EmployeeDetailsSheet({
    super.key,
    required this.employee,
    required this.onToggleStatus,
    required this.onDelete,
    required this.onEdit,
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
                  _buildEmployeeDetailAvatar(employee),
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
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${employee["role"] ?? "Employee"} - ${employee["department"] ?? "No Department"}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmployeeDetailAvatar(Map<String, dynamic> employee) {
    final String? avatarUrl = employee['avatar_url'] ?? employee['avatar'];
    final String fullName = employee['fullName'] ?? 'Employee';
    final bool isActive = employee['is_active'] == true;

    return Stack(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? Colors.green : Colors.red,
              width: 3,
            ),
          ),
          child: avatarUrl != null && avatarUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    width: 54,
                    height: 54,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildFallbackDetailAvatar(fullName, isActive);
                    },
                  ),
                )
              : _buildFallbackDetailAvatar(fullName, isActive),
        ),
      ],
    );
  }

  Widget _buildFallbackDetailAvatar(String fullName, bool isActive) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: isActive
            ? Colors.blue.withOpacity(0.2)
            : Colors.grey.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
          style: TextStyle(
            color: isActive ? Colors.blue : Colors.grey,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class DepartmentData {
  final String department;
  final int count;

  DepartmentData(this.department, this.count);
}

class ActivityItem {
  final String description;
  final IconData icon;
  final Color color;
  final DateTime timestamp;

  ActivityItem({
    required this.description,
    required this.icon,
    required this.color,
    required this.timestamp,
  });
}

class NotificationItem {
  final String title;
  final String message;
  final String type;
  final DateTime timestamp;
  bool isRead;

  NotificationItem({
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });
}
