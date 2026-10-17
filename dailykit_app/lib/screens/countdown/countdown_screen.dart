import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../../services/location_service.dart';
import '../../services/sms_service.dart';
import '../../services/database_helper.dart';
import '../../services/sync_service.dart';
import '../../models/contact_model.dart';
import '../../models/alert_model.dart';
import 'sos_result_dialog.dart';

class CountdownScreen extends StatefulWidget {
  final List<ContactModel> activeContacts;

  const CountdownScreen({super.key, required this.activeContacts});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> with SingleTickerProviderStateMixin {
  int _secondsLeft = 5;
  Timer? _countdownTimer;
  bool _isDispatching = false;
  String _dispatchStatus = 'Locating GPS...';

  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _startCountdown();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    // Vibrate once when countdown starts
    _vibrate();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
        _dispatchSos();
      }
    });
  }

  Future<void> _vibrate() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 400);
    }
  }

  void _cancelSos() {
    _countdownTimer?.cancel();
    Navigator.of(context).pop(false);
  }

  Future<void> _dispatchSos() async {
    setState(() {
      _isDispatching = true;
      _dispatchStatus = 'Acquiring high accuracy GPS coordinates...';
    });

    final now = DateTime.now();

    // 1. Acquire GPS location (live within 10s or fallback to last known)
    final locResult = await LocationService.instance.getSosLocation();

    setState(() {
      _dispatchStatus = 'Broadcasting emergency SMS to ${widget.activeContacts.length} contacts...';
    });

    // 2. Format alert message
    // "I need help. My location: https://maps.google.com/?q=<lat>,<lng> (sent <date time>)"
    // or with "last known location" label
    String formattedTime = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    String alertMessage;
    if (locResult.hasCoordinates) {
      if (locResult.locationSource == 'last_known') {
        alertMessage = "I need help. My last known location: ${locResult.googleMapsUrl} (sent $formattedTime)";
      } else {
        alertMessage = "I need help. My location: ${locResult.googleMapsUrl} (sent $formattedTime)";
      }
    } else {
      alertMessage = "I need help. My location: location unavailable (sent $formattedTime)";
    }

    // 3. Send SMS to all selected emergency contacts
    final phoneNumbers = widget.activeContacts.map((c) => c.phoneE164).toList();
    final List<SmsSendResult> smsResults = await SmsService.instance.broadcastSms(
      phones: phoneNumbers,
      message: alertMessage,
    );

    // Vibrate once when SMS is sent
    await _vibrate();

    final sentCount = smsResults.where((r) => r.isSuccess).length;
    final failedCount = smsResults.where((r) => !r.isSuccess).length;

    // 4. Save to local SQLite database
    final alertRecipients = smsResults.map((r) {
      final matchedContact = widget.activeContacts.cast<ContactModel?>().firstWhere(
            (c) => c?.phoneE164 == r.phone,
            orElse: () => null,
          );
      return AlertRecipientModel(
        contactId: matchedContact?.remoteId ?? matchedContact?.id,
        contactName: matchedContact?.name,
        phone: r.phone,
        status: r.isSuccess ? 'sent' : 'failed',
        error: r.error,
      );
    }).toList();

    final localAlert = AlertModel(
      latitude: locResult.latitude,
      longitude: locResult.longitude,
      accuracy: locResult.accuracy,
      locationSource: locResult.locationSource,
      message: alertMessage,
      triggeredAt: now,
      sentCount: sentCount,
      failedCount: failedCount,
      isSynced: false,
      recipients: alertRecipients,
    );

    await DatabaseHelper.instance.insertAlert(localAlert);

    // 5. Trigger background cloud sync if online
    SyncService.instance.syncAll();

    if (mounted) {
      // Pop countdown screen
      Navigator.of(context).pop(true);

      // Show summary dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => SosResultDialog(
          sentCount: sentCount,
          failedCount: failedCount,
          results: smsResults,
          alertMessage: alertMessage,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return PopScope(
      canPop: !_isDispatching,
      child: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top header
                Column(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.white),
                    const SizedBox(height: 8),
                    const Text(
                      'EMERGENCY SOS TRIGGERED',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isDispatching
                          ? _dispatchStatus
                          : 'Sending emergency alert to ${widget.activeContacts.length} contact${widget.activeContacts.length > 1 ? 's' : ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, color: Colors.white70),
                    ),
                  ],
                ),

                // Center animated countdown / spinner
                Center(
                  child: _isDispatching
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 90,
                              height: 90,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 8,
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              'Dispatching SOS...',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(90),
                                  blurRadius: 24,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '$_secondsLeft',
                                style: TextStyle(
                                  fontSize: 84,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),

                // Big accessible Cancel Button
                if (!_isDispatching)
                  ElevatedButton(
                    onPressed: _cancelSos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel_rounded, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'CANCEL ALERT',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

