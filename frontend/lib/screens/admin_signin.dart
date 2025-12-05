import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async'; // Add this import for TimeoutException

import 'hr_dashboard.dart';

class AdminSignInPage extends StatefulWidget {
  const AdminSignInPage({super.key});

  @override
  State<AdminSignInPage> createState() => _AdminSignInPageState();
}

class _AdminSignInPageState extends State<AdminSignInPage> {
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

  void _loginAdmin() async {
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
          .timeout(const Duration(seconds: 30));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          // Check if user has HR role
          final userRole = data['role']?.toString().toLowerCase();

          if (userRole != 'hr') {
            if (mounted) {
              setState(() {
                _message = "Access denied. Only HR personnel can sign in here.";
              });
            }
            return;
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Login Successful!")),
            );
          }

          // IMPORTANT: Wait for autofill to save password
          await Future.delayed(const Duration(milliseconds: 500));

          // Pass the token and user data to HRDashboard
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HRDashboard(
                  authToken: data['token'],
                  userData: {
                    'employee_id': data['employee_id'],
                    'fullName': data['fullName'],
                    'email': data['email'],
                    'department': data['department'],
                    'phone_number': data['phone_number'],
                    'aadhar_card': data['aadhar_card'],
                    'role': data['role'],
                    'avatar': data['avatar'],
                  },
                  onLogout: () {
                    // This callback will be called when user logs out from HRDashboard
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AdminSignInPage()),
                    );
                  },
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            setState(() {
              // Show user-friendly message from server or default
              final serverMessage = data['message']?.toString() ?? '';

              // Common error messages from backend
              if (serverMessage.contains('Invalid credentials') ||
                  serverMessage.contains('incorrect') ||
                  serverMessage.toLowerCase().contains('wrong')) {
                _message = "Invalid Employee ID or Password. Please try again.";
              } else if (serverMessage.contains('not found') ||
                  serverMessage.contains('does not exist')) {
                _message = "Employee ID not found. Please check your ID.";
              } else if (serverMessage.contains('required') ||
                  serverMessage.contains('missing')) {
                _message = "Please fill all required fields.";
              } else if (serverMessage.isNotEmpty) {
                _message = serverMessage;
              } else {
                _message = "Invalid credentials. Please try again.";
              }
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            // User-friendly HTTP status code messages
            switch (response.statusCode) {
              case 400:
                _message = "Bad request. Please check your information.";
                break;
              case 401:
                _message = "Inavlid. Please check your credentials.";
                break;
              case 403:
                _message = "Access denied. You don't have permission.";
                break;
              case 404:
                _message = "Service not found. Please try again later.";
                break;
              case 408:
                _message = "Request timeout. Please try again.";
                break;
              case 500:
              case 502:
              case 503:
              case 504:
                _message =
                    "Server is temporarily unavailable. Please try again later.";
                break;
              default:
                _message = "Something went wrong. Please try again.";
            }
          });
        }
      }
    } on http.ClientException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e.message.contains('Failed host lookup') ||
              e.message.contains('Connection refused')) {
            _message =
                "Cannot connect to server. Please check your internet connection.";
          } else if (e.message.contains('timeout')) {
            _message = "Connection timeout. Please try again.";
          } else {
            _message =
                "Network error. Please check your connection and try again.";
          }
        });
      }
    } on TimeoutException catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _message = "Connection timeout. Please try again.";
        });
      }
    } on FormatException catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _message = "Invalid response from server. Please try again.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Generic fallback message
          _message = "An error occurred. Please try again.";

          // For debugging only (remove in production or use logging)
          print('Login error: $e'); // Keep this for developers
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
                        Icons.admin_panel_settings,
                        size: isMobile ? 50 : 60,
                        color: const Color(0xFF1A237E),
                      ),
                      SizedBox(height: isMobile ? 8 : 12),
                      Text(
                        "HR Portal Sign In",
                        style: TextStyle(
                          fontSize: isMobile ? 20 : 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A237E),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isMobile ? 4 : 6),
                      Text(
                        "Restricted to HR personnel only",
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: Colors.grey.shade600,
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
                                  _loginAdmin();
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
                              ? _loginAdmin
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
                      SizedBox(height: isMobile ? 8 : 12),
                      SizedBox(height: isMobile ? 12 : 16),
                      if (_message.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _message.toLowerCase().contains('successful')
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  _message.toLowerCase().contains('successful')
                                      ? Colors.green.shade200
                                      : Colors.red.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _message.toLowerCase().contains('successful')
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                color: _message
                                        .toLowerCase()
                                        .contains('successful')
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _message,
                                  style: TextStyle(
                                    color: _message
                                            .toLowerCase()
                                            .contains('successful')
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    fontSize: isMobile ? 13 : 14,
                                    height: 1.3,
                                  ),
                                  textAlign: TextAlign.left,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
