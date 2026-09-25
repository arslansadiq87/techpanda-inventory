import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../services/remote_sync_service.dart';

/// Settings page for configuring dark mode, component visibility, backups, and remote server connectivity.
class SettingsPage extends StatefulWidget {
  final ApiClient api;
  final RemoteSyncService syncService;
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final bool displayComponentImages;
  final ValueChanged<bool> onDisplayComponentImagesChanged;
  final bool enableAddComponent;
  final ValueChanged<bool> onEnableAddComponentChanged;
  final bool enableEditComponent;
  final ValueChanged<bool> onEnableEditComponentChanged;
  final bool showComponentSupplier;
  final ValueChanged<bool> onShowComponentSupplierChanged;
  final bool showComponentPrice;
  final ValueChanged<bool> onShowComponentPriceChanged;
  final bool showComponentExpiryDate;
  final ValueChanged<bool> onShowComponentExpiryDateChanged;
  final bool showComponentDatasheetFile;
  final ValueChanged<bool> onShowComponentDatasheetFileChanged;
  final bool showComponentDatasheetText;
  final ValueChanged<bool> onShowComponentDatasheetTextChanged;
  final ValueChanged<int> onNavigateToTab;
  final VoidCallback onRefreshData;
  final ValueChanged<String?> onError;
  final TextEditingController usernameController;
  final TextEditingController passwordController;

