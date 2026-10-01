import 'dart:convert';
import 'package:http/http.dart' as http;

class RESTService {
  final String baseUrl;

  RESTService(this.baseUrl);

  Future<Map<String, dynamic>> uploadText({required String jsonEncodedTextData}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/text'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncodedTextData,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'REST-Error: ${response.statusCode}: ${response.body}',
      );
    }

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> uploadPicture({required List<int> picture}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/picture'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        "picture": picture,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'REST-Error: ${response.statusCode}: ${response.body}',
      );
    }

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getLCDRequest() async {
    final response = await http.get(
      Uri.parse('$baseUrl/lcd_request'),
    );
    print("Status: ${response.statusCode}");
    print("Response: ${response.body}");
    if (response.statusCode != 200) {
      throw Exception(
        'REST-Error: ${response.statusCode}: ${response.body}',
      );
    }

    return jsonDecode(response.body);
  }
}