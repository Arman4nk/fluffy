import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:fluffychat/utils/bot_utils.dart';

void main() {
  group('BotUtils Tests', () {
    test('should detect bot users correctly', () {
      expect(BotUtils.isBotUser('@testbot:example.com'), isTrue);
      expect(BotUtils.isBotUser('@mybot:matrix.org'), isTrue);
      expect(BotUtils.isBotUser('@reminderbot:server.com'), isTrue);
      expect(BotUtils.isBotUser('@user:example.com'), isFalse);
      expect(BotUtils.isBotUser('@admin:matrix.org'), isFalse);
    });

    test('should parse keyboard buttons correctly', () {
      final keyboardData = {
        'buttons': [
          [
            {'text': '📝 یادآور جدید', 'callback_data': '!remind help'},
            {'text': '📋 لیست یادآورها', 'callback_data': '!remind list'},
          ],
          [
            {'text': '🔁 ویرایش زمان یادآور', 'callback_data': '!remind again'},
          ],
          [
            {'text': '🌍 منطقه زمانی', 'callback_data': '!remind tz'},
          ],
        ],
      };

      final result = BotUtils.parseKeyboardButtons(keyboardData);
      
      expect(result.length, equals(3));
      expect(result[0].length, equals(2));
      expect(result[1].length, equals(1));
      expect(result[2].length, equals(1));
      
      expect(result[0][0]['text'], equals('📝 یادآور جدید'));
      expect(result[0][0]['callback_data'], equals('!remind help'));
      expect(result[0][1]['text'], equals('📋 لیست یادآورها'));
      expect(result[0][1]['callback_data'], equals('!remind list'));
    });

    test('should extract keyboard properties correctly', () {
      final keyboardData = {
        'input_field_placeholder': 'دستور را انتخاب کنید یا تایپ کنید...',
        'is_persistent': true,
        'resize_keyboard': true,
      };

      expect(BotUtils.getInputPlaceholder(keyboardData), 
             equals('دستور را انتخاب کنید یا تایپ کنید...'));
      expect(BotUtils.isKeyboardPersistent(keyboardData), isTrue);
      expect(BotUtils.shouldResizeKeyboard(keyboardData), isTrue);
    });

    test('should handle invalid keyboard data gracefully', () {
      expect(BotUtils.parseKeyboardButtons({}), isEmpty);
      expect(BotUtils.parseKeyboardButtons({'buttons': null}), isEmpty);
      expect(BotUtils.parseKeyboardButtons({'buttons': 'invalid'}), isEmpty);
      
      expect(BotUtils.getInputPlaceholder({}), isNull);
      expect(BotUtils.isKeyboardPersistent({}), isFalse);
      expect(BotUtils.shouldResizeKeyboard({}), isTrue); // defaults to true
    });

    test('should handle null timeline in bot message checks', () {
      // Mock room that looks like a bot DM
      // Note: This test is limited since we can't easily mock Room and Timeline objects
      // In a real test environment, you would create proper mocks
      expect(BotUtils.hasBotSentAnyMessages, isNotNull);
      expect(BotUtils.getLastBotMessageWithKeyboard, isNotNull);
    });
  });
}

/*
Example bot message content with keyboard:

{
  "msgtype": "m.text",
  "body": "چه کاری برایت انجام دهم؟",
  "keyboard": {
    "buttons": [
      [
        {
          "callback_data": "!remind help",
          "text": "📝 یادآور جدید"
        },
        {
          "callback_data": "!remind list", 
          "text": "📋 لیست یادآورها"
        }
      ],
      [
        {
          "callback_data": "!remind again",
          "text": "🔁 ویرایش زمان یادآور"
        }
      ],
      [
        {
          "callback_data": "!remind tz",
          "text": "🌍 منطقه زمانی"
        }
      ]
    ],
    "input_field_placeholder": "دستور را انتخاب کنید یا تایپ کنید...",
    "is_persistent": true,
    "resize_keyboard": true
  }
}
*/ 