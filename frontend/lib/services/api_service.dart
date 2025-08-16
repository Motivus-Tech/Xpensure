import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  final String baseUrl = "http://192.168.1.7:8000"; // Tanika's backend IP

  Future<String> loginEmployee(String employeeId, String password) async {
    try {
      final url = Uri.parse('$baseUrl/api/employee/login/');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'employee_id': employeeId, 'password': password}),
      );

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

  Future<String> registerEmployee(Map<String, dynamic> employeeData) async {
    try {
      final url = Uri.parse('$baseUrl/api/employee/register/');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(employeeData),
      );

      if (response.statusCode == 201) {
        return "Sign Up Successful!";
      } else {
        return "Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Error: $e";
    }
  }
}
