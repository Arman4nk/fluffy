import 'package:matrix/matrix.dart';

import 'package:fluffychat/utils/inline_button_models.dart' as models;

extension InlineKeyboardExtension on Room {
  /// Send a text message with inline keyboard
  Future<String?> sendTextEventWithInlineKeyboard(
    String message, {
    required models.InlineKeyboard inlineKeyboard,
    String? txid,
    Event? inReplyTo,
    String? editEventId,
    bool parseMarkdown = true,
    bool parseCommands = true,
    String msgtype = MessageTypes.Text,
    String? threadRootEventId,
    String? threadLastEventId,
  }) async {
    final content = <String, dynamic>{
      'msgtype': msgtype,
      'body': message,
    };

    // Add inline keyboard data
    if (inlineKeyboard.hasButtons) {
      content.addAll(inlineKeyboard.toJson());
    }

    if (parseMarkdown) {
      try {
        final formatted = message; // For now, keep it simple without markdown parsing
        if (formatted != message) {
          content['format'] = 'org.matrix.custom.html';
          content['formatted_body'] = formatted;
        }
      } catch (e) {
        // If markdown parsing fails, continue without it
      }
    }

    return sendEvent(
      content,
      txid: txid,
      inReplyTo: inReplyTo,
      editEventId: editEventId,
      threadRootEventId: threadRootEventId,
      threadLastEventId: threadLastEventId,
    );
  }

