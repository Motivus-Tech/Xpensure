import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class EmployeeService {
  // Replace this with your actual backend URL
  static const String baseUrl = "http://3.110.215.143";

  // Headers for API requests
  static Map<String, String> getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Add authorization token if required
      // 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch all employees
  static Future<List<Map<String, dynamic>>> getEmployees() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/employees/'),
      headers: getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to fetch employees: ${response.statusCode}');
    }
  }

  /// Add a new employee
  static Future<bool> addEmployee(Map<String, dynamic> employee) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/employees/'),
      headers: getHeaders(),
      body: json.encode(employee),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to add employee: ${response.statusCode}');
    }
  }

  /// Delete an employee by ID
  static Future<bool> deleteEmployee(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/employees/$id/'),
      headers: getHeaders(),
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return true;
    } else {
      throw Exception('Failed to delete employee: ${response.statusCode}');
    }
  }

  /// Update employee status
  static Future<bool> updateEmployeeStatus(String id, String status) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/employees/$id/'),
      headers: getHeaders(),
      body: json.encode({'status': status}),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to update status: ${response.statusCode}');
    }
  }

  /// Fetch activity logs
  static Future<List<Map<String, dynamic>>> getActivities() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/activities/'),
      headers: getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to fetch activities: ${response.statusCode}');
    }
  }

  /// Add a new activity
  static Future<bool> addActivity(Map<String, dynamic> activity) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/activities/'),
      headers: getHeaders(),
      body: json.encode(activity),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to add activity: ${response.statusCode}');
    }
  }
}
