import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result for each individual SMS recipient attempt.
class SmsSendResult {
  final String phone;
  final bool isSuccess;
  final String? error;
  final bool usedFallback;

  SmsSendResult({
    required this.phone,
    required this.isSuccess,
    this.error,
    this.usedFallback = false,
  });
}

/// Service handling background direct SMS via Android SmsManager and URL launcher fallback.
///
/// ================= GOOGLE PLAY STORE SMS POLICY NOTE =================
/// Android allows apps to send SMS directly without opening the messaging app
/// when granted the `android.permission.SEND_SMS` permission.
///
/// 1. Sideloaded / Internal / Enterprise / Personal Use:
///    The app can request runtime `SEND_SMS` permission and send messages directly
///    via the native Android `SmsManager` (via our MethodChannel `com.dailykit.sos/sms`).
///
/// 2. Google Play Store Release Policy:
///    Google strictly restricts `SEND_SMS` to apps declared as the default SMS handler
///    or specific personal safety exceptions that have submitted and won a permissions
///    declaration form with video proof. If releasing to Google Play without that declaration,
///    the fallback mechanism [launchSmsFallback] will open the device's default SMS app
///    prefilled with the emergency message for user confirmation.
/// =====================================================================
class SmsService {
  static final SmsService instance = SmsService._internal();
  static const MethodChannel _channel = MethodChannel('com.dailykit.sos/sms');

  SmsService._internal();

  /// Attempts to send an SMS directly via native Android SmsManager.
  /// Automatically handles multipart messages for long texts (>160 characters).
  Future<bool> sendDirectSms({
    required String phone,
    required String message,
  }) async {
    try {
      final status = await Permission.sms.status;
      if (!status.isGranted) {
        final request = await Permission.sms.request();
        if (!request.isGranted) {
          throw Exception('SMS permission was denied by user.');
        }
      }

      final dynamic result = await _channel.invokeMethod('sendDirectSms', {
        'phone': phone,
        'message': message,
      });

      return result == true;
    } catch (e) {
      throw Exception('Direct SMS failed: $e');
    }
  }

  /// Fallback option: opens the default SMS app prefilled with recipient and message.
  Future<bool> launchSmsFallback({
    required String phone,
    required String message,
  }) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[\s\-]'), '');
      final encodedMessage = Uri.encodeComponent(message);
      final uri = Uri.parse('sms:$cleanPhone?body=$encodedMessage');

      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback generic SMS scheme
        final altUri = Uri(
          scheme: 'sms',
          path: cleanPhone,
          queryParameters: {'body': message},
        );
        return await launchUrl(altUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      return false;
    }
  }

  /// Sends the emergency alert to a list of phone numbers.
  /// Attempts direct SMS first; records error and provides fallback option if direct SMS fails.
  Future<List<SmsSendResult>> broadcastSms({
    required List<String> phones,
    required String message,
  }) async {
    final List<SmsSendResult> results = [];

    for (final phone in phones) {
      try {
        final success = await sendDirectSms(phone: phone, message: message);
        results.add(SmsSendResult(phone: phone, isSuccess: success));
      } catch (e) {
        results.add(SmsSendResult(
          phone: phone,
          isSuccess: false,
          error: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }

    return results;
  }
}

