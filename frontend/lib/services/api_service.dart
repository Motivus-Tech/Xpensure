import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'http://10.0.2.2:8000'; // Use your backend URL here

  Future<bool> registerEmployee({
    required String fullName,
    required String employeeId,
    required String department,
    required String phone,
    required String email,
    required String aadhar,
    required String password,
    required String confirmPassword,
    File? profileImage,
  }) async {
    final uri = Uri.parse('$baseUrl/employee/register/');

    var request = http.MultipartRequest('POST', uri);
    request.fields['username'] = fullName;
    request.fields['employee_id'] = employeeId;
    request.fields['department'] = department;
    request.fields['phone_number'] = phone;
    request.fields['email'] = email;
    request.fields['aadhar_card'] = aadhar;
    request.fields['password'] = password;
    request.fields['confirm_password'] = confirmPassword;

    if (profileImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath('profile_photo', profileImage.path),
      );
    }

    final response = await request.send();

    return response.statusCode == 201;
  }

  Future<bool> login(String employeeId, String password) async {
    final uri = Uri.parse('$baseUrl/employee/login/');
    final response = await http.post(
      uri,
      body: {'employee_id': employeeId, 'password': password},
    );

    if (response.statusCode == 200) {
      // You can parse response.body here if needed
      return true;
    } else {
      return false;
    }
  }
}
