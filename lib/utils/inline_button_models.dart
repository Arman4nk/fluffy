import 'package:flutter/foundation.dart';

/// Enum for inline button types
enum InlineButtonType {
  text,
  link,
  media,
  date,
  time,
  datetime,
  map,
}

/// Extension to convert string to InlineButtonType
extension InlineButtonTypeExtension on String {
  InlineButtonType? get toInlineButtonType {
    switch (toLowerCase()) {
      case 'text':
        return InlineButtonType.text;
      case 'link':
        return InlineButtonType.link;
      case 'media':
        return InlineButtonType.media;
      case 'date':
        return InlineButtonType.date;
      case 'time':
        return InlineButtonType.time;
      case 'datetime':
        return InlineButtonType.datetime;
      case 'map':
        return InlineButtonType.map;
      default:
        return null;
    }
  }
}

/// Data model for an inline button
@immutable
class InlineButton {
  final String text;
  final InlineButtonType type;
  final String? callbackData;
  final String? url;
  final String? mediaType;
  final String? locationType;

  const InlineButton({
    required this.text,
    required this.type,
    this.callbackData,
    this.url,
    this.mediaType,
    this.locationType,
  });

  /// Create from JSON map
  factory InlineButton.fromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String? ?? 'text';
    final type = typeString.toInlineButtonType ?? InlineButtonType.text;

    return InlineButton(
      text: json['text'] as String? ?? '',
      type: type,
      callbackData: json['callback_data'] as String?,
      url: json['url'] as String?,
      mediaType: json['media_type'] as String?,
      locationType: json['location_type'] as String?,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'text': text,
      'type': type.name,
    };

    if (callbackData != null) data['callback_data'] = callbackData;
    if (url != null) data['url'] = url;
    if (mediaType != null) data['media_type'] = mediaType;
    if (locationType != null) data['location_type'] = locationType;

    return data;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InlineButton &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          type == other.type &&
          callbackData == other.callbackData &&
          url == other.url &&
          mediaType == other.mediaType &&
          locationType == other.locationType;

  @override
  int get hashCode =>
      text.hashCode ^
      type.hashCode ^
      (callbackData?.hashCode ?? 0) ^
      (url?.hashCode ?? 0) ^
      (mediaType?.hashCode ?? 0) ^
      (locationType?.hashCode ?? 0);

  @override
  String toString() {
    return 'InlineButton{text: $text, type: $type, callbackData: $callbackData, url: $url, mediaType: $mediaType, locationType: $locationType}';
  }
}

/// Data model for inline keyboard structure
@immutable
class InlineKeyboard {
  final List<List<InlineButton>> buttons;

  const InlineKeyboard({required this.buttons});

  /// Create from JSON structure
  factory InlineKeyboard.fromJson(Map<String, dynamic> json) {
    final inlineData = json['inline'] as Map<String, dynamic>?;
    if (inlineData == null) {
      return const InlineKeyboard(buttons: []);
    }

    final buttonsData = inlineData['inline_buttons'] as List<dynamic>? ?? [];
    
    final buttons = buttonsData.map<List<InlineButton>>((row) {
      final rowData = row as List<dynamic>? ?? [];
      return rowData.map<InlineButton>((buttonData) {
        return InlineButton.fromJson(buttonData as Map<String, dynamic>);
      }).toList();
    }).toList();

    return InlineKeyboard(buttons: buttons);
  }

  /// Convert to JSON structure
  Map<String, dynamic> toJson() {
    return {
      'inline': {
        'inline_buttons': buttons.map((row) => 
          row.map((button) => button.toJson()).toList()
        ).toList(),
      },
    };
  }

  /// Check if keyboard has any buttons
  bool get hasButtons => buttons.isNotEmpty && buttons.any((row) => row.isNotEmpty);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InlineKeyboard &&
          runtimeType == other.runtimeType &&
          listEquals(buttons, other.buttons);

  @override
  int get hashCode => buttons.hashCode;

  @override
  String toString() {
    return 'InlineKeyboard{buttons: $buttons}';
  }
} 