import 'package:flutter/material.dart';

/// Simple utility for handling Persian text with mixed English words
class PersianTextDirection {
  /// Check if text contains Persian characters
  static bool containsPersian(String text) {
    // Persian character ranges
    final persianRanges = [
      [0x0600, 0x06FF], // Arabic (includes Persian)
      [0x0750, 0x077F], // Arabic Supplement
      [0x08A0, 0x08FF], // Arabic Extended-A
      [0xFB50, 0xFDFF], // Arabic Presentation Forms-A
      [0xFE70, 0xFEFF], // Arabic Presentation Forms-B
      [0x06F0, 0x06FF], // Persian digits
    ];
    
    for (final char in text.codeUnits) {
      for (final range in persianRanges) {
        if (char >= range[0] && char <= range[1]) {
          return true;
        }
      }
    }
    return false;
  }
  
  /// Get appropriate text direction for Persian text with mixed English
  static TextDirection getTextDirection(String text) {
    if (text.isEmpty) return TextDirection.ltr;
    
    // If text contains Persian characters, use RTL
    if (containsPersian(text)) {
      return TextDirection.rtl;
    }
    
    // Default to LTR for English and other languages
    return TextDirection.ltr;
  }

  /// Get direction by first non-space character (Telegram/WhatsApp style)
  static TextDirection getDirectionByFirstChar(String text) {
    final trimmed = text.trimLeft();
    if (trimmed.isEmpty) return TextDirection.rtl; // default RTL
    final firstChar = trimmed[0];
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(firstChar)) {
      return TextDirection.rtl;
    }
    return TextDirection.ltr;
  }
} 