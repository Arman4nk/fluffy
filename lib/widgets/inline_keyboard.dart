import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/inline_button_models.dart' as models;
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_file_extension.dart';
import 'package:fluffychat/widgets/glass_button.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/persian_date_picker_dialog.dart';

class InlineKeyboardWidget extends StatelessWidget {
  final models.InlineKeyboard keyboardData;
  final Event event;
  final Timeline timeline;

  const InlineKeyboardWidget({
    super.key,
    required this.keyboardData,
    required this.event,
    required this.timeline,
  });

  @override
  Widget build(BuildContext context) {
    if (!keyboardData.hasButtons) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: keyboardData.buttons.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              children: [
                for (int i = 0; i < row.length; i++) ...[
                  Expanded(
                    child: _buildButton(context, row[i]),
                  ),
                  if (i < row.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildButton(BuildContext context, models.InlineButton button) {
    IconData? icon;
    
    switch (button.type) {
      case models.InlineButtonType.link:
        icon = Icons.link;
        break;
      case models.InlineButtonType.media:
        icon = Icons.attach_file;
        break;
      case models.InlineButtonType.date:
      case models.InlineButtonType.time:
      case models.InlineButtonType.datetime:
        icon = Icons.calendar_today;
        break;
      case models.InlineButtonType.map:
        icon = Icons.location_on;
        break;
      case models.InlineButtonType.text:
      default:
        icon = null;
        break;
    }

    return GlassButton(
      label: button.text,
      icon: icon,
      onPressed: () => _handleButtonPress(context, button),
    );
  }

  Future<void> _handleButtonPress(BuildContext context, models.InlineButton button) async {
    final matrixState = Matrix.of(context);
    final client = matrixState.client;
    final room = client.getRoomById(event.roomId!);
    
    if (room == null) return;

    switch (button.type) {
      case models.InlineButtonType.text:
        await _handleTextButton(room, button);
        break;
      case models.InlineButtonType.link:
        await _handleLinkButton(button);
        break;
      case models.InlineButtonType.media:
        await _handleMediaButton(context, room, button);
        break;
      case models.InlineButtonType.date:
      case models.InlineButtonType.time:
      case models.InlineButtonType.datetime:
        await _handleDateTimeButton(context, room, button);
        break;
      case models.InlineButtonType.map:
        await _handleMapButton(context, room, button);
        break;
    }
  }

  Future<void> _handleTextButton(Room room, models.InlineButton button) async {
    if (button.callbackData != null) {
      await room.sendTextEvent(button.callbackData!);
    }
  }

  Future<void> _handleLinkButton(models.InlineButton button) async {
    if (button.url != null) {
      await launchUrlString(
        button.url!,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Future<void> _handleMediaButton(BuildContext context, Room room, models.InlineButton button) async {
    final l10n = L10n.of(context);
    
    try {
      FileType fileType = FileType.any;
      List<String>? allowedExtensions;
      
      // Handle specific media types
      if (button.mediaType != null) {
        switch (button.mediaType!.toLowerCase()) {
          case 'image':
            fileType = FileType.image;
            break;
          case 'video':
            fileType = FileType.video;
            break;
          case 'audio':
            fileType = FileType.audio;
            break;
          default:
            // Parse specific extensions like "image/jpeg,image/png"
            if (button.mediaType!.contains('/')) {
              final extensions = button.mediaType!
                  .split(',')
                  .map((e) => e.trim().split('/').last)
                  .where((e) => e.isNotEmpty)
                  .toList();
              if (extensions.isNotEmpty) {
                fileType = FileType.custom;
                allowedExtensions = extensions;
              }
            }
        }
      }

      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            final matrixFile = MatrixFile(
              bytes: await File(file.path!).readAsBytes(),
              name: file.name,
            );
            await room.sendFileEvent(matrixFile);
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorOccurred)),
      );
    }
  }

  Future<void> _handleDateTimeButton(BuildContext context, Room room, models.InlineButton button) async {
    DateTimePickerMode mode;
    
    switch (button.type) {
      case models.InlineButtonType.date:
        mode = DateTimePickerMode.date;
        break;
      case models.InlineButtonType.time:
        mode = DateTimePickerMode.time;
        break;
      case models.InlineButtonType.datetime:
        mode = DateTimePickerMode.datetime;
        break;
      default:
        mode = DateTimePickerMode.date;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => PersianDatePickerDialog(
        mode: mode,
        onFinished: (value) => Navigator.of(context).pop(value),
      ),
    );

    if (result != null && result.isNotEmpty) {
      await room.sendTextEvent(result);
    }
  }

  Future<void> _handleMapButton(BuildContext context, Room room, models.InlineButton button) async {
    final l10n = L10n.of(context);
    
    try {
      // Check permission first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.locationPermissionDenied)),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.locationPermissionDeniedForever)),
        );
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition();
      
      // Send location message
      final geoUri = 'geo:${position.latitude},${position.longitude}';
      await room.sendEvent({
        'msgtype': 'm.location',
        'body': 'Location',
        'geo_uri': geoUri,
        'info': {
          'lat': position.latitude,
          'lon': position.longitude,
        },
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorOccurred)),
      );
    }
  }
}

// Extension to add missing localization keys
extension InlineKeyboardL10nExtensions on L10n {
  String get errorOccurred => 'An error occurred';
  String get locationPermissionDenied => 'Location permission denied';
  String get locationPermissionDeniedForever => 'Location permission permanently denied';
} 