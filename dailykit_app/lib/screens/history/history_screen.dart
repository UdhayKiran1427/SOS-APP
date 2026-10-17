import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/database_helper.dart';
import '../../services/sync_service.dart';
import '../../services/sms_service.dart';
import '../../models/alert_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<AlertModel> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final list = await DatabaseHelper.instance.getAlerts(limit: 50);
      if (mounted) {
        setState(() {
          _alerts = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAndSync() async {
    await SyncService.instance.syncAll();
    await _loadAlerts();
  }

  Future<void> _openMapUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Alert History', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync & Refresh',
            onPressed: _refreshAndSync,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshAndSync,
              child: _alerts.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_toggle_off_rounded,
                              size: 80,
                              color: theme.colorScheme.primary.withAlpha(90),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Emergency Alerts Logged',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Whenever an SOS is triggered, a timestamped report with GPS coordinates and recipient delivery status will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _alerts.length,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemBuilder: (context, i) {
                        final alert = _alerts[i];
                        final isLive = alert.locationSource == 'live';
                        final hasCoords = alert.latitude != null && alert.longitude != null;
                        final formattedDate = "${alert.triggeredAt.day.toString().padLeft(2, '0')}/${alert.triggeredAt.month.toString().padLeft(2, '0')}/${alert.triggeredAt.year} at ${alert.triggeredAt.hour.toString().padLeft(2, '0')}:${alert.triggeredAt.minute.toString().padLeft(2, '0')}";

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: alert.failedCount == 0
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              child: Icon(
                                alert.failedCount == 0
                                    ? Icons.check_circle_outline
                                    : Icons.warning_amber_rounded,
                                color: alert.failedCount == 0
                                    ? Colors.green.shade800
                                    : Colors.orange.shade900,
                              ),
                            ),
                            title: Text(
                              formattedDate,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isLive ? Colors.green.shade50 : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isLive ? 'Live GPS' : 'Last Known Location',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isLive ? Colors.green.shade800 : Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sent: ${alert.sentCount} | Failed: ${alert.failedCount}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(),
                                    // Location details & clickable map link
                                    if (hasCoords) ...[
                                      InkWell(
                                        onTap: () => _openMapUrl(alert.mapUrl),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.pin_drop, color: Colors.red, size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '${alert.latitude!.toStringAsFixed(6)}, ${alert.longitude!.toStringAsFixed(6)} (Tap to open Map)',
                                                  style: const TextStyle(
                                                    color: Colors.blue,
                                                    fontSize: 13,
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],

                                    // Message text preview
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        alert.message,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Recipients breakdown
                                    const Text(
                                      'Recipients Status:',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 6),
                                    ...alert.recipients.map((rec) {
                                      final isSent = rec.status == 'sent';
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isSent ? Icons.check : Icons.close,
                                              size: 16,
                                              color: isSent ? Colors.green : Colors.red,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${rec.contactName != null ? '${rec.contactName} (' : ''}${rec.phone}${rec.contactName != null ? ')' : ''}',
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                            ),
                                            if (!isSent)
                                              TextButton.icon(
                                                onPressed: () => SmsService.instance.launchSmsFallback(
                                                  phone: rec.phone,
                                                  message: alert.message,
                                                ),
                                                icon: const Icon(Icons.send_rounded, size: 14),
                                                label: const Text('Resend', style: TextStyle(fontSize: 11)),
                                                style: TextButton.styleFrom(
                                                  visualDensity: VisualDensity.compact,
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

