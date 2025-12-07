import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

class ApiService {
  final String baseUrl = "http://10.0.2.2:8000";
  final Duration requestTimeout = const Duration(seconds: 15);

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // -----------------------------
  // Employee Signup
  // -----------------------------
  Future<String> registerEmployee({
    required String employeeId,
    required String email,
    required String fullName,
    required String department,
    required String phoneNumber,
    required String aadharNumber,
    required String password,
    required String confirmPassword,
    File? avatar,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/api/auth/signup/');
      var request = http.MultipartRequest('POST', uri);

      request.fields['employee_id'] = employeeId;
      request.fields['fullName'] = fullName;
      request.fields['email'] = email;
      request.fields['department'] = department;
      request.fields['phone_number'] = phoneNumber;
      request.fields['aadhar_card'] = aadharNumber;
      request.fields['password'] = password;
      request.fields['confirm_password'] = confirmPassword;

      if (avatar != null) {
        request.files.add(
          await http.MultipartFile.fromPath('avatar', avatar.path),
        );
      }

      request.fields.forEach((key, value) {
        debugPrint("Signup Field: $key = $value");
      });

      var streamedResponse = await request.send().timeout(requestTimeout);
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint("Signup Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        return "Sign Up Successful!";
      } else {
        return "Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Error: $e";
    }
  }

  // -----------------------------
  // Employee Login
  // -----------------------------
  Future<Map<String, dynamic>> loginEmployeeMap({
    required String employeeId,
    required String password,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/auth/login/');

      final response = await http
          .post(
            url,
            headers: defaultHeaders,
            body: jsonEncode({'employee_id': employeeId, 'password': password}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "status": "success",
          "employee": {
            "fullName": data["fullName"] ?? "",
            "employee_id": data["employee_id"] ?? "",
            "email": data["email"] ?? "",
            "phone_number": data["phone_number"] ?? "",
            "avatar_url": data["avatar"] ?? "",
            "department": data["department"] ?? "",
            "aadhar_card": data["aadhar_card"] ?? "",
          },
          "token": data["token"] ?? "",
        };
      } else if (response.statusCode == 401) {
        return {"status": "error", "message": "Invalid credentials!"};
      } else {
        return {
          "status": "error",
          "message": "Error: ${response.statusCode} - ${response.body}",
        };
      }
    } catch (e) {
      return {"status": "error", "message": "Error: $e"};
    }
  }

  // -----------------------------
  // Update Employee Profile
  // -----------------------------
  Future<Map<String, dynamic>?> updateProfile({
    required String employeeId,
    required String authToken,
    required String fullName,
    required String email,
    required String phone_number,
    File? profileImage,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/api/employees/$employeeId/profile/');
      var request = http.MultipartRequest('PUT', uri);

      request.headers['Authorization'] = 'Token $authToken';

      request.fields['fullName'] = fullName.trim();
      request.fields['email'] = email.trim();
      request.fields['phone_number'] = phone_number.trim();

      if (profileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('avatar', profileImage.path),
        );
      }

      request.fields.forEach((key, value) {
        debugPrint("Update Field: $key = $value");
      });

      var streamedResponse = await request.send().timeout(requestTimeout);
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint("Update Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint(
          "Failed to update profile: ${response.statusCode} - ${response.body}",
        );
        return null;
      }
    } catch (e) {
      debugPrint("Error updating profile: $e");
      return null;
    }
  }
// In ApiService - FIX THE SUBMIT METHODS

