import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String employeeId;

  const EditProfileScreen({super.key, required this.employeeId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  File? _profileImage;
  String? _profileImageUrl;
  final ApiService apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await apiService.getProfile(widget.employeeId);
      setState(() {
        _nameController.text = profile['name'] ?? '';
        _emailController.text = profile['email'] ?? '';
        _mobileController.text = profile['mobile'] ?? '';
        _profileImageUrl = profile['profile_image']; // backend image URL
      });
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() => _profileImage = File(picked.path));
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // ✅ Call backend API to update profile and upload image
      final updatedProfile = await apiService.updateProfile(
        employeeId: widget.employeeId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        mobile: _mobileController.text.trim(),
        profileImage: _profileImage,
      );

      setState(() => _isLoading = false);

      if (updatedProfile != null && updatedProfile['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        // ✅ Return updated avatar URL to Dashboard
        Navigator.pop(context, updatedProfile['profile_image']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile.')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 195, 203, 234),
            Color.fromARGB(255, 195, 203, 234),
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
        keyboardType: keyboardType ?? TextInputType.text,
        style: const TextStyle(color: Color.fromARGB(255, 20, 20, 20)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color.fromARGB(179, 20, 20, 20)),
          border: InputBorder.none,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please enter $label';
          if (label == 'Email' && !value.contains('@'))
            return 'Enter a valid email';
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F222B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              "Update Your Profile",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[200],
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: const Color.fromARGB(255, 195, 203, 232),
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!) as ImageProvider
                    : (_profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : null),
                child: (_profileImage == null && _profileImageUrl == null)
                    ? const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 30,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField(label: "Name", controller: _nameController),
                  _buildTextField(
                    label: "Email",
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _buildTextField(
                    label: "Mobile",
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  InkWell(
                    onTap: _isLoading ? null : _submitProfile,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [
                            Color.fromARGB(255, 174, 135, 184),
                            Color.fromARGB(255, 89, 114, 213),
                          ],
                        ),
                        boxShadow: [
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
                                "Save Changes",
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
