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

  void _login() async {
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

    // Call API
    Map<String, dynamic> response = await _apiService.loginEmployeeMap(
      employeeId: employeeId,
      password: password,
    );

    setState(() {
      _isLoading = false;
    });

    if (response["status"] == "success" && response["employee"] != null) {
      final employee = Map<String, dynamic>.from(response["employee"]);

      // Save token
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('authToken', response["token"] ?? "");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Login Successful!")));

      // Navigate to EmployeeDashboard
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
    } else {
      setState(() {
        _message = response["message"] ?? "Login failed";
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_message)));
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
                  const Icon(Icons.work, size: 60, color: Color(0xFF1A237E)),
                  const SizedBox(height: 12),
                  const Text(
                    "Employee Sign In",
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
                      onPressed: _login,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
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
                        child: const Text("Forgot Password?"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EmployeeSignUpPage(),
                            ),
                          );
                        },
                        child: const Text("Sign Up"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(_message, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
