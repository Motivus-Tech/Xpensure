import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'employee_signup.dart';
import 'employee_forgot_password.dart';
import 'employee_dashboard.dart';

class EmployeeSignInPage extends StatefulWidget {
  const EmployeeSignInPage({super.key});

  @override
  State<EmployeeSignInPage> createState() => _EmployeeSignInPageState();
}

class _EmployeeSignInPageState extends State<EmployeeSignInPage> {
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();

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

  void _login() async {
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
      // Call API
      Map<String, dynamic> response = await _apiService.loginEmployeeMap(
        employeeId: employeeId,
        password: password,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (response["status"] == "success" && response["employee"] != null) {
        final employee = Map<String, dynamic>.from(response["employee"]);

        // Save token
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('authToken', response["token"] ?? "");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Login Successful!")),
          );
        }

        // IMPORTANT: Wait for autofill to save password
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigate to EmployeeDashboard
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EmployeeDashboard(
                employeeName: employee["fullName"] ?? "",
                employeeId: employee["employee_id"] ?? "",
                email: employee["email"] ?? "",
                mobile: employee["phone_number"] ?? "",
                avatarUrl: employee["avatar_url"] ?? "",
                department: employee["department"] ?? "",
                aadhaar: employee["aadhar_card"] ?? "",
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _message = response["message"] ?? "Login failed";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _message = "Error connecting to server: $e";
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
                        Icons.work,
                        size: isMobile ? 50 : 60,
                        color: const Color(0xFF1A237E),
                      ),
                      SizedBox(height: isMobile ? 8 : 12),
                      Text(
                        "Employee Sign In",
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
                                  _login();
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
                          onPressed:
                              _isPasswordValid && !_isLoading ? _login : null,
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

                      // Navigation buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EmployeeForgotPasswordPage(),
                                ),
                              );
                            },
                            child: Text(
                              "Forgot Password?",
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                color: const Color(0xFF009688),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EmployeeSignUpPage(),
                                ),
                              );
                            },
                            child: Text(
                              "Sign Up",
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                color: const Color(0xFF009688),
                              ),
                            ),
                          ),
                        ],
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
