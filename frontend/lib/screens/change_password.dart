import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String employeeId;
  const ChangePasswordScreen({super.key, required this.employeeId});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  final ApiService apiService = ApiService();

  // NEW: Toggle visibility for each password field
  bool _showOldPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Step 1: Verify old password
      bool oldPasswordValid = await apiService.verifyOldPassword(
        employeeId: widget.employeeId,
        oldPassword: _oldPasswordController.text.trim(),
      );

      if (!oldPasswordValid) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Old password is incorrect')),
        );
        return;
      }

      // Step 2: Update to new password
      bool success = await apiService.changePassword(
        employeeId: widget.employeeId,
        newPassword: _newPasswordController.text.trim(),
      );

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Password changed successfully!'
                : 'Failed to change password.',
          ),
        ),
      );

      if (success) Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool showPassword,
    required VoidCallback togglePassword,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 188, 198, 238),
            Color.fromARGB(255, 188, 198, 238),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: !showPassword,
        style: const TextStyle(color: Color.fromARGB(255, 9, 8, 8)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color.fromARGB(179, 19, 18, 18)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              showPassword ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey[700],
            ),
            onPressed: togglePassword,
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please enter $label';
          if (label == 'Confirm New Password' &&
              value != _newPasswordController.text) {
            return 'Passwords do not match';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF252525),
        title: const Text(
          "Change Password",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              "Change Your Password",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[200],
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildPasswordField(
                    label: "Old Password",
                    controller: _oldPasswordController,
                    showPassword: _showOldPassword,
                    togglePassword: () =>
                        setState(() => _showOldPassword = !_showOldPassword),
                  ),
                  _buildPasswordField(
                    label: "New Password",
                    controller: _newPasswordController,
                    showPassword: _showNewPassword,
                    togglePassword: () =>
                        setState(() => _showNewPassword = !_showNewPassword),
                  ),
                  _buildPasswordField(
                    label: "Confirm New Password",
                    controller: _confirmPasswordController,
                    showPassword: _showConfirmPassword,
                    togglePassword: () => setState(
                      () => _showConfirmPassword = !_showConfirmPassword,
                    ),
                  ),
                  const SizedBox(height: 24),
                  InkWell(
                    onTap: _isLoading ? null : _submitChangePassword,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [
                            Color.fromARGB(255, 174, 135, 184),
                            Color.fromARGB(255, 88, 120, 248),
                          ],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Submit",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
