import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'ceo_dashboard.dart';
import 'finance_dashboard.dart' as finance;
import 'common_dashboard.dart' as common;

class ApproverSignInPage extends StatefulWidget {
  const ApproverSignInPage({super.key});

  @override
  State<ApproverSignInPage> createState() => _ApproverSignInPageState();
}

class _ApproverSignInPageState extends State<ApproverSignInPage> {
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String _message = "";

  void _loginApprover() async {
    final employeeId = _employeeIdController.text.trim();
    final password = _passwordController.text.trim();

    if (employeeId.isEmpty || password.isEmpty) {
      setState(() {
        _message = "Please fill both fields";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = "";
    });

    try {
      final response = await http.post(
        Uri.parse("http://10.0.2.2:8000/api/auth/login/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "employee_id": employeeId,
          "password": password,
        }),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check different response formats
        final bool success = data['success'] == true ||
            data['status'] == 'success' ||
            data['token'] != null;

        if (success) {
          final role = data['role'] ??
              'Common'; // Default to Common if role not specified
          final userId = data['user_id'] ?? data['employee_id'] ?? employeeId;
          final userName = data['fullName'] ??
              data['user_name'] ??
              data['employee_name'] ??
              'Employee';
          final avatarUrl = data['avatar'] ?? data['avatar_url'] ?? null;
          final token = data['token'] ?? '';

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Login Successful!")),
          );

          // Prepare user data for dashboard
          final userData = {
            'id': userId,
            'fullName': userName,
            'employeeId': employeeId,
            'avatar': avatarUrl,
            'role': role,
          };

          // Navigate to appropriate dashboard
          if (role == 'CEO' || role == 'ceo') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => CEODashboard(
                  userData: userData,
                  authToken: token,
                ),
              ),
            );
          } else if (role == 'Finance' || role == 'finance') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => finance.FinanceDashboard(
                  userData: userData,
                  authToken: token,
                ),
              ),
            );
          } else if (role == 'Common' ||
              role == 'common' ||
              role == 'Employee') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => common.CommonDashboard(
                  userData: userData,
                  authToken: token,
                ),
              ),
            );
          } else {
            setState(() {
              _message = "Role '$role' not authorized for Approver access";
            });
          }
        } else {
          setState(() {
            _message =
                data['message'] ?? data['error'] ?? "Invalid credentials";
          });
        }
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _message = errorData['message'] ??
              errorData['error'] ??
              "Server error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = "Error connecting to server: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF009688)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.business_center,
                    size: 60,
                    color: Color(0xFF1A237E),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Approver Sign In",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _employeeIdController,
                    decoration: InputDecoration(
                      labelText: "Employee ID",
                      prefixIcon: const Icon(Icons.badge_outlined),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _loginApprover,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Sign In",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_message.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        _message,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
