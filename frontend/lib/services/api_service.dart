import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

class ApiService {
  final String baseUrl =
      "http://10.0.2.2:8000"; // Use PC LAN IP for real device
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
  // Get Employee Profile (Requires Token)
  // -----------------------------
  Future<Map<String, dynamic>> getProfile({
    required String employeeId,
    required String authToken,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/employees/$employeeId/profile/'),
            headers: {
              'Authorization': 'Token $authToken',
              'Accept': 'application/json',
            },
          )
          .timeout(requestTimeout);

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
          .get(Uri.parse('$baseUrl/health/'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
