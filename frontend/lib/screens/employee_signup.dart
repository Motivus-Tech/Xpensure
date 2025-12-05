import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'employee_signin.dart';

class EmployeeSignUpPage extends StatefulWidget {
  const EmployeeSignUpPage({super.key});

  @override
  State<EmployeeSignUpPage> createState() => _EmployeeSignUpPageState();
}

class _EmployeeSignUpPageState extends State<EmployeeSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _aadharController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Friendly error messages for common issues
  String _getFriendlyErrorMessage(String error) {
    if (error.contains('connection') || error.contains('network')) {
      return 'Unable to connect. Please check your internet connection and try again.';
    } else if (error.contains('email') || error.contains('Email')) {
      return 'This email is already registered. Please use a different email or sign in instead.';
    } else if (error.contains('employee') || error.contains('ID')) {
      return 'This Employee ID is already registered. Please check your ID or contact HR.';
    } else if (error.contains('password') || error.contains('Password')) {
      return 'Password requirements not met. Please use a stronger password.';
    } else if (error.contains('Aadhar') || error.contains('aadhar')) {
      return 'Aadhar number already registered. Please check the number or contact HR.';
    } else if (error.contains('phone') || error.contains('Phone')) {
      return 'Phone number already registered. Please use a different number.';
    } else if (error.contains('server') || error.contains('Server')) {
      return 'Our system is temporarily unavailable. Please try again in a few minutes.';
    } else if (error.contains('timeout') || error.contains('Time')) {
      return 'Request timed out. Please check your connection and try again.';
    } else if (error.toLowerCase().contains('invalid')) {
      return 'Please check all fields and try again. Some information appears to be incorrect.';
    }

    // Generic but friendly error
    return 'Something went wrong. Please check your information and try again. If the problem continues, contact HR support.';
  }

  // Validation functions with friendly messages
  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your full name';
    }
    if (value.length < 2) {
      return 'Name should be at least 2 characters long';
    }
    if (value.length > 100) {
      return 'Name is too long (max 100 characters)';
    }
    return null;
  }

  String? _validateEmployeeId(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your Employee ID';
    }
    if (value.length < 3) {
      return 'Employee ID should be at least 3 characters';
    }
    if (value.length > 20) {
      return 'Employee ID is too long (max 20 characters)';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email address';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address (e.g., name@company.com)';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    final phoneRegex = RegExp(r'^[0-9]{10}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Please enter a valid 10-digit phone number';
    }
    return null;
  }

  String? _validateDepartment(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your department';
    }
    if (value.length < 2) {
      return 'Please enter a valid department name';
    }
    return null;
  }

  String? _validateAadhar(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your Aadhar number';
    }
    final aadharRegex = RegExp(r'^[0-9]{12}$');
    if (!aadharRegex.hasMatch(value)) {
      return 'Please enter a valid 12-digit Aadhar number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please create a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Include at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Include at least one number';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _signUp() async {
    // Validate all fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final fullName = _nameController.text.trim();

      final response = await _apiService.registerEmployee(
        employeeId: _employeeIdController.text.trim(),
        fullName: fullName,
        email: _emailController.text.trim(),
        department: _departmentController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        aadharNumber: _aadharController.text.trim(),
        password: _passwordController.text.trim(),
        confirmPassword: _confirmPasswordController.text.trim(),
        avatar: null,
      );

      setState(() {
        _isLoading = false;
      });

      if (response == "Sign Up Successful!") {
        // Show success message
        _showSuccessDialog();
      } else {
        // Show friendly error message
        _showErrorDialog(_getFriendlyErrorMessage(response));
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });

      // Handle unexpected errors
      _showErrorDialog(
          'We encountered an unexpected issue. Please try again in a moment. If the problem continues, contact HR support.');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text(
              "Account Created!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome aboard! Your account has been created successfully.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              "You can now sign in with your Employee ID and password.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmployeeSignInPage(),
                ),
              );
            },
            child: Text(
              "Go to Sign In",
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text(
              "Unable to Sign Up",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red[800],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              "What you can try:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("• Check if you're connected to the internet"),
                  Text("• Verify your information is correct"),
                  Text("• Try again in a few minutes"),
                  Text("• Contact HR if the problem continues"),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "Try Again",
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showValidationHelper(
      BuildContext context, String title, List<String> tips) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: tips
              .map((tip) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text("• $tip"),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Got it"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool isSmallScreen = screenWidth < 600;
    final bool isLargeScreen = screenWidth > 1200;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF009688)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 24,
                vertical: isSmallScreen ? 8 : 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isLargeScreen ? 600 : 500,
                  minHeight: screenHeight * 0.8,
                ),
                child: Container(
                  padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Responsive icon
                        Container(
                          width: isSmallScreen ? 60 : 80,
                          height: isSmallScreen ? 60 : 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_add,
                            size: isSmallScreen ? 30 : 40,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        Text(
                          "Create Employee Account",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        Text(
                          "Fill in your details to get started",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: isSmallScreen ? 13 : 14,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 16 : 20),

                        // Name field with helper
                        _buildTextFieldWithHelper(
                          context,
                          _nameController,
                          "Full Name",
                          Icons.person,
                          _validateName,
                          "Name Tips",
                          [
                            "Use your legal full name",
                            "Include first and last name",
                            "Avoid special characters",
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 12),

                        // Employee ID field
                        _buildTextFieldWithHelper(
                          context,
                          _employeeIdController,
                          "Employee ID",
                          Icons.badge_outlined,
                          _validateEmployeeId,
                          "Employee ID",
                          [
                            "Enter your official Employee ID",
                            "Check your company ID card",
                            "Contact HR if you don't know your ID",
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 12),

                        // Email field
                        _buildTextFieldWithHelper(
                          context,
                          _emailController,
                          "Email",
                          Icons.email_outlined,
                          _validateEmail,
                          "Email Format",
                          [
                            "Use your company email if available",
                            "Format: name@example.com",
                            "Make sure it's a valid email address",
                          ],
                          keyboardType: TextInputType.emailAddress,
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 12),

                        // Phone field
                        _buildTextFieldWithHelper(
                          context,
                          _phoneController,
                          "Phone Number",
                          Icons.phone_outlined,
                          _validatePhone,
                          "Phone Number",
                          [
                            "Enter your 10-digit mobile number",
                            "Example: 9876543210",
                            "Include country code if outside India",
                          ],
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 12),

                        // Department field
                        _buildTextFieldWithHelper(
                          context,
                          _departmentController,
                          "Department",
                          Icons.work_outline,
                          _validateDepartment,
                          "Department",
                          [
                            "Enter your department name",
                            "Examples: MIPL, MITPL, MIPPL, MINPL",
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 12),

                        // Aadhar field
                        _buildTextFieldWithHelper(
                          context,
                          _aadharController,
                          "Aadhar Number",
                          Icons.credit_card_outlined,
                          _validateAadhar,
                          "Aadhar Number",
                          [
                            "Enter your 12-digit Aadhar number",
                            "Only numbers, no spaces or dashes",
                            "Example: 123456789012",
                          ],
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 12),

                        // Password field with strength indicator
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: "Create Password",
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.help_outline, size: 20),
                                      onPressed: () => _showValidationHelper(
                                        context,
                                        "Password Requirements",
                                        [
                                          "At least 6 characters long",
                                          "Include one uppercase letter (A-Z)",
                                          "Include one number (0-9)",
                                          "Make it memorable but secure",
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: isSmallScreen ? 14 : 16,
                                ),
                              ),
                              validator: _validatePassword,
                              onChanged: (value) => setState(() {}),
                            ),
                            SizedBox(height: 8),
                            // Simple password strength indicator
                            if (_passwordController.text.isNotEmpty)
                              _buildPasswordStrengthIndicator(),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 12),

                        // Confirm Password field
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
                              onPressed: () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isSmallScreen ? 14 : 16,
                            ),
                          ),
                          validator: _validateConfirmPassword,
                        ),
                        SizedBox(height: isSmallScreen ? 16 : 20),

                        // Sign Up Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF009688),
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 14 : 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_add,
                                          color: Colors.white),
                                      SizedBox(width: 10),
                                      Text(
                                        "Create Account",
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 15 : 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),

                        // Already have account
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account? ",
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 15,
                                color: Colors.grey[600],
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EmployeeSignInPage(),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                "Sign In Here",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF009688),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Help text
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[100]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.blue[700], size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Need help? Contact HR department for support.",
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 13,
                                    color: Colors.blue[800],
                                  ),
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
      ),
    );
  }

  Widget _buildTextFieldWithHelper(
    BuildContext context,
    TextEditingController controller,
    String label,
    IconData icon,
    String? Function(String?) validator,
    String helperTitle,
    List<String> helperTips, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: Icon(icon),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isSmallScreen ? 14 : 16,
                  ),
                ),
                validator: validator,
              ),
            ),
            IconButton(
              icon: Icon(Icons.help_outline, size: 20),
              onPressed: () =>
                  _showValidationHelper(context, helperTitle, helperTips),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    final password = _passwordController.text;
    int strength = 0;

    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.length >= 12) strength++;

    Color color;
    String text;

    switch (strength) {
      case 0:
      case 1:
        color = Colors.red;
        text = "Weak";
        break;
      case 2:
        color = Colors.orange;
        text = "Fair";
        break;
      case 3:
        color = Colors.blue;
        text = "Good";
        break;
      case 4:
        color = Colors.green;
        text = "Strong";
        break;
      default:
        color = Colors.grey;
        text = "";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Password strength: ",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: strength / 4,
          backgroundColor: Colors.grey[200],
          color: color,
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }
}
