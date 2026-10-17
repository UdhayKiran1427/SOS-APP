import 'package:flutter/material.dart';
import '../../services/permission_service.dart';

class ConsentDialog extends StatefulWidget {
  final VoidCallback onConsentGranted;

  const ConsentDialog({super.key, required this.onConsentGranted});

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  bool _isRequesting = false;

  Future<void> _handleConsent() async {
    setState(() => _isRequesting = true);

    await PermissionService.instance.saveConsent(true);
    final report = await PermissionService.instance.requestRequiredPermissions();

    setState(() => _isRequesting = false);

    if (mounted) {
      Navigator.of(context).pop();
      widget.onConsentGranted();

      if (!report.isReadyForSos) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('SMS and Location permissions are required to dispatch SOS alerts automatically.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => PermissionService.instance.openSystemSettings(),
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield_rounded, size: 48, color: Colors.red.shade700),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Emergency SOS Permissions',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'To protect your safety during an emergency, DailyKit SOS requires access to:',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            _buildPermissionItem(
              icon: Icons.sms_outlined,
              title: 'SMS Permission',
              subtitle: 'Sends direct emergency alerts with your coordinates to your chosen contacts when you triple-tap SOS.',
            ),
            const SizedBox(height: 12),
            _buildPermissionItem(
              icon: Icons.location_on_outlined,
              title: 'Precise GPS Location',
              subtitle: 'Captures your live location coordinates so emergency contacts can find you immediately on Google Maps.',
            ),
            const SizedBox(height: 12),
            _buildPermissionItem(
              icon: Icons.contacts_outlined,
              title: 'Contacts Access',
              subtitle: 'Allows you to easily pick trusted emergency contacts from your phone address book.',
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isRequesting ? null : _handleConsent,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isRequesting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'I Understand & Allow Permissions',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not Now', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.red.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
    );
  }
}