// -----------------------------
// Submit Reimbursement - FIXED
// -----------------------------
  Future<String> submitReimbursement({
    required String authToken,
    required String amount,
    String? description,
    required List<File> attachments,
    required String date,
    required List<Map<String, dynamic>> payments,
    required String projectId, // ✅ ADD REQUIRED PROJECT ID
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/api/reimbursements/');
      var request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Token $authToken';

      // ✅ ADD PROJECT ID FIELD - THIS WAS MISSING!
      request.fields['project_id'] = projectId;
      request.fields['amount'] = amount;
      request.fields['description'] = description ?? '';
      request.fields['date'] = date;
      request.fields['payments'] = jsonEncode(payments);

      // Add attachments
      for (var i = 0; i < attachments.length; i++) {
        var attachment = attachments[i];
        if (await attachment.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'attachments',
              attachment.path,
              filename:
                  'attachment_${i + 1}_${attachment.path.split('/').last}',
            ),
          );
        }
      }

      var streamedResponse = await request.send().timeout(requestTimeout);
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint(
          'Reimbursement Submit Response: ${response.statusCode} - ${response.body}');
      debugPrint('Reimbursement Project ID Sent: $projectId'); // ✅ DEBUG

      if (response.statusCode == 201) {
        return "Reimbursement submitted successfully!";
      } else {
        return "Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Error: $e";
    }
  }

