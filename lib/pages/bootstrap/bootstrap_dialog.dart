import 'package:fluffychat/l10n/l10n.dart';
import 'package:flutter/material.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';

import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/utils/error_reporter.dart';
import 'package:fluffychat/utils/fluffy_share.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:fluffychat/widgets/future_loading_dialog.dart';
import '../../utils/adaptive_bottom_sheet.dart';
import '../key_verification/key_verification_dialog.dart';
import '../../services/matrix_auth_api.dart';

class BootstrapDialog extends StatefulWidget {
  final bool wipe;
  final Client client;

  const BootstrapDialog({
    super.key,
    this.wipe = false,
    required this.client,
  });

  Future<bool?> show(BuildContext context) => showAdaptiveBottomSheet(
        context: context,
        builder: (context) => this,
      );

  @override
  BootstrapDialogState createState() => BootstrapDialogState();
}

class BootstrapDialogState extends State<BootstrapDialog> {
  final TextEditingController _recoveryKeyTextEditingController =
      TextEditingController();

  late Bootstrap bootstrap;

  String? _recoveryKeyInputError;

  bool _recoveryKeyInputLoading = false;

  String? titleText;

  bool _recoveryKeyStored = false;
  bool _recoveryKeyCopied = false;

  bool? _storeInSecureStorage = false;
  bool? _storeInServer = true;
  bool _isStoringInServer = false;

  bool? _wipe;

  String get _secureStorageKey =>
      'ssss_recovery_key_${bootstrap.client.userID}';

  bool get _supportsSecureStorage =>
      PlatformInfos.isMobile || PlatformInfos.isDesktop;

  String _getSecureStorageLocalizedName() {
    if (PlatformInfos.isAndroid) {
      return L10n.of(context).storeInAndroidKeystore;
    }
    if (PlatformInfos.isIOS || PlatformInfos.isMacOS) {
      return L10n.of(context).storeInAppleKeyChain;
    }
    return L10n.of(context).storeSecurlyOnThisDevice;
  }

  bool _isLoadingSecurityPasswords = false;
  String? _securityPasswordsError;
  Map<String, dynamic>? _securityPasswords;

  String _keyType = 'security_key';

  bool _isAutoUnlocking = false;

  @override
  void initState() {
    super.initState();
    // Initialize bootstrap first
    _createBootstrap(widget.wipe).then((_) {
      // Only fetch passwords after bootstrap is initialized
      if (mounted) {
        _fetchSecurityPasswords();
      }
    });
  }

