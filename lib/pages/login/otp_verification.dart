import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/widgets/layouts/login_scaffold.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:matrix/matrix.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import '../../services/matrix_auth_api.dart';
import 'dart:async';

class OtpVerification extends StatefulWidget {
  final String phoneNumber;
  String sid;
  final String submitUrl;
  String clientSecret;
  final Function(String) onOtpVerified;

  OtpVerification({
    super.key,
    required this.phoneNumber,
    required this.sid,
    required this.submitUrl,
    required this.clientSecret,
    required this.onOtpVerified,
  });

  @override
  State<OtpVerification> createState() => _OtpVerificationState();
}

class _OtpVerificationState extends State<OtpVerification> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _error;
  int _timeLeft = 120; // 2 minutes countdown
  bool _canResend = false;
  Timer? _timer;
  String? _currentClientSecret; // Track the current client secret
  String? _currentSid; // Track the current sid

  @override
  void initState() {
    super.initState();
    _currentClientSecret = widget.clientSecret; // Initialize with the initial client secret
    _currentSid = widget.sid; // Initialize with the initial sid
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Only dispose the controller if it's not being used
    if (!_isLoading) {
      _otpController.dispose();
    }
    super.dispose();
  }

  void _resetOtp() {
    if (_otpController.text.isNotEmpty) {
      _otpController.clear();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _timeLeft = 10;
      _canResend = false;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  String get _timeLeftString {
    final minutes = (_timeLeft / 60).floor();
    final seconds = _timeLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyOtp() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final isVerified = await MatrixAuthApi.verifyOtp(
        sid: _currentSid ?? widget.sid, // Use the current sid
        clientSecret: _currentClientSecret ?? widget.clientSecret, // Use the current client secret
        otp: _otpController.text,
        submitUrl: widget.submitUrl,
      );

      if (isVerified) {
        final client = Matrix.of(context).getLoginClient();

        try {
          final loginResponse = await MatrixAuthApi.customPhoneLogin(
            client: client,
            phoneNumber: await widget.phoneNumber.formatInternationalPhoneNumber() ?? widget.phoneNumber,
            clientSecret: _currentClientSecret ?? widget.clientSecret,
            sid: _currentSid ?? widget.sid,
          );

          if (mounted) {
            widget.onOtpVerified(_otpController.text);
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _error = 'Login failed: ${e.toString()}';
              _resetOtp();
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Verification failed';
            _resetOtp();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _resetOtp();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
      _error = null;
    });

    try {
      final response = await MatrixAuthApi.sendSmsCode(
        await widget.phoneNumber.formatInternationalPhoneNumber() ?? widget.phoneNumber,
      );

      if (response != null) {
        setState(() {
          _currentSid = response['sid']; // Update the current sid
          _currentClientSecret = response['client_secret']; // Update the current client secret
        });
        _startTimer();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    return LoginScaffold(
      appBar: AppBar(
        title: Text(l10n.otp),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Hero(
                    tag: 'info-logo',
                    child: Image.asset(
                      Theme.of(context).brightness == Brightness.light
                          ? "assets/otp_banner_light.png"
                          : "assets/otp_banner_dark.png",
                      height: 220,
                    ),
                  ),
                ),
              ),
              Text(
                l10n.pleaseEnterOTP,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.otpCodeSentTo(widget.phoneNumber.replaceFirst('+', '')),
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.start,
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 32),
              Directionality(
                textDirection: TextDirection.ltr,
                child: PinCodeTextField(
                  appContext: context,
                  length: 6,
                  controller: _otpController,
                  onChanged: (value) {},
                  autoDisposeControllers: false,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
                    fieldHeight: 50,
                    fieldWidth: 50,
                    activeFillColor: theme.colorScheme.surface,
                    inactiveFillColor: theme.colorScheme.surface,
                    selectedFillColor: theme.colorScheme.surface,
                    activeColor: AppConfig.primaryColor,
                    inactiveColor: theme.colorScheme.outline,
                    selectedColor: AppConfig.primaryColor,
                  ),
                  keyboardType: TextInputType.number,
                  enableActiveFill: true,
                  onCompleted: (value) {
                    if (!_isLoading) {
                      _verifyOtp();
                    }
                  },
                ),
              ),
              // const SizedBox(height: 32),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.primaryColor,
                  foregroundColor: theme.colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const LinearProgressIndicator()
                    : Text(l10n.verify),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _canResend && !_isResending ? _resendCode : null,
                child: _isResending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppConfig.primaryColor,
                          ),
                        ),
                      )
                    : RichText(
                        textAlign: TextAlign.start,
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'IRANYekanXFaNumber',
                            color: theme.textTheme.bodyMedium?.color,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: '${l10n.resendCodePrefix} ',
                            ),
                            if (_canResend)
                              TextSpan(
                                text: l10n.resendCodeAction,
                                style: const TextStyle(
                                  fontFamily: 'IRANYekanXFaNumber',
                                  color: AppConfig.primaryColor,
                                ),
                              )
                            else
                              TextSpan(
                                text: '(${_timeLeftString}) ${l10n.resendCodeAction}',
                                style: TextStyle(
                                  fontFamily: 'IRANYekanXFaNumber',
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              TextButton(
                onPressed: () {
                  context.pop(); // Go back to login page
                },
                child: RichText(
                  textAlign: TextAlign.start,
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'IRANYekanXFaNumber',
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 14,
                    ),
                    children: [
                      TextSpan(
                        text: '${l10n.wrongNumberPrefix} ',
                      ),
                      TextSpan(
                        text: l10n.wrongNumberAction,
                        style: TextStyle(
                          fontFamily: 'IRANYekanXFaNumber',
                          color: AppConfig.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

