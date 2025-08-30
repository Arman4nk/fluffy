import 'package:matrix/matrix.dart';

class BotUtils {
  /// Checks if a user is a bot based on their Matrix ID
  /// Bot usernames typically end with "bot" before the domain
  static bool isBotUser(String userId) {
    try {
      // Extract the localpart (before the colon)
      final localpart = userId.split(':')[0];
      return localpart.toLowerCase().endsWith('bot');
    } catch (e) {
      return false;
    }
  }

  /// Checks if a room is a direct message with a bot
  static bool isDirectMessageWithBot(Room room) {
    final directChatMatrixId = room.directChatMatrixID;
    if (directChatMatrixId == null) return false;
    return isBotUser(directChatMatrixId);
  }

  /// Gets the last message from a bot that contains keyboard data
  /// Requires a timeline to be passed from the chat controller
  static Event? getLastBotMessageWithKeyboard(Room room, Timeline? timeline) {
    if (!isDirectMessageWithBot(room) || timeline == null) return null;
    
    final directChatMatrixId = room.directChatMatrixID!;
    
    // Get recent events from the timeline
    final events = timeline.events.where((event) => 
        event.senderId == directChatMatrixId &&
        event.type == EventTypes.Message &&
        event.content['keyboard'] != null,
    );
    
    if (events.isEmpty) return null;
    
    // Return the most recent message with keyboard
    return events.first;
  }

  /// Checks if the bot has sent any messages in the timeline
  static bool hasBotSentAnyMessages(Room room, Timeline? timeline) {
    if (!isDirectMessageWithBot(room) || timeline == null) return false;
    
    final directChatMatrixId = room.directChatMatrixID!;
    
    // Check if there are any message events from the bot
    final botMessages = timeline.events.where((event) => 
        event.senderId == directChatMatrixId &&
        event.type == EventTypes.Message,
    );
    
    return botMessages.isNotEmpty;
  }

  /// Extracts keyboard data from a message event
  static Map<String, dynamic>? extractKeyboardData(Event event) {
    try {
      final content = event.content;
      return content['keyboard'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Converts keyboard data to the format expected by CustomKeyboard widget
  static List<List<Map<String, String>>> parseKeyboardButtons(Map<String, dynamic> keyboardData) {
    try {
      final buttons = keyboardData['buttons'] as List?;
      if (buttons == null) return [];

      return buttons.map<List<Map<String, String>>>((row) {
        if (row is! List) return <Map<String, String>>[];
        
        return row.map<Map<String, String>>((button) {
          if (button is! Map) return <String, String>{};
          
          return {
            'text': button['text']?.toString() ?? '',
            'callback_data': button['callback_data']?.toString() ?? '',
          };
        }).toList();
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Gets the input field placeholder from keyboard data
  static String? getInputPlaceholder(Map<String, dynamic> keyboardData) {
    try {
      return keyboardData['input_field_placeholder']?.toString();
    } catch (e) {
      return null;
    }
  }

  /// Checks if the keyboard should be persistent
  static bool isKeyboardPersistent(Map<String, dynamic> keyboardData) {
    try {
      return keyboardData['is_persistent'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Checks if the keyboard should resize
  static bool shouldResizeKeyboard(Map<String, dynamic> keyboardData) {
    try {
      final value = keyboardData['resize_keyboard'];
      if (value == null) return true; // Default to true when key is missing
      return value == true;
    } catch (e) {
      return true; // Default to true
    }
  }
} 