import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

abstract class AppConfig {
  static String _applicationName = 'Rayka';

  static String get applicationName => _applicationName;
  static String? _applicationWelcomeMessage;

  static String? get applicationWelcomeMessage => _applicationWelcomeMessage;
  static String _defaultHomeserver = 'https://core.gitanegaran.ir';

  static String get defaultHomeserver => _defaultHomeserver;
  static double fontSizeFactor = 1;
  static const Color chatColor = primaryColor;
  static Color? colorSchemeSeed = primaryColor;
  static const double messageFontSize = 16.0;
  static const bool allowOtherHomeservers = true;
  static const bool enableRegistration = true;
  static const Color primaryColor = Color(0xFF576dd5);
  static const Color primaryColorLight = Color(0xFFCCBDEA);
  static const Color secondaryColor = Color(0xFF41a2bc);
  static String _privacyUrl =
      'https://github.com/krille-chan/fluffychat/blob/main/PRIVACY.md';

  static const Set<String> defaultReactions = {'👍', '❤️', '😂', '😮', '😢'};

  static String get privacyUrl => _privacyUrl;
  static const String website = 'https://fluffychat.im';
  static const String enablePushTutorial =
      'https://github.com/krille-chan/fluffychat/wiki/Push-Notifications-without-Google-Services';
  static const String encryptionTutorial =
      'https://github.com/krille-chan/fluffychat/wiki/How-to-use-end-to-end-encryption-in-Rayka';
  static const String startChatTutorial =
      'https://github.com/krille-chan/fluffychat/wiki/How-to-Find-Users-in-Rayka';
  static const String appId = 'im.fluffychat.Rayka';
  static const String appOpenUrlScheme = 'im.fluffychat';
  static String _webBaseUrl = 'https://fluffychat.im/web';

  static String get webBaseUrl => _webBaseUrl;
  static const String sourceCodeUrl =
      'https://github.com/krille-chan/fluffychat';
  static const String supportUrl =
      'https://github.com/krille-chan/fluffychat/issues';
  static const String changelogUrl =
      'https://github.com/krille-chan/fluffychat/blob/main/CHANGELOG.md';
  static final Uri newIssueUrl = Uri(
    scheme: 'https',
    host: 'github.com',
    path: '/krille-chan/fluffychat/issues/new',
  );
  static bool renderHtml = true;
  static bool hideRedactedEvents = false;
  static bool hideUnknownEvents = true;
  static bool separateChatTypes = false;
  static bool autoplayImages = true;
  static bool sendTypingNotifications = true;
  static bool sendPublicReadReceipts = true;
  static bool swipeRightToLeftToReply = true;
  static bool? sendOnEnter;
  static bool showPresences = true;
  static bool displayNavigationRail = false;
  static bool experimentalVoip = false;
  static const bool hideTypingUsernames = false;
  static const String inviteLinkPrefix = 'https://matrix.to/#/';
  static const String deepLinkPrefix = 'im.fluffychat://chat/';
  static const String schemePrefix = 'matrix:';
  static const String pushNotificationsChannelId = 'fluffychat_push';
  static const String pushNotificationsAppId = 'chat.fluffy.fluffychat';
  static const double borderRadius = 18.0;
  static const double columnWidth = 360.0;
  static final Uri homeserverList = Uri(
    scheme: 'https',
    host: 'servers.joinmatrix.org',
    path: 'servers.json',
  );
  static String _loginBannerPath = 'assets/chatsi_login_banner.png';
  static final ValueNotifier<String> loginBannerPathNotifier = ValueNotifier(_loginBannerPath);

  static String get loginBannerPath => _loginBannerPath;

  static void loadFromJson(Map<String, dynamic> json) {
    Logs().v('[AppConfig] Loading config from JSON: $json');
    if (json['chat_color'] != null) {
      try {
        colorSchemeSeed = Color(json['chat_color']);
      } catch (e) {
        Logs().w(
          'Invalid color in config.json! Please make sure to define the color in this format: "0xffdd0000"',
          e,
        );
      }
    }
    if (json['application_name'] is String) {
      _applicationName = json['application_name'];
      Logs().v('[AppConfig] Set application name to: $_applicationName');
    }
    if (json['application_welcome_message'] is String) {
      _applicationWelcomeMessage = json['application_welcome_message'];
    }
    if (json['default_homeserver'] is String) {
      _defaultHomeserver = json['default_homeserver'];
    }
    if (json['privacy_url'] is String) {
      _privacyUrl = json['privacy_url'];
    }
    if (json['web_base_url'] is String) {
      _webBaseUrl = json['web_base_url'];
    }
    if (json['render_html'] is bool) {
      renderHtml = json['render_html'];
    }
    if (json['hide_redacted_events'] is bool) {
      hideRedactedEvents = json['hide_redacted_events'];
    }
    if (json['hide_unknown_events'] is bool) {
      hideUnknownEvents = json['hide_unknown_events'];
    }
    if (json['login_banner_path'] is String) {
      final newPath = json['login_banner_path'];
      Logs().v('[AppConfig] Updating login banner path from $_loginBannerPath to $newPath');
      _loginBannerPath = newPath;
      loginBannerPathNotifier.value = newPath;
    }
  }
}
