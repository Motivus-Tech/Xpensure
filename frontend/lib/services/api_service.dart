import 'package:http/http.dart' as http;

class ApiService {
  // Replace with your laptop's local IP address and backend port
  final String baseUrl = "http://192.168.1.5:5000";

  // Function to test connection
  Future<String> testConnection() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/test"));

      if (response.statusCode == 200) {
        return "Connected: ${response.body}";
      } else {
        return "Failed: ${response.statusCode}";
      }
    } catch (e) {
      return "Error: $e";
    }
  }
}
