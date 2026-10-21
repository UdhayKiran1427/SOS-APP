import 'package:flutter/material.dart';
import '../../services/database_helper.dart';
import '../../services/sms_service.dart';
import '../../services/permission_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  bool _countdownEnabled = true;
  final TextEditingController _countryCodeController = TextEditingController(text: '+91');
  final TextEditingController _messageTemplateController = TextEditingController(
    text: 'I need help. My location: {location} (sent {datetime})',
  );
  final TextEditingController _testPhoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSendingTest = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _countryCodeController.dispose();
    _messageTemplateController.dispose();
    _testPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final countdown = await _db.getSetting('countdown_enabled');
    final countryCode = await _db.getSetting('default_country_code');
    final template = await _db.getSetting('message_template');

    if (mounted) {
      setState(() {
        _countdownEnabled = countdown != 'false';
        if (countryCode != null) _countryCodeController.text = countryCode;
        if (template != null) _messageTemplateController.text = template;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    await _db.setSetting('countdown_enabled', _countdownEnabled ? 'true' : 'false');
    await _db.setSetting('default_country_code', _countryCodeController.text.trim());
    await _db.setSetting('message_template', _messageTemplateController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully!')),
      );
    }
  }

  Future<void> _sendTestSms() async {
    final phone = _testPhoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number to test.')),
      );
      return;
    }

    setState(() => _isSendingTest = true);

    try {
      final success = await SmsService.instance.sendDirectSms(
        phone: phone,
        message: 'DailyKit SOS Test: System is operating normally. (sent ${DateTime.now().toIso8601String()})',
      );

      if (mounted) {
        setState(() => _isSendingTest = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Direct test SMS sent successfully to $phone!'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingTest = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Direct SMS error: $e. Opening SMS app fallback...'),
            backgroundColor: Colors.orange.shade800,
          ),
        );

        // Fallback test
        await SmsService.instance.launchSmsFallback(
          phone: phone,
          message: 'DailyKit SOS Test: System check (Fallback mode)',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded),
            tooltip: 'Save Settings',
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Safety Section
          _buildSectionHeader('SAFETY & TIMING'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('5-Second Cancellation Countdown', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Gives you 5 seconds to cancel accidental SOS triggers with vibration alerts.'),
                  value: _countdownEnabled,
                  onChanged: (val) {
                    setState(() => _countdownEnabled = val);
                    _saveSettings();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Customization Section
          _buildSectionHeader('SMS & TEMPLATE CONFIGURATION'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _countryCodeController,
                    decoration: InputDecoration(
                      labelText: 'Default Country Code',
                      hintText: '+91',
                      prefixIcon: const Icon(Icons.flag_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _messageTemplateController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'SOS Alert Template',
                      hintText: 'I need help. My location: {location} (sent {datetime})',
                      helperText: 'Tokens: {location} (Google Maps URL), {datetime}',
                      prefixIcon: const Icon(Icons.message_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Local Storage Section
          _buildSectionHeader('STORAGE & PRIVACY'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.sd_storage_rounded, color: Colors.green, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '100% Offline Local Storage',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'All data (profile, contacts, SOS history) is stored privately inside this phone. No external server used.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Self Test Section
          _buildSectionHeader('SELF TEST SMS HARNESS'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Safely verify your phone carrier and SMS permissions by sending a self-test message without triggering an alert.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _testPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'My Phone Number',
                      hintText: '+919876543210',
                      prefixIcon: const Icon(Icons.phone_android_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isSendingTest ? null : _sendTestSms,
                    icon: _isSendingTest
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded),
                    label: const Text('Send Test SMS to Myself'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Permissions Section
          _buildSectionHeader('PERMISSIONS & CONSENT'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.security_update_good_rounded, color: Colors.green),
              title: const Text('Manage System Permissions'),
              subtitle: const Text('SMS, Fine Location, Contacts, Notifications'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => PermissionService.instance.openSystemSettings(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: Colors.grey,
        ),
      ),
    );
  }
}

