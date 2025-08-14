import 'package:flutter/material.dart';
import 'employee_signin.dart';

class EmployeeForgotPasswordPage extends StatefulWidget {
  const EmployeeForgotPasswordPage({super.key});

  @override
  State<EmployeeForgotPasswordPage> createState() =>
      _EmployeeForgotPasswordPageState();
}

class _EmployeeForgotPasswordPageState
    extends State<EmployeeForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailOrPhoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isOtpSent = false;
  bool _isPasswordReset = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  void _sendOtp() {
    if (_emailOrPhoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter Email or Mobile Number")),
      );
      return;
    }

    // TODO: Integrate backend OTP send
    setState(() {
      _isOtpSent = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("OTP sent successfully (mock)")),
    );
  }

  void _resetPassword() {
    if (_formKey.currentState!.validate()) {
      // TODO: Call backend to reset password
      setState(() {
        _isPasswordReset = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset successful")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const EmployeeSignInPage()),
      );
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
              child: _isPasswordReset
                  ? const Center(
                      child: Text(
                        "Password reset successful!",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_reset,
                            size: 60,
                            color: Color(0xFF1A237E),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Reset Password",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Email / Phone
                          TextFormField(
                            controller: _emailOrPhoneController,
                            decoration: InputDecoration(
                              labelText: "Email or Mobile Number",
                              prefixIcon: const Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Enter Email or Mobile Number";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Send OTP Button
                          if (!_isOtpSent)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _sendOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF009688),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Send OTP",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                          // OTP and New Password Fields
                          if (_isOtpSent) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _otpController,
                              decoration: InputDecoration(
                                labelText: "Enter OTP",
                                prefixIcon: const Icon(Icons.confirmation_num),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Enter OTP";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: "New Password",
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
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Enter new password";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                labelText: "Confirm Password",
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
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
                              validator: (value) {
                                if (value != _newPasswordController.text) {
                                  return "Passwords do not match";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _resetPassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF009688),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Reset Password",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