  const SettingsPage({
    super.key,
    required this.api,
    required this.syncService,
    required this.darkMode,
    required this.onDarkModeChanged,
    required this.displayComponentImages,
    required this.onDisplayComponentImagesChanged,
    required this.enableAddComponent,
    required this.onEnableAddComponentChanged,
    required this.enableEditComponent,
    required this.onEnableEditComponentChanged,
    required this.showComponentSupplier,
    required this.onShowComponentSupplierChanged,
    required this.showComponentPrice,
    required this.onShowComponentPriceChanged,
    required this.showComponentExpiryDate,
    required this.onShowComponentExpiryDateChanged,
    required this.showComponentDatasheetFile,
    required this.onShowComponentDatasheetFileChanged,
    required this.showComponentDatasheetText,
    required this.onShowComponentDatasheetTextChanged,
    required this.onNavigateToTab,
    required this.onRefreshData,
    required this.onError,
    required this.usernameController,
    required this.passwordController,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _remoteServerUrlController = TextEditingController();
  bool _remoteServerEnabled = false;
  String _remoteServerUrl = '';
  bool _syncingToRemote = false;
  double? _syncProgress;
  bool _testingConnection = false;
  String? _connectionTestMessage;
  bool _connectionTestPassed = false;
  String _lastTestedUrl = '';
  bool _exportingBackup = false;
  bool _restoringBackup = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _remoteServerUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('remote_server_enabled') ?? false;
    final url = prefs.getString('remote_server_url') ?? '';
    if (mounted) {
      setState(() {
        _remoteServerEnabled = enabled;
        _remoteServerUrl = url;
        _remoteServerUrlController.text = url;
        if (enabled && url.isNotEmpty) {
          _connectionTestPassed = true;
          _lastTestedUrl = url;
        }
      });
    }
  }

  Future<void> _downloadBackup() async {
    setState(() => _exportingBackup = true);
    widget.onError(null);
    try {
      final backup = await widget.api.downloadBackup();
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save inventory backup',
        fileName: backup.filename,
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        bytes: backup.bytes,
      );
      if (!mounted) return;
      if (kIsWeb || savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${backup.filename} has been downloaded.')),
        );
      }
    } catch (error) {
      if (mounted) widget.onError(error.toString());
    } finally {
      if (mounted) setState(() => _exportingBackup = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'This will replace the local inventory database and images with the selected backup. A safety copy of the current local data will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.restore),
            label: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    setState(() => _restoringBackup = true);
    widget.onError(null);
    try {
      await widget.api.restoreBackup(file.name, bytes);
      widget.onRefreshData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Backup restored.')));
    } catch (error) {
      if (mounted) widget.onError(error.toString());
    } finally {
      if (mounted) setState(() => _restoringBackup = false);
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    var showCurrent = false;
    var showNext = false;
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Change password'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: current,
                    obscureText: !showCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setDialogState(() => showCurrent = !showCurrent),
                        icon: Icon(
                          showCurrent ? Icons.visibility_off : Icons.visibility,
                        ),
                        tooltip: showCurrent
                            ? 'Hide password'
                            : 'Show password',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: next,
                    obscureText: !showNext,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setDialogState(() => showNext = !showNext),
                        icon: Icon(
                          showNext ? Icons.visibility_off : Icons.visibility,
                        ),
                        tooltip: showNext ? 'Hide password' : 'Show password',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirm,
                    obscureText: !showNext,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.key),
                label: const Text('Change'),
              ),
            ],
          ),
        ),
      );
      if (saved != true) return;
      if (next.text.isEmpty) {
        widget.onError('New password cannot be empty.');
        return;
      }
      if (next.text != confirm.text) {
        widget.onError('New passwords do not match.');
        return;
      }
      await widget.api.changePassword(current.text, next.text);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_password', next.text);
      if (!mounted) return;
      widget.passwordController.text = next.text;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password changed.')));
    } catch (error) {
      if (mounted) widget.onError(error.toString());
    } finally {
      current.dispose();
      next.dispose();
      confirm.dispose();
    }
  }

  Future<void> _testRemoteConnection() async {
    final url = _remoteServerUrlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _connectionTestPassed = false;
        _connectionTestMessage = 'Please enter a server URL first.';
      });
      return;
    }
    setState(() {
      _testingConnection = true;
      _connectionTestMessage = null;
    });
    try {
      final res = await widget.syncService.testConnection(url);
      final version = res['version'] != null ? ' (v${res['version']})' : '';
      if (mounted) {
        setState(() {
          _testingConnection = false;
          _connectionTestPassed = true;
          _lastTestedUrl = url;
          _connectionTestMessage = 'Server online & ready$version';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testingConnection = false;
          _connectionTestPassed = false;
          _connectionTestMessage =
              'Connection failed: ${e.toString().replaceAll('Exception:', '').trim()}';
        });
      }
    }
  }

  Future<void> _toggleRemoteServer(bool enable) async {
    final url = _remoteServerUrlController.text.trim();
    if (enable) {
      if (url.isEmpty) {
        widget.onError('Please enter a Remote Server URL first.');
        return;
      }
      if (!_connectionTestPassed || url != _lastTestedUrl) {
        widget.onError(
          'Please test the connection successfully before enabling remote server.',
        );
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final alreadySynced = prefs.getBool('remote_initial_sync_done') ?? false;

    await widget.syncService.configureRemote(enabled: enable, url: url);

    setState(() {
      _remoteServerEnabled = enable;
      _remoteServerUrl = url;
    });

    if (enable) {
      final client = widget.api as dynamic;
      if (client.remoteClient?.accessToken == null &&
          widget.usernameController.text.trim().isNotEmpty &&
          widget.passwordController.text.trim().isNotEmpty) {
        try {
          final username = widget.usernameController.text.trim().split('@').first;
          await widget.api.login(username, widget.passwordController.text);
        } catch (_) {}
      }
      if (!alreadySynced) {
        setState(() => _syncingToRemote = true);
        await widget.syncService.syncToRemote(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _syncProgress = progress;
                _syncingToRemote = progress != null;
              });
            }
          },
          onError: (err) {
            if (mounted && err != null) widget.onError(err);
          },
        );
        await prefs.setBool('remote_initial_sync_done', true);
      }
    } else {
      await prefs.setBool('remote_initial_sync_done', false);
    }

    if (mounted) {
      widget.onRefreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SwitchListTile(
          secondary: Icon(widget.darkMode ? Icons.dark_mode : Icons.light_mode),
          title: const Text('Dark mode'),
          subtitle: const Text('Use a dark color theme throughout the app'),
          value: widget.darkMode,
          onChanged: widget.onDarkModeChanged,
        ),
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.image),
          title: const Text('Display component images'),
          subtitle: const Text('Show saved thumbnails in the components list'),
          value: widget.displayComponentImages,
          onChanged: widget.onDisplayComponentImagesChanged,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.add_box),
          title: const Text('Enable add component'),
          subtitle: const Text('Show the add component form in Components'),
          value: widget.enableAddComponent,
          onChanged: widget.onEnableAddComponentChanged,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.edit),
          title: const Text('Enable edit component'),
          subtitle: const Text('Show component edit and delete actions'),
          value: widget.enableEditComponent,
          onChanged: widget.onEnableEditComponentChanged,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.local_shipping_outlined),
          title: const Text('Show supplier in components'),
          subtitle:
              const Text('Show supplier field in component forms and details'),
          value: widget.showComponentSupplier,
          onChanged: widget.onShowComponentSupplierChanged,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.attach_money),
          title: const Text('Show price in components'),
          subtitle: const Text(
            'Show price field in component forms, lists, and details',
          ),
          value: widget.showComponentPrice,
          onChanged: widget.onShowComponentPriceChanged,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.calendar_today_outlined),
          title: const Text('Show expiry date in components'),
          subtitle:
              const Text('Show expiry date picker and badges in components'),
          value: widget.showComponentExpiryDate,
          onChanged: widget.onShowComponentExpiryDateChanged,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.upload_file),
          title: const Text('Show choose datasheet'),
          subtitle:
              const Text('Show datasheet file attachment picker in component forms'),
          value: widget.showComponentDatasheetFile,
          onChanged: widget.onShowComponentDatasheetFileChanged,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notes),
          title: const Text('Show datasheet copy-paste / specs'),
          subtitle:
              const Text('Show technical specifications and datasheet text field'),
          value: widget.showComponentDatasheetText,
          onChanged: widget.onShowComponentDatasheetTextChanged,
        ),
        ListTile(
          leading: const Icon(Icons.key),
          title: const Text('Change password'),
          subtitle: const Text('Update the local admin password'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _changePassword,
        ),
        ListTile(
          leading: const Icon(Icons.summarize_outlined),
          title: const Text('Inventory exports'),
          subtitle: const Text(
            'Open Reports to download CSV or PDF with component images',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => widget.onNavigateToTab(4),
        ),
        const ListTile(
          leading: Icon(Icons.backup),
          title: Text('Backups'),
          subtitle: Text(
            'Download or restore a complete backup with database and images.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _exportingBackup || _restoringBackup
                    ? null
                    : _downloadBackup,
                icon: _exportingBackup
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: const Text('Download backup'),
              ),
              FilledButton.tonalIcon(
                onPressed: _exportingBackup || _restoringBackup
                    ? null
                    : _restoreBackup,
                icon: _restoringBackup
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restore),
                label: const Text('Restore backup'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Server Connection ──────────────────────────────────
        ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Server Connection'),
          subtitle: const Text(
            'Connect to a remote FastAPI server. On first enable, local data is synced to the server.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _remoteServerUrlController,
                enabled: !_remoteServerEnabled && !_syncingToRemote,
                decoration: const InputDecoration(
                  labelText: 'Remote Server URL',
                  hintText: 'https://inventory.example.com/api/v1',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.url,
                onChanged: (v) {
                  setState(() {
                    _remoteServerUrl = v.trim();
                    if (_lastTestedUrl != v.trim()) {
                      _connectionTestPassed = false;
                      _connectionTestMessage = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: (_testingConnection ||
                            _syncingToRemote ||
                            _remoteServerUrlController.text.trim().isEmpty)
                        ? null
                        : _testRemoteConnection,
                    icon: _testingConnection
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check, size: 18),
                    label: Text(_testingConnection
                        ? 'Testing Connection…'
                        : 'Test Connection'),
                  ),
                  if (_connectionTestMessage != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _connectionTestPassed
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: _connectionTestPassed
                              ? Colors.green
                              : Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _connectionTestMessage!,
                          style: TextStyle(
                            color: _connectionTestPassed
                                ? Colors.green
                                : Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_syncingToRemote && _syncProgress != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Syncing local data to server… ${(_syncProgress! * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: _syncProgress),
              ],
            ),
          ),
        SwitchListTile(
          secondary: _syncingToRemote
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          title: const Text('Remote Server'),
          subtitle: Text(
            _remoteServerEnabled
                ? 'All requests are routed to: $_remoteServerUrl'
                : (_connectionTestPassed &&
                        _remoteServerUrlController.text.trim() ==
                            _lastTestedUrl &&
                        _remoteServerUrlController.text.trim().isNotEmpty)
                    ? 'Connection verified. Turn on to switch to remote server.'
                    : 'Test connection successfully before enabling remote server',
          ),
          value: _remoteServerEnabled,
          onChanged: _syncingToRemote
              ? null
              : (_remoteServerEnabled ||
                      (_connectionTestPassed &&
                          _remoteServerUrlController.text.trim() ==
                              _lastTestedUrl &&
                          _remoteServerUrlController.text.trim().isNotEmpty))
                  ? _toggleRemoteServer
                  : null,
        ),
      ],
    );
  }
}
