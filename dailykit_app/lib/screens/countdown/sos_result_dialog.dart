import 'package:flutter/material.dart';
import '../../services/sms_service.dart';

class SosResultDialog extends StatelessWidget {
  final int sentCount;
  final int failedCount;
  final List<SmsSendResult> results;
  final String alertMessage;

  const SosResultDialog({
    super.key,
    required this.sentCount,
    required this.failedCount,
    required this.results,
    required this.alertMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAllSuccess = failedCount == 0 && sentCount > 0;

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
                  color: isAllSuccess ? Colors.green.shade50 : Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAllSuccess ? Icons.check_circle_rounded : Icons.warning_rounded,
                  size: 48,
                  color: isAllSuccess ? Colors.green.shade700 : Colors.orange.shade800,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isAllSuccess ? 'SOS Alert Dispatched!' : 'SOS Broadcast Summary',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isAllSuccess
                  ? 'Successfully sent emergency SMS to $sentCount contact${sentCount > 1 ? 's' : ''}.'
                  : 'Sent to $sentCount contact${sentCount != 1 ? 's' : ''}, $failedCount failed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isAllSuccess ? Colors.green.shade800 : Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // List of recipients with individual status
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: results.length,
                separatorBuilder: (context, index) => const Divider(height: 12),
                itemBuilder: (context, i) {
                  final item = results[i];
                  return Row(
                    children: [
                      Icon(
                        item.isSuccess ? Icons.check_circle : Icons.error,
                        size: 20,
                        color: item.isSuccess ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.phone,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (!item.isSuccess && item.error != null)
                              Text(
                                item.error!,
                                style: const TextStyle(fontSize: 11, color: Colors.red),
                              ),
                          ],
                        ),
                      ),
                      if (!item.isSuccess)
                        TextButton.icon(
                          onPressed: () => SmsService.instance.launchSmsFallback(
                            phone: item.phone,
                            message: alertMessage,
                          ),
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text('SMS App', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

