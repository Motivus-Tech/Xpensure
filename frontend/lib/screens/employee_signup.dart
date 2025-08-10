import 'package:flutter/material.dart';

class EmployeeSignUp extends StatefulWidget {
  const EmployeeSignUp({super.key});

  @override
  State<EmployeeSignUp> createState() => _EmployeeSignUpState();
}

class _EmployeeSignUpState extends State<EmployeeSignUp> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _profileImagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1A237E), // Deep Indigo
              Color(0xFF26A69A), // Soothing Teal-Green
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(28),
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Employee Registration",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 25),

                  GestureDetector(
                    onTap: () {
                      // TODO: Implement file picker / image picker
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color(
                        0xFF26A69A,
                      ).withValues(alpha: 0.15),
                      backgroundImage: _profileImagePath != null
                          ? AssetImage(_profileImagePath!) as ImageProvider
                          : null,
                      child: _profileImagePath == null
                          ? const Icon(
                              Icons.camera_alt,
                              color: Color(0xFF26A69A),
                              size: 30,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 25),

                  _buildTextField(
                    label: "Full Name",
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    label: "Employee ID",
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    label: "Department",
                    icon: Icons.business_outlined,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    label: "Phone Number",
                    icon: Icons.phone_outlined,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    label: "Email ID",
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    label: "Aadhar Card No.",
                    icon: Icons.credit_card_outlined,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    label: "Create Password",
                    icon: Icons.lock_outline,
                    obscure: _obscurePassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    label: "Confirm Password",
                    icon: Icons.lock_outline,
                    obscure: _obscureConfirmPassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF26A69A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      onPressed: () {
                        // TODO: Submit data to backend
                      },
                      child: const Text(
                        "Register",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account? "),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Sign In",
                          style: TextStyle(
                            color: Color(0xFF1A237E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF26A69A)),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
