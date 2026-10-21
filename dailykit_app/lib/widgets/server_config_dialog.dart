import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const ServerConfigDialog(),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late final TextEditingController _controller;
  bool _isTesting = false;
  String? _testResult;
  bool? _isSuccess;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ApiService.instance.baseUrl);
    _testCurrentUrl();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testCurrentUrl([String? urlToTest]) async {
    final target = urlToTest ?? _controller.text.trim();
    if (target.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
      _isSuccess = null;
    });

    final ok = await ApiService.instance.checkHealth(target);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _isSuccess = ok;
        _testResult = ok
            ? 'Connected! Backend is online.'
            : 'Cannot reach server. Check URL or deploy status.';
      });
    }
  }

  void _selectPreset(String url) {
    _controller.text = url;
    _testCurrentUrl(url);
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    if (url.isNotEmpty) {
      await ApiService.instance.saveServerUrl(url);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server URL set to: $url'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.dns_rounded, color: Colors.blueAccent),
          const SizedBox(width: 8),
          const Text('Server Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select backend server or enter your Render URL:',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 12),

            // Quick Presets
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.usb, size: 16),
                  label: const Text('Local USB (127.0.0.1)'),
                  onPressed: () => _selectPreset('http://127.0.0.1:3000'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.cloud_outlined, size: 16),
                  label: const Text('Render Cloud'),
                  onPressed: () => _selectPreset('https://sos-app-3188.onrender.com'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'API Base URL',
                hintText: 'https://your-service.onrender.com',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Test Connection',
                  onPressed: () => _testCurrentUrl(),
                ),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),

            // Health Status indicator
            if (_isTesting)
              const Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Testing connection...', style: TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              )
            else if (_testResult != null)
              Row(
                children: [
                  Icon(
                    _isSuccess == true ? Icons.check_circle : Icons.error,
                    size: 16,
                    color: _isSuccess == true ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _isSuccess == true ? Colors.green : Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save & Apply'),
        ),
      ],
    );
  }
}

