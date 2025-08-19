import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc_impl;
import 'package:matrix/matrix.dart';
import 'package:webrtc_interface/webrtc_interface.dart' hide Navigator;

import 'package:fluffychat/pages/chat_list/chat_list.dart';
import 'package:fluffychat/pages/dialer/dialer.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import '../../utils/voip/user_media_manager.dart';
import '../widgets/matrix.dart';

class VoipPlugin with WidgetsBindingObserver implements WebRTCDelegate {
  final MatrixState matrix;
  Client get client => matrix.client;
  VoipPlugin(this.matrix) {
    voip = VoIP(client, this);
    if (!kIsWeb) {
      final wb = WidgetsBinding.instance;
      wb.addObserver(this);
      didChangeAppLifecycleState(wb.lifecycleState);
    }
  }
  bool background = false;
  bool speakerOn = false;
  late VoIP voip;
  OverlayEntry? overlayEntry;
  BuildContext get context => matrix.context;

  @override
  void didChangeAppLifecycleState(AppLifecycleState? state) {
    background = (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused);
  }

  void addCallingOverlay(String callId, CallSession call) {
    BuildContext? overlayContext;
    
    // Always try ChatList.contextForVoip first (it has proper overlay access)
    if (ChatList.contextForVoip != null) {
      overlayContext = ChatList.contextForVoip;
    } else if (kIsWeb) {
      overlayContext = ChatList.contextForVoip;
    } else {
      overlayContext = this.context;
    }
    
    // Fallback if context is not available
    if (overlayContext == null) {
      Logs().e('[VOIP] No context available for overlay');
      return;
    }

    // Check if the context has an Overlay
    try {
      Overlay.of(overlayContext);
    } catch (e) {
      Logs().e('[VOIP] Context does not have Overlay: $e');
      return;
    }

    if (overlayEntry != null) {
      try {
        overlayEntry!.remove();
      } catch (e) {
        // Ignore error when removing overlay
      }
      overlayEntry = null;
    }
    
    Logs().i('[VOIP] Adding calling overlay for call: $callId');
    
    // Overlay.of(context) is broken on web
    // falling back on a dialog
    if (kIsWeb) {
      showDialog(
        context: overlayContext,
        builder: (context) => Calling(
          context: context,
          client: client,
          callId: callId,
          call: call,
          onClear: () => Navigator.of(context).pop(),
        ),
      );
    } else {
      try {
        overlayEntry = OverlayEntry(
          builder: (_) => Calling(
            context: overlayContext!,
            client: client,
            callId: callId,
            call: call,
            onClear: () {
              if (overlayEntry != null) {
                try {
                  overlayEntry!.remove();
                } catch (e) {
                  // Ignore error when removing overlay
                }
                overlayEntry = null;
              }
            },
          ),
        );
        Overlay.of(overlayContext).insert(overlayEntry!);
      } catch (e) {
        Logs().e('[VOIP] Error creating overlay: $e');
        overlayEntry = null;
      }
    }
  }

  @override
  MediaDevices get mediaDevices => webrtc_impl.navigator.mediaDevices;

  @override
  bool get isWeb => kIsWeb;

  @override
  Future<RTCPeerConnection> createPeerConnection(
    Map<String, dynamic> configuration, [
    Map<String, dynamic> constraints = const {},
  ]) =>
      webrtc_impl.createPeerConnection(configuration, constraints);

  Future<bool> get hasCallingAccount async => false;

  @override
  Future<void> playRingtone() async {
    if (!background && !await hasCallingAccount) {
      try {
        await UserMediaManager().startRingingTone();
      } catch (_) {}
    }
  }

  @override
  Future<void> stopRingtone() async {
    if (!background && !await hasCallingAccount) {
      try {
        await UserMediaManager().stopRingingTone();
      } catch (_) {}
    }
  }

  @override
  Future<void> handleNewCall(CallSession call) async {
    if (PlatformInfos.isAndroid) {
      try {
        final wasForeground = await FlutterForegroundTask.isAppOnForeground;

        await matrix.store.setString(
          'wasForeground',
          wasForeground == true ? 'true' : 'false',
        );
        FlutterForegroundTask.setOnLockScreenVisibility(true);
        FlutterForegroundTask.wakeUpScreen();
        FlutterForegroundTask.launchApp();
      } catch (e) {
        Logs().e('VOIP foreground failed $e');
      }
      // use fallback flutter call pages for outgoing and video calls.
      addCallingOverlay(call.callId, call);
    } else {
      addCallingOverlay(call.callId, call);
    }
  }

  @override
  Future<void> handleCallEnded(CallSession session) async {
    if (overlayEntry != null) {
      try {
        overlayEntry!.remove();
      } catch (e) {
        Logs().e('[VOIP] Error removing overlay: $e');
      }
      overlayEntry = null;
      
      if (PlatformInfos.isAndroid) {
        try {
          FlutterForegroundTask.setOnLockScreenVisibility(false);
          FlutterForegroundTask.stopService();
          final wasForeground = matrix.store.getString('wasForeground');
          if (wasForeground == 'false') {
            FlutterForegroundTask.minimizeApp();
          }
        } catch (e) {
          // Ignore foreground task errors
        }
      }
    }
  }

  @override
  Future<void> handleGroupCallEnded(GroupCallSession groupCall) async {
    // TODO: implement handleGroupCallEnded
  }

  @override
  Future<void> handleNewGroupCall(GroupCallSession groupCall) async {
    // TODO: implement handleNewGroupCall
  }

  @override
  // TODO: implement canHandleNewCall
  bool get canHandleNewCall =>
      voip.currentCID == null && voip.currentGroupCID == null;

  @override
  Future<void> handleMissedCall(CallSession session) async {
    // TODO: implement handleMissedCall
  }

  @override
  // TODO: implement keyProvider
  EncryptionKeyProvider? get keyProvider => null;

  @override
  Future<void> registerListeners(CallSession session) async {
    // Basic implementation - can be enhanced later
    session.onCallStateChanged.stream.listen((state) {
      Logs().i('Call state changed: $state');
    });
  }
}
