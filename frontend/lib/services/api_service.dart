import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

class ApiService {
  final String baseUrl =
      "http://10.0.2.2:8000"; // Use PC LAN IP for real device
  final Duration requestTimeout = const Duration(seconds: 15);

  static const Map<String, String> headers = {
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
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/auth/signup/');
      final response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode({
              'employee_id': employeeId,
              'email': email,
              'fullName': fullName,
              'department': department,
              'phone_number': phoneNumber,
              'aadhar_card': aadharNumber,
              'password': password,
              'confirm_password': confirmPassword,
            }),
          )
          .timeout(requestTimeout);

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
  // Employee Login via employee_id
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
            headers: headers,
            body: jsonEncode({'employee_id': employeeId, 'password': password}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final employee = data["employee"] ?? {};

        // Normalize keys for frontend
        return {
          "status": "success",
          "employee": {
            "fullName": employee["fullName"] ?? "",
            "employee_id": employee["employee_id"] ?? "",
            "email": employee["email"] ?? "",
            "phone_number": employee["phone_number"] ?? "",
            "avatar_url": employee["avatarUrl"] ?? "",
            "department": employee["department"] ?? "",
            "aadhar_card": employee["aadhar_card"] ?? "",
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
  // Submit Reimbursement
  // -----------------------------
  Future<String> submitReimbursement({
    required String authToken,
    required String amount,
    String? description,
    File? attachment,
    required String date,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/api/reimbursements/');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Token $authToken';
      request.fields['amount'] = amount;
      request.fields['description'] = description ?? '';
      request.fields['date'] = date;

      if (attachment != null) {
        request.files.add(
          await http.MultipartFile.fromPath('attachment', attachment.path),
        );
      }

      var streamedResponse = await request.send().timeout(requestTimeout);
      var response = await http.Response.fromStream(streamedResponse);

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
  // Submit Advance
  // -----------------------------
  Future<String> submitAdvanceRequest({
    required String authToken,
    required String amount,
    required String description,
    required String requestDate,
    required String projectDate,
    File? attachment,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/api/advances/');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Token $authToken';
      request.fields['amount'] = amount;
      request.fields['description'] = description;
      request.fields['request_date'] = requestDate;
      request.fields['project_date'] = projectDate;

      if (attachment != null) {
        request.files.add(
          await http.MultipartFile.fromPath('attachment', attachment.path),
        );
      }

      var streamedResponse = await request.send().timeout(requestTimeout);
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return "Advance submitted successfully!";
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
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/reimbursements/'),
            headers: {
              'Authorization': 'Token $authToken',
              'Accept': 'application/json',
            },
          )
          .timeout(requestTimeout);

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
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/advances/'),
            headers: {
              'Authorization': 'Token $authToken',
              'Accept': 'application/json',
            },
          )
          .timeout(requestTimeout);

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
  // Optional: Server Health Check
  // -----------------------------
  Future<bool> checkServerStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health/'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
