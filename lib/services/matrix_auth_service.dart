import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';
import 'package:flutter/foundation.dart';
import '../utils/platform_infos.dart';
import 'package:uuid/uuid.dart';

class MatrixAuthService {
  static int sendAttempt = 0;
  static final _uuid = Uuid();

  static Future<Map<String, dynamic>> sendSmsCode(String phoneNumber) async {
    final clientSecret =
        _uuid.v4(); // Using UUID v4 for secure random generation

    final payload = {
      "client_secret": clientSecret,
      "country": "IR",
      "phone_number": phoneNumber,
      "send_attempt": ++sendAttempt,
    };

    final response = await http.post(
      Uri.parse(
          "https://core.gitanegaran.ir/_matrix/client/v3/login/msisdn/requestToken"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'sid': data["sid"],
        'submit_url': data["submit_url"],
        'client_secret': clientSecret,
      };
    } else {
      throw Exception("Failed to send SMS: ${response.body}");
    }
  }
}
