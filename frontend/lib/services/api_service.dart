import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class ApiService {
  final String baseUrl = "http://10.0.2.2:8000"; // Android emulator
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
    required String fullName, // <- matches Django serializer
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
              'fullName': fullName, // <- must match serializer
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
  Future<String> loginEmployee({
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
        return "Login Successful!";
      } else if (response.statusCode == 401) {
        return "Invalid credentials!";
      } else {
        return "Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Error: $e";
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
