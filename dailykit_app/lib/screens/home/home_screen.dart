import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../services/permission_service.dart';
import '../../services/tap_sequence_detector.dart';
import '../contacts/contacts_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import '../auth/login_screen.dart';
import '../consent/consent_dialog.dart';
import '../countdown/countdown_screen.dart';

/// ================= WHY POWER BUTTON OR CLOSED-APP ICON TAPS CANNOT BE USED =================
/// On modern Android (Android 8.0 Oreo through Android 14+):
/// 1. Power Button Press Interception:
///    Google strictly reserves the hardware power button for system-level actions
///    (e.g., Emergency SOS system integration, Power Menu, Google Assistant).
///    Third-party apps cannot register a global broadcast receiver for `Intent.ACTION_SCREEN_OFF`
///    or power button presses while the process is in background or terminated, to prevent battery drain
///    and malicious lockouts.
/// 2. Closed-App Icon Multi-Tap:
///    The Android Launcher (home screen launcher app) handles icon clicks. A regular app cannot
///    detect multiple taps on its launcher icon when closed; clicking the icon always launches the
///    default activity (`MainActivity`).
///
/// Hence, the standard, reliable architectures for personal safety on Android are:
///  A) In-App SOS Button with 600ms sequence detector (Single tap for contacts, Triple tap for SOS).
///  B) Interactive Home Screen AppWidget (using home_widget / native AppWidgetProvider).
///  C) Quick Settings Tile (pull-down notification shade shortcut).
/// ============================================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const MethodChannel _smsChannel = MethodChannel('com.dailykit.sos/sms');
  late final TapSequenceDetector _tapDetector;
  bool _isGpsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkGpsStatus();
    _tapDetector = TapSequenceDetector(
      sequenceTimeout: const Duration(milliseconds: 600),
      onSingleTap: _handleSingleTap,
      onTripleTap: _handleTripleTap,
    );

    _initWidgetAndTileListener();
  }

  @override
  void dispose() {
    _tapDetector.dispose();
    super.dispose();
  }

  void _initWidgetAndTileListener() {
    // Check initial launch action from Widget or Tile
    _smsChannel.invokeMethod<String>('getLaunchRouteAction').then((action) {
      if (action != null) {
        _handleRouteAction(action);
      }
    });

    // Listen for live resume intent actions
    _smsChannel.setMethodCallHandler((call) async {
      if (call.method == 'onRouteAction') {
        final action = call.arguments as String?;
        if (action != null) {
          _handleRouteAction(action);
        }
      }
    });
  }

  void _handleRouteAction(String action) {
    if (!mounted) return;
    if (action == 'TRIGGER_SOS') {
      _handleTripleTap();
    } else if (action == 'OPEN_CONTACTS') {
      _handleSingleTap();
    }
  }

  Future<void> _checkGpsStatus() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (mounted) {
      setState(() => _isGpsEnabled = enabled);
    }
  }

  void _handleSingleTap() {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ContactsScreen()),
    );
  }

  Future<void> _handleTripleTap() async {
    if (!mounted) return;

    // Check one-time user consent first
    final hasConsented = await PermissionService.instance.hasConsented();
    if (!hasConsented) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => ConsentDialog(
          onConsentGranted: () => _triggerSosFlow(),
        ),
      );
      return;
    }

    _triggerSosFlow();
  }

  Future<void> _triggerSosFlow() async {
    final contactsProvider = context.read<ContactsProvider>();
    final activeContacts = contactsProvider.activeContacts;

    if (activeContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add at least one active emergency contact first!'),
          action: SnackBarAction(
            label: 'Add Contact',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ContactsScreen()),
              );
            },
          ),
          backgroundColor: Colors.amber.shade900,
        ),
      );
      return;
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CountdownScreen(activeContacts: activeContacts),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contactsProvider = context.watch<ContactsProvider>();
    final authProvider = context.watch<AuthProvider>();
    final activeCount = contactsProvider.activeCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AU APP', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Alert History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'App Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: authProvider.isAuthenticated ? 'Account Profile' : 'Sign In',
            icon: Icon(
              authProvider.isAuthenticated ? Icons.account_circle : Icons.login,
              color: authProvider.isAuthenticated ? theme.colorScheme.primary : null,
            ),
            onPressed: () {
              if (authProvider.isAuthenticated) {
                _showProfileDialog(context, authProvider);
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Status Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: activeCount > 0
                    ? theme.colorScheme.primaryContainer.withAlpha(90)
                    : Colors.amber.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        activeCount > 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                        color: activeCount > 0 ? theme.colorScheme.primary : Colors.amber.shade900,
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeCount > 0
                                  ? '$activeCount contact${activeCount > 1 ? 's' : ''} ready'
                                  : 'No contacts configured',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: activeCount > 0 ? theme.colorScheme.primary : Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  _isGpsEnabled ? Icons.gps_fixed : Icons.gps_not_fixed,
                                  size: 14,
                                  color: _isGpsEnabled ? Colors.green : Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isGpsEnabled ? 'GPS Active' : 'GPS Offline / Coarse',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _isGpsEnabled ? Colors.green.shade800 : Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Very Large SOS Button with Sequence Detector (AU APP Blue & White Theme)
              Center(
                child: GestureDetector(
                  onTap: () => _tapDetector.registerTap(),
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E88E5), // Bright Blue
                          Color(0xFF0D47A1), // Royal Blue
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D47A1).withAlpha(140),
                          blurRadius: 36,
                          spreadRadius: 10,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shield_rounded, size: 48, color: Colors.white),
                          const SizedBox(height: 4),
                          const Text(
                            'AU SOS',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'TRIPLE TAP TO SEND',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Clear usage hint
              Text(
                'Tap once to manage contacts, tap 3 times to send location',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(),

              // Quick Actions Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ContactsScreen()),
                      );
                    },
                    icon: const Icon(Icons.people_alt_outlined),
                    label: const Text('Contacts'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HistoryScreen()),
                      );
                    },
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('History'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Settings'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileDialog(BuildContext context, AuthProvider auth) {
    final user = auth.currentUser;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${user?.name ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Email: ${user?.email ?? "N/A"}'),
            const SizedBox(height: 12),
            const Text(
              'Your contacts and alert history are automatically backed up to MySQL cloud when online.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await auth.logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
