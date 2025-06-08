import 'package:flutter/material.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:phone_form_field/phone_form_field.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/layouts/login_scaffold.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:matrix/matrix.dart';
import 'login.dart';

class LoginView extends StatelessWidget {
  final LoginController controller;

  const LoginView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    final homeserver = Matrix.of(context)
        .getLoginClient()
        .homeserver
        .toString()
        .replaceFirst('https://', '');
    final title = l10n.logInTo(homeserver);
    final titleParts = title.split(homeserver);

    return LoginScaffold(
      enforceMobileMode: Matrix.of(context).client.isLogged(),
      appBar: AppBar(
        leading: controller.loading ? null : const Center(child: BackButton()),
        automaticallyImplyLeading: !controller.loading,
        titleSpacing: !controller.loading ? 0 : null,
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: l10n.login),
              // TextSpan(
              //   text: homeserver,
              //   style: const TextStyle(fontWeight: FontWeight.bold),
              // ),
              // TextSpan(text: titleParts.last),
            ],
          ),
          style: const TextStyle(fontSize: 18),
        ),
      ),
      body: Builder(
        builder: (context) {
          return AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Hero(
                    tag: 'info-logo',
                    child: ValueListenableBuilder<String>(
                      valueListenable: AppConfig.loginBannerPathNotifier,
                      builder: (context, bannerPath, _) {
                        return Image.asset(
                          bannerPath,
                          errorBuilder: (context, error, stackTrace) {
                            Logs().e('Failed to load image: $bannerPath', error, stackTrace);
                            return const Icon(Icons.error);
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Login method selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Material(
                    borderRadius:
                        BorderRadius.circular(AppConfig.borderRadius / 2),
                    color: theme.colorScheme.onInverseSurface,
                    child: DropdownButton<LoginMethod>(
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      borderRadius:
                          BorderRadius.circular(AppConfig.borderRadius / 2),
                      underline: const SizedBox.shrink(),
                      value: controller.loginMethod,
                      items: [
                        DropdownMenuItem(
                          value: LoginMethod.password,
                          child: Row(
                            children: [
                              const Icon(Icons.lock_outline),
                              const SizedBox(width: 8),
                              Text(l10n.passwordLogin),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: LoginMethod.phone,
                          child: Row(
                            children: [
                              const Icon(Icons.phone_outlined),
                              const SizedBox(width: 8),
                              Text(l10n.phoneLogin),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          controller.setLoginMethod(value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Username/Phone field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: controller.loginMethod == LoginMethod.password
                    ? TextField(
                        readOnly: controller.loading,
                        autocorrect: false,
                        autofocus: true,
                        onChanged: controller.checkWellKnownWithCoolDown,
                        controller: controller.usernameController,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: controller.loading
                            ? null
                            : [AutofillHints.username],
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.account_box_outlined),
                          errorText: controller.usernameError,
                          errorStyle: const TextStyle(color: Colors.orange),
                          hintText: '@username:domain',
                          labelText: l10n.emailOrUsername,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: PhoneFormField(
                              controller: PhoneController(
                                PhoneNumber(
                                  isoCode: IsoCode.IR,
                                  nsn: '',
                                ),
                              ),
                              decoration: InputDecoration(
                                hintText: L10n.of(context).phoneNumber,
                                errorText: controller.phoneError,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.send),
                                  onPressed: controller.loading
                                      ? null
                                      : () => controller.sendSmsCode(context),
                                ),
                              ),
                              onChanged: (phone) {
                                if (phone != null && phone.isValid()) {
                                  controller.phoneController.text = phone.international;
                                  controller.checkWellKnownWithCoolDown(phone.international);
                                }
                              },
                              defaultCountry: IsoCode.IR,
                              showFlagInInput: true,
                              flagSize: 16,
                              countrySelectorNavigator: CountrySelectorNavigator.bottomSheet(),
                            ),
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: 16),
                // Password field (only show for password login)
                if (controller.loginMethod == LoginMethod.password)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: TextField(
                      readOnly: controller.loading,
                      autocorrect: false,
                      autofillHints:
                          controller.loading ? null : [AutofillHints.password],
                      controller: controller.passwordController,
                      textInputAction: TextInputAction.go,
                      obscureText: !controller.showPassword,
                      onSubmitted: (_) => controller.login(),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outlined),
                        errorText: controller.passwordError,
                        errorStyle: const TextStyle(color: Colors.orange),
                        
                        suffixIcon: IconButton(
                          onPressed: controller.toggleShowPassword,
                          icon: Icon(
                            controller.showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.black,
                          ),
                        ),
                        hintText: '******',
                        labelText: l10n.password,
                      ),
                    ),
                  ),
                if (controller.loginMethod == LoginMethod.password)
                  const SizedBox(height: 16),
                // Login button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.primaryColor,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    onPressed: controller.loading ? null : controller.login,
                    child: controller.loading
                        ? const LinearProgressIndicator()
                        : Text(l10n.login),
                  ),
                ),
                const SizedBox(height: 16),
                if (controller.loginMethod == LoginMethod.password)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: TextButton(
                      onPressed: controller.loading
                          ? () {}
                          : controller.passwordForgotten,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      child: Text(l10n.passwordForgotten),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
