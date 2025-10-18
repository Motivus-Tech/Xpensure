import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String employeeId;
  final String authToken;

  const EditProfileScreen({
    super.key,
    required this.employeeId,
    required this.authToken,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();

  File? _imageFile;
  String? _profileImageUrl;
  ImageProvider<Object>? _avatarImage;

  final apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await apiService.getProfile(
        employeeId: widget.employeeId,
        authToken: widget.authToken,
      );

      _nameController.text = profile['fullName'] ?? profile['full_name'] ?? '';
      _emailController.text = profile['email'] ?? '';
      _mobileController.text =
          profile['phone_number'] ?? profile['phone'] ?? '';

      _profileImageUrl = profile['avatar'];
      _avatarImage = (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
          ? NetworkImage(_profileImageUrl!)
          : null;

      setState(() {});
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to load profile")));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // REMOVED _pickImage method since profile picture cannot be changed

  // REMOVED _saveProfile method since no changes can be made

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 55,
      backgroundColor: const Color(0xFF2C2F38),
      backgroundImage: _avatarImage,
      child: _avatarImage == null
          ? Text(
              _nameController.text.isNotEmpty
                  ? _nameController.text.trim()[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2F38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isNotEmpty ? value : 'Not provided',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        title: const Text(
          "View Profile", // Changed from "Edit Profile"
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1F222B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Removed edit/save actions since it's view-only
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Picture - Centered and non-interactive
                  Center(
                    child: _buildAvatar(),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      "Profile Picture",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Personal Information Section
                  const Text(
                    "Personal Information",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Your profile details are managed by HR",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Full Name - Read Only
                  _buildReadOnlyField("Full Name", _nameController.text),
                  const SizedBox(height: 15),

                  // Email - Read Only
                  _buildReadOnlyField("Email Address", _emailController.text),
                  const SizedBox(height: 15),

                  // Mobile Number - Read Only
                  _buildReadOnlyField("Mobile Number", _mobileController.text),
                  const SizedBox(height: 15),

                  // Employee ID - Read Only
                  _buildReadOnlyField("Employee ID", widget.employeeId),
                  const SizedBox(height: 30),

                  // Information Message
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "To update your profile information, please contact your HR department",
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Close Button (instead of Save Changes)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF849CFC),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text("Close"),
                  ),
                ],
              ),
            ),
    );
  }
}
