import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:matrix/matrix.dart';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_text_input_dialog.dart';
import 'package:fluffychat/widgets/future_loading_dialog.dart';
import 'package:fluffychat/widgets/matrix.dart';
import '../../utils/platform_infos.dart';
import '../../config/app_config.dart';
import 'login_view.dart';
import 'otp_verification.dart';
import '../../services/matrix_auth_api.dart';

enum LoginMethod {
  password,
  phone,
}

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  LoginController createState() => LoginController();
}

class LoginController extends State<Login> with ChangeNotifier {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  LoginMethod _loginMethod = LoginMethod.phone;
  LoginMethod get loginMethod => _loginMethod;

  String? _clientSecret; // Store client_secret for OTP flow

  @override
  void initState() {
    super.initState();
    // Set default homeserver
    Matrix.of(context).getLoginClient().homeserver =
        Uri.parse(AppConfig.defaultHomeserver);
  }

  void setLoginMethod(LoginMethod method) {
    setState(() {
      _loginMethod = method;
    });
  }

  bool loading = false;
  bool showPassword = false;
  String? usernameError;
  String? passwordError;
  String? phoneError;
  String? otpError;

  void toggleShowPassword() {
    setState(() {
      showPassword = !showPassword;
    });
  }

  Future<void> checkWellKnownWithCoolDown(String? _) async {
    // ... existing code ...
  }

  Future<void> login() async {
    if (loading) return;

    setState(() {
      usernameError = null;
      passwordError = null;
      phoneError = null;
      otpError = null;
      loading = true;
    });

    try {
      final client = Matrix.of(context).getLoginClient();

      if (_loginMethod == LoginMethod.password) {
        if (usernameController.text.isEmpty) {
          setState(() {
            usernameError = L10n.of(context).pleaseEnterYourUsername;
            loading = false;
          });
          return;
        }
        if (passwordController.text.isEmpty) {
          setState(() {
            passwordError = L10n.of(context).pleaseEnterYourPassword;
            loading = false;
          });
          return;
        }

        await client.login(
          LoginType.mLoginPassword,
          identifier: AuthenticationUserIdentifier(
            user: usernameController.text,
          ),
          password: passwordController.text,
        );
      } else if (_loginMethod == LoginMethod.phone) {
        // For phone login, we'll navigate to the OTP verification page
        if (phoneController.text.isEmpty) {
          setState(() {
            phoneError = L10n.of(context).pleaseEnterYourPhone;
            loading = false;
          });
          return;
        }

        if (!mounted) return;
        setState(() => loading = false); // Reset loading before navigation
        await sendSmsCode(context);
      }
    } catch (e) {
      setState(() {
        if (e is MatrixException) {
          if (e.error == 'M_FORBIDDEN') {
            passwordError = L10n.of(context).passwordIsWrong;
          } else if (e.error == 'M_USER_DEACTIVATED') {
            usernameError = L10n.of(context).deactivateAccountWarning;
          } else {
            usernameError = e.error.toString();
          }
        } else {
          usernameError = e.toString();
        }
        loading = false;
      });
    }
  }

  Future<void> sendSmsCode(BuildContext context) async {
    if (loading) return;

    setState(() {
      phoneError = null;
      loading = true;
    });

    try {
      if (phoneController.text.isEmpty) {
        setState(() {
          phoneError = L10n.of(context).pleaseEnterYourPhone;
          loading = false;
        });
        return;
      }

      final formattedPhone = phoneController.text.formatIranPhoneNumber();
      final result = await MatrixAuthApi.sendSmsCode(formattedPhone);

      if (!mounted) return;
      setState(() => loading = false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OtpVerification(
            phoneNumber: phoneController.text,
            sid: result['sid'],
            submitUrl: result['submit_url'],
            clientSecret: result['client_secret'],
            onOtpVerified: (otp) async {
              try {
                setState(() => loading = true);
                final client = Matrix.of(context).getLoginClient();
                // The login and navigation are now handled in the OtpVerification widget
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  loading = false;
                  phoneError = e.toString();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      setState(() {
        phoneError = e.toString();
        loading = false;
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  void passwordForgotten() async {
    final input = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).passwordForgotten,
      message: L10n.of(context).enterAnEmailAddress,
      okLabel: L10n.of(context).ok,
      cancelLabel: L10n.of(context).cancel,
      initialText:
          usernameController.text.isEmail ? usernameController.text : '',
      hintText: L10n.of(context).enterAnEmailAddress,
      keyboardType: TextInputType.emailAddress,
    );
    if (input == null) return;
    final clientSecret = DateTime.now().millisecondsSinceEpoch.toString();
    final response = await showFutureLoadingDialog(
      context: context,
      future: () =>
          Matrix.of(context).getLoginClient().requestTokenToResetPasswordEmail(
                clientSecret,
                input,
                sendAttempt++,
              ),
    );
    if (response.error != null) return;
    final password = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).passwordForgotten,
      message: L10n.of(context).chooseAStrongPassword,
      okLabel: L10n.of(context).ok,
      cancelLabel: L10n.of(context).cancel,
      hintText: '******',
      obscureText: true,
      minLines: 1,
      maxLines: 1,
    );
    if (password == null) return;
    final ok = await showOkAlertDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).weSentYouAnEmail,
      message: L10n.of(context).pleaseClickOnLink,
      okLabel: L10n.of(context).iHaveClickedOnLink,
    );
    if (ok != OkCancelResult.ok) return;
    final data = <String, dynamic>{
      'new_password': password,
      'logout_devices': false,
      "auth": AuthenticationThreePidCreds(
        type: AuthenticationTypes.emailIdentity,
        threepidCreds: ThreepidCreds(
          sid: response.result!.sid,
          clientSecret: clientSecret,
        ),
      ).toJson(),
    };
    final success = await showFutureLoadingDialog(
      context: context,
      future: () => Matrix.of(context).getLoginClient().request(
            RequestType.POST,
            '/client/v3/account/password',
            data: data,
          ),
    );
    if (success.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).passwordHasBeenChanged)),
      );
      usernameController.text = input;
      passwordController.text = password;
      login();
    }
  }

  static int sendAttempt = 0;

  @override
  Widget build(BuildContext context) => LoginView(this);
}

extension on String {
  static final RegExp _phoneRegex =
      RegExp(r'^[+]*[(]{0,1}[0-9]{1,4}[)]{0,1}[-\s\./0-9]*$');
  static final RegExp _emailRegex = RegExp(r'(.+)@(.+)\.(.+)');

  bool get isEmail => _emailRegex.hasMatch(this);
  bool get isPhoneNumber => _phoneRegex.hasMatch(this);
}
