import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';
import 'package:flutter/foundation.dart';
import '../utils/platform_infos.dart';
import 'package:uuid/uuid.dart';
import 'package:fluffychat/config/app_config.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

class MatrixAuthApi {
  static int sendAttempt = 0;
  static final _uuid = Uuid();

  static Future<Map<String, dynamic>> sendSmsCode(String phoneNumber) async {
    final clientSecret = _uuid.v4(); // Using UUID v4 for secure random generation

    final payload = {
      "client_secret": clientSecret,
      "country": "IR",
      "phone_number": phoneNumber,
      "send_attempt": ++sendAttempt,
    };

    final response = await http.post(
      Uri.parse( "${AppConfig.defaultHomeserver}/_matrix/client/v3/login/msisdn/requestToken"),
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

  static Future<bool> verifyOtp({
    required String sid,
    required String clientSecret,
    required String otp,
    required String submitUrl,
  }) async {
    final payload = {
      "sid": sid,
      "client_secret": clientSecret,
      "token": otp,
    };

    final response = await http.post(
      Uri.parse(submitUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    return response.statusCode == 200;
  }

  static Future<LoginResponse> customPhoneLogin({
    required Client client,
    required String phoneNumber,
    required String clientSecret,
    required String sid,
  }) async {
    try {
      client.onLoginStateChanged.stream.listen((state) {
        debugPrint('Login state changed to: $state');
      });

      // Defensive fix: Ensure homeserver is set and has a valid scheme, using AppConfig.defaultHomeserver
      if (client.homeserver == null ||
          !client.homeserver.toString().startsWith('http')) {
        client.homeserver = Uri.parse(AppConfig.defaultHomeserver);
      }
      debugPrint('Using homeserver: [32m${client.homeserver}[0m');

      final loginParams = {
        'type': 'm.login.msisdn',
        'identifier': {
          'type': 'm.id.phone',
          'country': 'IR',
          'phone': phoneNumber,
          'user': phoneNumber,
        },
        'password': '',
        'initial_device_display_name': PlatformInfos.clientName,
        'threepid_creds': {
          'client_secret': clientSecret,
          'sid': sid,
        },
      };

      final response = await client.httpClient.post(
        Uri.parse('${client.homeserver}/_matrix/client/v3/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(loginParams),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Login successful, initializing client...');

        await client.init(
          newToken: data['access_token'],
          newDeviceID: data['device_id'],
          newUserID: data['user_id'],
          newDeviceName: PlatformInfos.clientName,
          newHomeserver: client.homeserver,
        );

        debugPrint('Client initialized, login state should be updated');
        return LoginResponse.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        debugPrint('Login failed with error: $error');
        throw MatrixException.fromJson(error);
      }
    } catch (e) {
      debugPrint('Login error: $e');
      throw MatrixException.fromJson({'error': e.toString()});
    }
  }
}

extension PhoneNumberFormatter on String {
  /// Formats a phone number to international format
  Future<String?> formatInternationalPhoneNumber() async {
    try {
      final phoneNumber = PhoneNumber.parse(this);
      return phoneNumber.international;
    } catch (e) {
      return null;
    }
  }

  /// Validates if the phone number is valid
  Future<bool> isValidPhoneNumber() async {
    try {
      final phoneNumber = PhoneNumber.parse(this);
      return phoneNumber.isValid();
    } catch (e) {
      return false;
    }
  }
}