// -----------------------------
// Submit Advance Request - FIXED
// -----------------------------
  Future<String> submitAdvanceRequest({
    required String authToken,
    required String amount,
    required String description,
    required String requestDate,
    required String projectDate,
    required List<File> attachments,
    required List<Map<String, dynamic>> payments,
    required String projectId, // ✅ ADD REQUIRED PARAMETER
    required String projectName, // ✅ ADD REQUIRED PARAMETER
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/api/advances/');
      var request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Token $authToken';

      // ✅ ADD PROJECT FIELDS - THESE WERE MISSING!
      request.fields['project_id'] = projectId;
      request.fields['project_name'] = projectName;
      request.fields['amount'] = amount;
      request.fields['description'] = description;
      request.fields['request_date'] = requestDate;
      request.fields['project_date'] = projectDate;
      request.fields['payments'] = jsonEncode(payments);

      // Add attachments
      for (var i = 0; i < attachments.length; i++) {
        var attachment = attachments[i];
        if (await attachment.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'attachments',
              attachment.path,
              filename:
                  'advance_attachment_${i + 1}_${attachment.path.split('/').last}',
            ),
          );
        }
      }

      var streamedResponse = await request.send().timeout(requestTimeout);
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint(
          'Advance Submit Response: ${response.statusCode} - ${response.body}');
      debugPrint(
          'Advance Project Data Sent - ID: $projectId, Name: $projectName'); // ✅ DEBUG

      if (response.statusCode == 201) {
        return "Advance request submitted successfully!";
      } else {
        return "Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Error: $e";
    }
  }

  // -----------------------------
  // Fetch Reimbursements
  // -----------------------------
  Future<List<Map<String, dynamic>>> fetchReimbursements(
    String authToken,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/reimbursements/'),
        headers: {
          'Authorization': 'Token $authToken',
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception(
          "Failed to fetch reimbursements: ${response.statusCode}",
        );
      }
    } catch (e) {
      throw Exception("Error fetching reimbursements: $e");
    }
  }

  // -----------------------------
  // Fetch Advances
  // -----------------------------
  Future<List<Map<String, dynamic>>> fetchAdvances(String authToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/advances/'),
        headers: {
          'Authorization': 'Token $authToken',
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception("Failed to fetch advances: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error fetching advances: $e");
    }
  }

  // -----------------------------
  // Get Employee Profile (Requires Token)
  // -----------------------------
  Future<Map<String, dynamic>> getProfile({
    required String employeeId,
    required String authToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/employees/$employeeId/profile/'),
        headers: {
          'Authorization': 'Token $authToken',
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          "Failed to fetch profile: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      throw Exception("Error fetching profile: $e");
    }
  }

  // -----------------------------
  // Change Password (Requires Token)
  // -----------------------------
  Future<bool> verifyOldPassword({
    required String employeeId,
    required String oldPassword,
    required String authToken,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/employees/$employeeId/verify-password/'),
            headers: {
              'Authorization': 'Token $authToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'old_password': oldPassword}),
          )
          .timeout(requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> changePassword({
    required String employeeId,
    required String newPassword,
    required String authToken,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/api/employees/$employeeId/change-password/'),
            headers: {
              'Authorization': 'Token $authToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'new_password': newPassword}),
          )
          .timeout(requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // -----------------------------
  // Optional: Server Health Check
  // -----------------------------
  Future<bool> checkServerStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/health/'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // -----------------------------
  // Admin Login
  // -----------------------------
  Future<Map<String, dynamic>> loginAdminMap({
    required String adminId,
    required String password,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/auth/admin/login/');

      final response = await http
          .post(
            url,
            headers: defaultHeaders,
            body: jsonEncode({'admin_id': adminId, 'password': password}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "status": "success",
          "admin": {
            "admin_id": data["admin_id"] ?? "",
            "fullName": data["fullName"] ?? "",
            "email": data["email"] ?? "",
          },
          "token": data["token"] ?? "",
        };
      } else if (response.statusCode == 401) {
        return {"status": "error", "message": "Invalid admin credentials!"};
      } else {
        return {
          "status": "error",
          "message": "Error: ${response.statusCode} - ${response.body}",
        };
      }
    } catch (e) {
      return {"status": "error", "message": "Error: $e"};
    }
  }

  // -----------------------------
  // HR/Admin-specific Methods
  // -----------------------------
  Future<bool> updateEmployeeStatus({
    required String authToken,
    required String employeeId,
    required bool isActive,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/employees/$employeeId/status/');
      final response = await http
          .put(
            url,
            headers: {
              'Authorization': 'Token $authToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'is_active': isActive}),
          )
          .timeout(requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error updating employee status: $e");
      return false;
    }
  }

  Future<bool> addActivity({
    required String authToken,
    required String employeeId,
    required String activity,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/employees/$employeeId/activities/');
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Token $authToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'activity': activity}),
          )
          .timeout(requestTimeout);

      return response.statusCode == 201;
    } catch (e) {
      debugPrint("Error adding activity: $e");
      return false;
    }
  }

  Future<bool> deleteEmployee({
    required String authToken,
    required String employeeId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/employees/$employeeId/');
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Token $authToken'},
      ).timeout(requestTimeout);

      return response.statusCode == 204;
    } catch (e) {
      debugPrint("Error deleting employee: $e");
      return false;
    }
  }

  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health/'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print("Connection test failed: $e");
      return false;
    }
  }

  // -----------------------------
  // Multi-level Approval Workflow
  // -----------------------------

  // Fetch Pending Approvals for Logged-in Manager
  Future<Map<String, dynamic>> getPendingApprovals({
    required String authToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/approvals/pending/'),
        headers: {
          'Authorization': 'Token $authToken',
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        throw Exception(
          "Failed to fetch pending approvals: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      throw Exception("Error fetching pending approvals: $e");
    }
  }

  Future<bool> approveRequest({
    required String authToken,
    required int requestId,
    required String requestType, // "reimbursement" or "advance"
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/approvals/$requestId/approve/'),
      headers: {
        'Authorization': 'Token $authToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({"request_type": requestType}),
    );
    return response.statusCode == 200;
  }

  Future<bool> rejectRequest({
    required String authToken,
    required int requestId,
    required String requestType, // "reimbursement" or "advance"
    required String reason,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/approvals/$requestId/reject/'),
      headers: {
        'Authorization': 'Token $authToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "request_type": requestType,
        "rejection_reason": reason,
      }),
    );
    return response.statusCode == 200;
  }
// In your ApiService class, update the CEO methods:
// services/api_service.dart - CEO Methods add karo

// -----------------------------
// CEO Dashboard APIs - ACTUAL
// -----------------------------
  Future<Map<String, dynamic>> getCEODashboardData({
    required String authToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ceo/dashboard/'),
        headers: {
          'Authorization': 'Token $authToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);

      debugPrint(
          'CEO Dashboard Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. CEO role required.');
      } else {
        throw Exception('Failed to load CEO dashboard: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in getCEODashboardData: $e');
      throw Exception('Failed to load CEO dashboard: $e');
    }
  }

  Future<Map<String, dynamic>> getCEOAnalytics({
    required String authToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ceo/analytics/'),
        headers: {
          'Authorization': 'Token $authToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);

      debugPrint(
          'CEO Analytics Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. CEO role required.');
      } else {
        // Return empty analytics data if endpoint fails
        return {
          'monthly_spending': 0,
          'monthly_growth': 0,
          'total_requests': 0,
          'reimbursement_count': 0,
          'advance_count': 0,
          'approval_rate': 0,
          'approved_count': 0,
          'rejected_count': 0,
          'pending_count': 0,
          'department_stats': [],
          'average_request_amount': 0,
          'top_department': 'N/A'
        };
      }
    } catch (e) {
      debugPrint('Error in getCEOAnalytics: $e');
      // Return default analytics data on error
      return {
        'monthly_spending': 0,
        'monthly_growth': 0,
        'total_requests': 0,
        'reimbursement_count': 0,
        'advance_count': 0,
        'approval_rate': 0,
        'approved_count': 0,
        'rejected_count': 0,
        'pending_count': 0,
        'department_stats': [],
        'average_request_amount': 0,
        'top_department': 'N/A'
      };
    }
  }

  // -----------------------------
// CEO History - FIXED
// -----------------------------
  // In your ApiService class, update the getCEOHistory method:

// -----------------------------
// CEO History - FIXED
// -----------------------------
  Future<List<dynamic>> getCEOHistory({
    required String authToken,
    String period = 'last_30_days',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ceo/history/?period=$period'),
        headers: {
          'Authorization': 'Token $authToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);

      debugPrint(
          'CEO History Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle both response formats:
        // 1. Direct list response: [item1, item2, ...]
        // 2. Map response with 'history' key: {'history': [item1, item2, ...]}
        if (data is List) {
          return data; // Direct list response
        } else if (data is Map && data.containsKey('history')) {
          return List<dynamic>.from(
              data['history'] ?? []); // Map with history key
        } else {
          return []; // Unknown format, return empty
        }
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. CEO role required.');
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error in getCEOHistory: $e');
      return [];
    }
  }
  // Add these methods to your existing ApiService class:

// In your ApiService class, update the CEO approval methods:

// -----------------------------
// CEO Approval/Rejection APIs - FIXED
// -----------------------------
  Future<bool> approveCEORequest({
    required String authToken,
    required int requestId,
    required String requestType,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/ceo/approve-request/'),
            headers: {
              'Authorization': 'Token $authToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'request_id': requestId,
              'request_type': requestType,
            }),
          )
          .timeout(requestTimeout);

      debugPrint(
          'CEO Approve Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint('CEO Approve Failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error in approveCEORequest: $e');
      return false;
    }
  }

  Future<bool> rejectCEORequest({
    required String authToken,
    required int requestId,
    required String requestType,
    required String reason,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/ceo/reject-request/'),
            headers: {
              'Authorization': 'Token $authToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'request_id': requestId,
              'request_type': requestType,
              'reason': reason,
            }),
          )
          .timeout(requestTimeout);

      debugPrint(
          'CEO Reject Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint('CEO Reject Failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error in rejectCEORequest: $e');
      return false;
    }
  }

// -----------------------------
// CEO Request Details - FIXED
// -----------------------------
  Future<Map<String, dynamic>> getCEORequestDetails({
    required String authToken,
    required int requestId,
    required String requestType,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/ceo/request-details/$requestId/?request_type=$requestType'),
        headers: {
          'Authorization': 'Token $authToken',
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);

      debugPrint(
          'CEO Request Details Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Failed to load request details: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in getCEORequestDetails: $e');
      throw Exception('Failed to load request details: $e');
    }
  }

// -----------------------------
// CEO Reports Generation
// -----------------------------
  Future<Map<String, dynamic>> generateCEOReport({
    required String authToken,
    required String reportType,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ceo/generate-report/?report_type=$reportType'),
        headers: {
          'Authorization': 'Token $authToken',
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);

      debugPrint(
          'CEO Report Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Failed to generate CEO report: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in generateCEOReport: $e');
      throw Exception('Failed to generate CEO report: $e');
    }
  }

  Future<bool> downloadCEOReport({
    required String authToken,
    required String reportName,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ceo/download-report/?report_name=$reportName'),
        headers: {
          'Authorization': 'Token $authToken',
        },
      ).timeout(requestTimeout);

      debugPrint('CEO Download Report Response: ${response.statusCode}');

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error in downloadCEOReport: $e');
      return false;
    }
  }

// -----------------------------
// CEO Enhanced Analytics
// -----------------------------
  Future<Map<String, dynamic>> getCEODetailedAnalytics({
    required String authToken,
    String period = 'this_month',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ceo/detailed-analytics/?period=$period'),
        headers: {
          'Authorization': 'Token $authToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);

      debugPrint(
          'CEO Detailed Analytics Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        // Return enhanced default analytics
        return {
          'monthly_approved_count': 0,
          'monthly_spending': 0,
          'total_requests_this_month': 0,
          'average_request_amount': 0,
          'approval_rate': 0,
          'monthly_trend': [],
          'department_stats': [],
          'recent_reports': [],
          'monthly_growth': 0,
          'reimbursement_count': 0,
          'advance_count': 0,
          'approved_count': 0,
          'rejected_count': 0,
          'pending_count': 0,
          'top_department': 'N/A'
        };
      }
    } catch (e) {
      debugPrint('Error in getCEODetailedAnalytics: $e');
      return {
        'monthly_approved_count': 0,
        'monthly_spending': 0,
        'total_requests_this_month': 0,
        'average_request_amount': 0,
        'approval_rate': 0,
        'monthly_trend': [],
        'department_stats': [],
        'recent_reports': [],
        'monthly_growth': 0,
        'reimbursement_count': 0,
        'advance_count': 0,
        'approved_count': 0,
        'rejected_count': 0,
        'pending_count': 0,
        'top_department': 'N/A'
      };
    }
  }

  // Add to ApiService class
  Future<Map<String, dynamic>> getApprovalTimeline({
    required String authToken,
    required int requestId,
    required String requestType,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/approval-timeline/$requestId/?request_type=$requestType'),
        headers: {
          'Authorization': 'Token $authToken',
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Failed to load approval timeline: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching approval timeline: $e');
    }
  }

  // Add this method to ApiService
  Future<Map<String, dynamic>> _handleApiResponse(
      http.Response response) async {
    try {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        throw HttpException(
          'Request failed with status: ${response.statusCode}',
          uri: response.request?.url,
        );
      }
    } catch (e) {
      throw Exception('Failed to parse response: $e');
    }
  }

  // Add these methods to ApiService
  Future<Map<String, dynamic>> getFinanceVerificationDashboard({
    required String authToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/finance-verification/dashboard/'),
      headers: {'Authorization': 'Token $authToken'},
    );
    return json.decode(response.body);
  }

  Future<bool> financeVerificationApprove({
    required String authToken,
    required int requestId,
    required String requestType,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/finance-verification/approve/'),
      headers: {'Authorization': 'Token $authToken'},
      body: json.encode({
        'request_id': requestId,
        'request_type': requestType,
      }),
    );
    return response.statusCode == 200;
  }

  Future<bool> financeVerificationReject({
    required String authToken,
    required int requestId,
    required String requestType,
    required String reason,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/finance-verification/reject/'),
      headers: {'Authorization': 'Token $authToken'},
      body: json.encode({
        'request_id': requestId,
        'request_type': requestType,
        'reason': reason,
      }),
    );
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> getFinancePaymentDashboard({
    required String authToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/finance-payment/dashboard/'),
      headers: {'Authorization': 'Token $authToken'},
    );
    return json.decode(response.body);
  }

  Future<bool> financePaymentMarkAsPaid({
    required String authToken,
    required int requestId,
    required String requestType,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/finance-payment/mark-paid/'),
      headers: {'Authorization': 'Token $authToken'},
      body: json.encode({
        'request_id': requestId,
        'request_type': requestType,
      }),
    );
    return response.statusCode == 200;
  }
}
