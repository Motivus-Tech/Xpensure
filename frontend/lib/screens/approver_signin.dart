import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'ceo_dashboard.dart';
import 'finance_verification_dashboard.dart';
import 'finance_payment_dashboard.dart';
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
  bool _isPasswordValid = false;

  final FocusNode _employeeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);

    // Auto-focus to trigger autofill suggestions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_employeeFocusNode);
      }
    });
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePassword);
    _employeeIdController.dispose();
    _passwordController.dispose();
    _employeeFocusNode.dispose();
    super.dispose();
  }

  void _validatePassword() {
    if (mounted) {
      setState(() {
        _isPasswordValid = _passwordController.text.length >= 6;
      });
    }
  }

  void _loginApprover() async {
    // Close keyboard first
    FocusScope.of(context).unfocus();

    final employeeId = _employeeIdController.text.trim();
    final password = _passwordController.text.trim();

    if (employeeId.isEmpty || password.isEmpty) {
      if (mounted) {
        setState(() {
          _message = "Please fill both fields";
        });
      }
      return;
    }

    if (!_isPasswordValid) {
      if (mounted) {
        setState(() {
          _message = "Password must be at least 6 characters";
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _message = "";
      });
    }

    try {
      final response = await http
          .post(
            Uri.parse("http://10.0.2.2:8000/api/auth/login/"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "employee_id": employeeId,
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 30)); // Add timeout

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check different response formats
        final bool success = data['success'] == true ||
            data['status'] == 'success' ||
            data['token'] != null;

        if (success) {
          final role = data['role'] ?? 'Common';
          final userId = data['user_id'] ?? data['employee_id'] ?? employeeId;
          final userName = data['fullName'] ??
              data['user_name'] ??
              data['employee_name'] ??
              'Employee';
          final avatarUrl = data['avatar'] ?? data['avatar_url'] ?? null;
          final token = data['token'] ?? '';

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Login Successful!")),
            );
          }

          // IMPORTANT: Wait for autofill to save password
          await Future.delayed(const Duration(milliseconds: 500));

          // Prepare user data for dashboard
          final userData = {
            'id': userId,
            'fullName': userName,
            'employeeId': employeeId,
            'avatar': avatarUrl,
            'role': role,
          };

          // Navigate to appropriate dashboard - UPDATED
          if (mounted) {
            if (role == 'CEO' || role == 'ceo') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => CEODashboard(
                    userData: userData,
                    authToken: token,
                    onLogout: () {
                      // Navigate back to login page
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ApproverSignInPage()),
                        (route) => false,
                      );
                    },
                  ),
                ),
              );
            } else if (role == "Finance Verification") {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => FinanceVerificationDashboard(
                    userData: userData,
                    authToken: token,
                    onLogout: () {
                      // Navigate back to login page
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ApproverSignInPage()),
                        (route) => false,
                      );
                    },
                  ),
                ),
              );
            } else if (role == "Finance Payment") {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => FinancePaymentDashboard(
                    userData: userData,
                    authToken: token,
                    onLogout: () {
                      // Navigate back to login page
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ApproverSignInPage()),
                        (route) => false,
                      );
                    },
                  ),
                ),
              );
            } else if (role == 'HR' ||
                role == 'hr' ||
                role == 'Human Resources') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => common.CommonDashboard(
                    userData: userData,
                    authToken: token,
                    onLogout: () {
                      // Navigate back to login page
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ApproverSignInPage()),
                        (route) => false,
                      );
                    },
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
                    onLogout: () {
                      // Navigate back to login page
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ApproverSignInPage()),
                        (route) => false,
                      );
                    },
                  ),
                ),
              );
            } else {
              setState(() {
                _message = "Role '$role' not authorized for Approver access";
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _message =
                  data['message'] ?? data['error'] ?? "Invalid credentials";
            });
          }
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _message = errorData['message'] ??
                errorData['error'] ??
                "Server error: ${response.statusCode}";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _message = e.toString().contains('TimeoutException')
              ? "Connection timeout. Please try again."
              : "Error connecting to server: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF009688)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? 400 : 500,
                  minWidth: isMobile ? 300 : 400,
                  minHeight: screenHeight * 0.6,
                ),
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 20 : 24),
                  margin: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 20,
                    vertical: isMobile ? 8 : 20,
                  ),
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
                      Icon(
                        Icons.business_center,
                        size: isMobile ? 50 : 60,
                        color: const Color(0xFF1A237E),
                      ),
                      SizedBox(height: isMobile ? 8 : 12),
                      Text(
                        "Approver Sign In",
                        style: TextStyle(
                          fontSize: isMobile ? 20 : 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A237E),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isMobile ? 16 : 24),

                      // AutofillGroup for password saving
                      AutofillGroup(
                        child: Column(
                          children: [
                            TextField(
                              controller: _employeeIdController,
                              focusNode: _employeeFocusNode,
                              autofillHints: const [AutofillHints.username],
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: "Employee ID",
                                prefixIcon: const Icon(Icons.badge_outlined),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: isMobile ? 14 : 16,
                                ),
                              ),
                            ),
                            SizedBox(height: isMobile ? 12 : 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              onEditingComplete: () {
                                if (_isPasswordValid &&
                                    !_isLoading &&
                                    mounted) {
                                  _loginApprover();
                                }
                              },
                              decoration: InputDecoration(
                                labelText: "Password",
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey.shade600,
                                  ),
                                  onPressed: () {
                                    if (mounted) {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    }
                                  },
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: isMobile ? 14 : 16,
                                ),
                                errorText: _passwordController
                                            .text.isNotEmpty &&
                                        !_isPasswordValid
                                    ? "Password must be at least 6 characters"
                                    : null,
                                errorMaxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isMobile ? 16 : 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isPasswordValid && !_isLoading
                                ? const Color(0xFF009688)
                                : Colors.grey,
                            padding: EdgeInsets.symmetric(
                              vertical: isMobile ? 14 : 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          onPressed: _isPasswordValid && !_isLoading
                              ? _loginApprover
                              : null,
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  "Sign In",
                                  style: TextStyle(
                                    fontSize: isMobile ? 16 : 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: isMobile ? 12 : 16),
                      if (_message.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.shade200,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _message,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: isMobile ? 13 : 14,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
