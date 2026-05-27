import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/monitoring_service.dart';
import '../../../core/services/receipt_printer_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pos_layout.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  MonitoringSnapshot? _snapshot;
  bool _busy = false;
  String? _message;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final next = await PosMonitoringService.instance.snapshot();
    if (!mounted) return;
    setState(() => _snapshot = next);
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      await _refresh();
      if (!mounted) return;
      setState(() => _message = '$label completed.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$label failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadLogs() => _run(
        'Upload logs',
        () => PosMonitoringService.instance.uploadLogs(),
      );

  Future<void> _forceSync() => _run(
        'Force sync',
        () async {
          await PosMonitoringService.instance.flushQueue();
          await PosMonitoringService.instance.sendHeartbeat();
        },
      );

  Future<void> _testPrinter() => _run(
        'Test printer',
        () async {
          final result =
              await ReceiptPrinterService.instance.printHardwareSmokeTest();
          if (!result.isSuccess) throw Exception(result.message);
        },
      );

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final snapshot = _snapshot;

    return Scaffold(
      backgroundColor: AppColors.pageBackgroundFor(context),
      body: Padding(
        padding: EdgeInsets.all(layout.isCompact ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Diagnostics',
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.textPrimaryFor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Device status, backend connection, and local support tools.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondaryFor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                _ActionButton(
                  icon: Icons.upload_file_rounded,
                  label: 'Upload Logs',
                  busy: _busy,
                  onPressed: _uploadLogs,
                ),
                const SizedBox(width: 10),
                _ActionButton(
                  icon: Icons.sync_rounded,
                  label: 'Force Sync',
                  busy: _busy,
                  onPressed: _forceSync,
                ),
                const SizedBox(width: 10),
                _ActionButton(
                  icon: Icons.print_rounded,
                  label: 'Test Printer',
                  busy: _busy,
                  onPressed: _testPrinter,
                ),
              ],
            ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.08),
                  border:
                      Border.all(color: AppColors.blue.withValues(alpha: 0.18)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message!,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textPrimaryFor(context),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Expanded(
              child: snapshot == null
                  ? const Center(child: CircularProgressIndicator())
                  : GridView(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: layout.width > 1200 ? 3 : 2,
                        childAspectRatio: 3.5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      children: [
                        _DiagnosticTile(
                            label: 'App Version',
                            value: snapshot.appVersion,
                            icon: Icons.info_rounded),
                        _DiagnosticTile(
                            label: 'Device ID',
                            value: snapshot.deviceId,
                            icon: Icons.computer_rounded),
                        _DiagnosticTile(
                            label: 'API URL',
                            value: snapshot.apiUrl,
                            icon: Icons.link_rounded),
                        _DiagnosticTile(
                            label: 'Internet',
                            value: snapshot.internetStatus,
                            icon: Icons.wifi_rounded),
                        _DiagnosticTile(
                            label: 'Backend',
                            value: snapshot.backendStatus,
                            icon: Icons.cloud_done_rounded),
                        _DiagnosticTile(
                            label: 'Last Sync',
                            value: _fmt(snapshot.lastSyncAt),
                            icon: Icons.schedule_rounded),
                        _DiagnosticTile(
                            label: 'Unsynced Orders',
                            value: snapshot.unsyncedOrdersCount.toString(),
                            icon: Icons.pending_actions_rounded),
                        _DiagnosticTile(
                            label: 'Printer',
                            value: snapshot.printerStatus,
                            icon: Icons.print_rounded),
                        _DiagnosticTile(
                            label: 'Local DB',
                            value: snapshot.localDbStatus,
                            icon: Icons.storage_rounded),
                        _DiagnosticTile(
                            label: 'Last Error',
                            value: snapshot.lastError.isEmpty
                                ? '-'
                                : snapshot.lastError,
                            icon: Icons.warning_rounded,
                            wide: true),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime? value) {
    if (value == null) return '-';
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _DiagnosticTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool wide;

  const _DiagnosticTile({
    required this.label,
    required this.value,
    required this.icon,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panelFor(context),
        border: Border.all(color: AppColors.borderFor(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondaryFor(context),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: wide ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSm
                      .copyWith(color: AppColors.textPrimaryFor(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