  Future<void> _createBootstrap(bool wipe) async {
    _wipe = wipe;
    titleText = null;
    _recoveryKeyStored = false;
    bootstrap = widget.client.encryption!.bootstrap(
      onUpdate: (state) {
        if (mounted) {
          setState(() {});
        }
      },
    );
    
    // Wait for bootstrap to be ready
    while (bootstrap.state == BootstrapState.loading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    final key = await const FlutterSecureStorage().read(key: _secureStorageKey);
    if (key == null) return;
    if (mounted) {
      _recoveryKeyTextEditingController.text = key;
    }
  }

  Future<void> _fetchSecurityPasswords() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingSecurityPasswords = true;
      _securityPasswordsError = null;
    });

    try {
      final passwords = await MatrixAuthApi.getSecurityPasswords(
        accessToken: widget.client.accessToken!,
      );
      
      if (!mounted) return;
      
      setState(() {
        _securityPasswords = passwords;
        _isLoadingSecurityPasswords = false;
      });

      final recoveryKey = passwords['second_password']?.toString().isNotEmpty == true 
          ? passwords['second_password'] 
          : (passwords['security_key']?.toString().isNotEmpty == true 
              ? passwords['security_key'] 
              : null);
              
      if (recoveryKey != null) {
        _recoveryKeyTextEditingController.text = recoveryKey;
        
        // Start auto-unlock process
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          
          setState(() {
            _isAutoUnlocking = true;
          });
          
          try {
            // Wait a bit for bootstrap to initialize
            await Future.delayed(const Duration(milliseconds: 1000));
            
            // Handle initial states
            if (bootstrap.state == BootstrapState.askWipeSsss) {
              bootstrap.wipeSsss(false);
            } else if (bootstrap.state == BootstrapState.askBadSsss) {
              bootstrap.ignoreBadSecrets(true);
            } else if (bootstrap.state == BootstrapState.askUseExistingSsss) {
              bootstrap.useExistingSsss(true);
            }
            
            // Wait for state to update and try to unlock
            int attempts = 0;
            while (attempts < 5 && mounted) {
              await Future.delayed(const Duration(milliseconds: 500));
              
              // Check if we're in a state where we can unlock
              if (bootstrap.state == BootstrapState.askUnlockSsss || 
                  bootstrap.state == BootstrapState.askNewSsss ||
                  bootstrap.state == BootstrapState.openExistingSsss) {
                Logs().d('Attempting auto-unlock in state: ${bootstrap.state}');
                await _unlockWithRecoveryKey();
                break;
              }
              
              // If we're in openExistingSsss, try to proceed
              if (bootstrap.state == BootstrapState.openExistingSsss) {
                try {
                  await bootstrap.openExistingSsss();
                  Logs().d('Successfully opened existing SSSS');
                } catch (e) {
                  Logs().e('Error opening existing SSSS', e);
                }
              }
              
              attempts++;
              Logs().d('Waiting for correct state, attempt $attempts, current state: ${bootstrap.state}');
            }
            
            if (attempts >= 5 && mounted) {
              Logs().w('Failed to reach correct state for auto-unlock after $attempts attempts');
            }
          } finally {
            if (mounted) {
              setState(() {
                _isAutoUnlocking = false;
              });
            }
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _securityPasswordsError = e.toLocalizedString(context);
        _isLoadingSecurityPasswords = false;
        _isAutoUnlocking = false;
      });
    }
  }

  Future<void> _unlockWithRecoveryKey() async {
    final key = _recoveryKeyTextEditingController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.of(context).pleaseEnterYourKey),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _recoveryKeyInputLoading = true;
    });

    try {
      // First try to unlock SSSS
      await bootstrap.newSsssKey!.unlock(
        keyOrPassphrase: key,
      );
      await bootstrap.openExistingSsss();
      Logs().d('SSSS unlocked');

      // Handle cross-signing separately
      if (bootstrap.encryption.crossSigning.enabled) {
        Logs().v('Cross signing is already enabled. Try to self-sign');
        try {
          await bootstrap.client.encryption!.crossSigning.selfSign(recoveryKey: key);
          Logs().d('Successfully self-signed');
        } catch (e, s) {
          // Log the error but don't fail the whole process
          Logs().e('Error during cross-signing, continuing with backup', e, s);
        }
      }

      // Handle server storage
      if (_storeInServer == true) {
        try {
          await MatrixAuthApi.setSecurityPasswords(
            accessToken: widget.client.accessToken!,
            securityKey: _keyType == 'security_key' ? key : null,
            secondPassword: _keyType == 'second_password' ? key : null,
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(L10n.of(context).storeInServerSuccess),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          // Don't show error for server storage, just log it
          debugPrint('Error storing key in server: $e');
        }
      } else {
        // If _storeInServer is false, remove any existing key from server
        try {
          await MatrixAuthApi.setSecurityPasswords(
            accessToken: widget.client.accessToken!,
            securityKey: '',
            secondPassword: '',
          );
          debugPrint('Successfully removed existing keys from server');
        } catch (e) {
          // We don't show an error here since this is just cleanup
          debugPrint('Error removing security key from server: $e');
        }
      }

      // Ensure we complete the bootstrap process
      if (bootstrap.state != BootstrapState.done) {
        try {
          await bootstrap.askSetupOnlineKeyBackup(true);
          Logs().d('Successfully set up online key backup');
        } catch (e, s) {
          Logs().e('Error setting up online key backup', e, s);
          // Continue anyway as the key is already stored
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, s) {
      if (!mounted) return;
      ErrorReporter(
        context,
        'Unable to open SSSS with recovery key',
      ).onErrorCallback(e, s);
      setState(
        () => _recoveryKeyInputError = e.toLocalizedString(context),
      );
    } finally {
      if (mounted) {
        setState(() {
          _recoveryKeyInputLoading = false;
        });
      }
    }
  }

  Future<void> _handleNextButton(String key) async {
    if (_storeInSecureStorage == true) {
      await const FlutterSecureStorage().write(
        key: _secureStorageKey,
        value: key,
      );
    }

    if (_storeInServer == true) {
      setState(() {
        _isStoringInServer = true;
      });

      try {
        await MatrixAuthApi.setSecurityPasswords(
          accessToken: widget.client.accessToken!,
          securityKey: key,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.of(context).storeInServerSuccess),
          ),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.of(context).storeInServerError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return; // Don't proceed if server storage fails
      } finally {
        if (mounted) {
          setState(() {
            _isStoringInServer = false;
          });
        }
      }
    } else {
      // If _storeInServer is false, send empty values to remove any existing keys
      try {
        await MatrixAuthApi.setSecurityPasswords(
          accessToken: widget.client.accessToken!,
          securityKey: '',
          secondPassword: '',
        );
      } catch (e) {
        // We don't show an error here since this is just cleanup
        debugPrint('Error removing security key from server: $e');
      }
    }

    setState(() => _recoveryKeyStored = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _wipe ??= widget.wipe;
    final buttons = <Widget>[];
    Widget body = const CircularProgressIndicator.adaptive();
    titleText = L10n.of(context).loadingPleaseWait;

    if (_isLoadingSecurityPasswords) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator.adaptive(),
          const SizedBox(height: 16),
          Text(L10n.of(context).loadingPleaseWait),
        ],
      );
    } else if (_securityPasswordsError != null) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(_securityPasswordsError!),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchSecurityPasswords,
            child: Text(L10n.of(context).tryAgain),
          ),
        ],
      );
    } else if (_securityPasswords != null) {
      if (bootstrap.newSsssKey?.recoveryKey != null &&
          _recoveryKeyStored == false) {
        final key = bootstrap.newSsssKey!.recoveryKey;
        titleText = L10n.of(context).recoveryKey;
        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: Navigator.of(context).pop,
            ),
            title: Text(L10n.of(context).recoveryKey),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: FluffyThemes.columnWidth * 1.5),
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    trailing: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      child: Icon(
                        Icons.info_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    subtitle: Text(L10n.of(context).chatBackupDescription),
                  ),
                  const Divider(
                    height: 32,
                    thickness: 1,
                  ),
                  TextField(
                    minLines: 2,
                    maxLines: 4,
                    readOnly: true,
                    style: const TextStyle(fontFamily: 'RobotoMono'),
                    controller: TextEditingController(text: key),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(16),
                      suffixIcon: Icon(Icons.key_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_supportsSecureStorage)
                    CheckboxListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                      value: _storeInSecureStorage,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (b) {
                        setState(() {
                          _storeInSecureStorage = b;
                        });
                      },
                      title: Text(_getSecureStorageLocalizedName()),
                      subtitle:
                          Text(L10n.of(context).storeInSecureStorageDescription),
                    ),
                  const SizedBox(height: 16),
                  CheckboxListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    value: _storeInServer,
                    activeColor: theme.colorScheme.primary,
                    onChanged: _isStoringInServer
                        ? null
                        : (b) {
                            setState(() {
                              _storeInServer = b;
                            });
                          },
                    title: Text(L10n.of(context).storeInServer),
                    subtitle: Text(L10n.of(context).storeInServerSuccessDescription),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    value: _recoveryKeyCopied,
                    activeColor: theme.colorScheme.primary,
                    onChanged: (b) {
                      FluffyShare.share(key!, context);
                      setState(() => _recoveryKeyCopied = true);
                    },
                    title: Text(L10n.of(context).copyToClipboard),
                    subtitle: Text(L10n.of(context).saveKeyManuallyDescription),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: _isStoringInServer 
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_outlined),
                    label: Text(L10n.of(context).next),
                    onPressed: (_recoveryKeyCopied || _storeInSecureStorage == true || _storeInServer == true) && !_isStoringInServer
                        ? () => _handleNextButton(key!)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        switch (bootstrap.state) {
          case BootstrapState.loading:
            break;
          case BootstrapState.askWipeSsss:
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => bootstrap.wipeSsss(_wipe!),
            );
            break;
          case BootstrapState.askBadSsss:
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => bootstrap.ignoreBadSecrets(true),
            );
            break;
          case BootstrapState.askUseExistingSsss:
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => bootstrap.useExistingSsss(!_wipe!),
            );
            break;
          case BootstrapState.askUnlockSsss:
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => bootstrap.unlockedSsss(),
            );
            break;
          case BootstrapState.askNewSsss:
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => bootstrap.newSsss(),
            );
            break;
          case BootstrapState.openExistingSsss:
            _recoveryKeyStored = true;
            return Scaffold(
              appBar: AppBar(
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: Navigator.of(context).pop,
                ),
                title: Text(L10n.of(context).chatBackup),
              ),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: FluffyThemes.columnWidth * 1.5,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8.0),
                        trailing: Icon(
                          Icons.info_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        subtitle: Text(
                          L10n.of(context).pleaseEnterRecoveryKeyDescription,
                        ),
                      ),
                      const Divider(height: 32),
                      Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L10n.of(context).recoveryKey,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                minLines: 1,
                                maxLines: 2,
                                autocorrect: false,
                                readOnly: _recoveryKeyInputLoading,
                                autofillHints: _recoveryKeyInputLoading
                                    ? null
                                    : [AutofillHints.password],
                                controller: _recoveryKeyTextEditingController,
                                style: const TextStyle(fontFamily: 'RobotoMono'),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.all(16),
                                  hintStyle: TextStyle(
                                    fontFamily: theme.textTheme.bodyLarge?.fontFamily,
                                  ),
                                  prefixIcon: const Icon(Icons.key_outlined),
                                  labelText: L10n.of(context).recoveryKey,
                                  hintText: 'Es** **** **** ****',
                                  errorText: _recoveryKeyInputError,
                                  errorMaxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L10n.of(context).storageOptions,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(L10n.of(context).storeInServer),
                                subtitle: Text(L10n.of(context).storeInServerDescription),
                                value: _storeInServer,
                                onChanged: (value) {
                                  setState(() {
                                    _storeInServer = value ?? false;
                                    // Reset key type when disabling server storage
                                    if (!value!) {
                                      _keyType = 'security_key';
                                    }
                                  });
                                },
                              ),
                              if (_storeInServer == true) ...[
                                const Divider(height: 32),
                                Text(
                                  L10n.of(context).keyType,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SegmentedButton<String>(
                                  style: ButtonStyle(
                                    backgroundColor: MaterialStateProperty.resolveWith<Color>(
                                      (Set<MaterialState> states) {
                                        if (states.contains(MaterialState.selected)) {
                                          return theme.colorScheme.primaryContainer;
                                        }
                                        return theme.colorScheme.surface;
                                      },
                                    ),
                                  ),
                                  segments: [
                                    ButtonSegment<String>(
                                      value: 'security_key',
                                      label: Text(L10n.of(context).securityKey),
                                      icon: const Icon(Icons.key),
                                    ),
                                    ButtonSegment<String>(
                                      value: 'second_password',
                                      label: Text(L10n.of(context).secondPassword),
                                      icon: const Icon(Icons.password),
                                    ),
                                  ],
                                  selected: {_keyType},
                                  onSelectionChanged: (Set<String> newSelection) {
                                    setState(() {
                                      _keyType = newSelection.first;
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onPrimary,
                          iconColor: theme.colorScheme.onPrimary,
                          backgroundColor: theme.colorScheme.primary,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        icon: (_recoveryKeyInputLoading || _isAutoUnlocking)
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                              )
                            : const Icon(Icons.lock_open_outlined),
                        label: Text(L10n.of(context).unlockOldMessages),
                        onPressed: (_recoveryKeyInputLoading || _isAutoUnlocking)
                            ? null
                            : _unlockWithRecoveryKey,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(L10n.of(context).or),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.cast_connected_outlined),
                        label: Text(L10n.of(context).transferFromAnotherDevice),
                        onPressed: _recoveryKeyInputLoading
                            ? null
                            : () async {
                                final consent = await showOkCancelAlertDialog(
                                  context: context,
                                  title: L10n.of(context).verifyOtherDevice,
                                  message: L10n.of(context)
                                      .verifyOtherDeviceDescription,
                                  okLabel: L10n.of(context).ok,
                                  cancelLabel: L10n.of(context).cancel,
                                );
                                if (consent != OkCancelResult.ok) return;
                                final req = await showFutureLoadingDialog(
                                  context: context,
                                  delay: false,
                                  future: () async {
                                    await widget.client.updateUserDeviceKeys();
                                    return widget.client
                                        .userDeviceKeys[widget.client.userID!]!
                                        .startVerification();
                                  },
                                );
                                if (req.error != null) return;
                                await KeyVerificationDialog(request: req.result!)
                                    .show(context);
                                Navigator.of(context, rootNavigator: false).pop();
                              },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.errorContainer,
                          foregroundColor: theme.colorScheme.onErrorContainer,
                          iconColor: theme.colorScheme.onErrorContainer,
                        ),
                        icon: const Icon(Icons.delete_outlined),
                        label: Text(L10n.of(context).recoveryKeyLost),
                        onPressed: _recoveryKeyInputLoading
                            ? null
                            : () async {
                                if (OkCancelResult.ok ==
                                    await showOkCancelAlertDialog(
                                      useRootNavigator: false,
                                      context: context,
                                      title: L10n.of(context).recoveryKeyLost,
                                      message: L10n.of(context).wipeChatBackup,
                                      okLabel: L10n.of(context).ok,
                                      cancelLabel: L10n.of(context).cancel,
                                      isDestructive: true,
                                    )) {
                                  setState(() => _createBootstrap(true));
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
            );
          case BootstrapState.askWipeCrossSigning:
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => bootstrap.wipeCrossSigning(_wipe!),
            );
            break;
          case BootstrapState.askSetupCrossSigning:
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => bootstrap.askSetupCrossSigning(
                setupMasterKey: true,
                setupSelfSigningKey: true,
                setupUserSigningKey: true,
              ),
            );
            break;
          case BootstrapState.askWipeOnlineKeyBackup:
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => bootstrap.wipeOnlineKeyBackup(_wipe!),
            );

            break;
          case BootstrapState.askSetupOnlineKeyBackup:
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => bootstrap.askSetupOnlineKeyBackup(true),
            );
            break;
          case BootstrapState.error:
            titleText = L10n.of(context).oopsSomethingWentWrong;
            body = const Icon(Icons.error_outline, color: Colors.red, size: 80);
            buttons.add(
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: false).pop<bool>(false),
                child: Text(L10n.of(context).close),
              ),
            );
            break;
          case BootstrapState.done:
            titleText = L10n.of(context).everythingReady;
            body = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 120,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                Text(
                  L10n.of(context).yourChatBackupHasBeenSetUp,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 16),
              ],
            );
            buttons.add(
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: false).pop<bool>(false),
                child: Text(L10n.of(context).close),
              ),
            );
            break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: Center(
          child: CloseButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: false).pop<bool>(true),
          ),
        ),
        title: Text(titleText ?? L10n.of(context).loadingPleaseWait),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              body,
              const SizedBox(height: 8),
              ...buttons,
            ],
          ),
        ),
      ),
    );
  }
}
