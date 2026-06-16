// ignore_for_file: invalid_use_of_protected_member

part of '../screens/login_screen.dart';

extension _LoginScreenActions on _LoginScreenState {
  Future<void> _handleLogin() async {
    if (_isPrintingTest) return;

    if (_usernameCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your username and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await ref.read(authProvider.notifier).login(
            _usernameCtrl.text.trim(),
            _passwordCtrl.text.trim(),
          );
      if (!mounted) return;
      if (success) {
        final sessionReady = await _ensureSessionReady();
        if (!mounted) return;
        if (sessionReady) {
          final warmup = ref.read(posWarmupProvider);
          await warmup.warmUpSalesBeforeOpen();
          if (!mounted) return;
          context.go(AppRoutes.sales);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(
              Future<void>.delayed(
                const Duration(milliseconds: 350),
                warmup.warmUpDeferredAfterOpen,
              ),
            );
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid username or password.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _handlePrinterDrawerTest() async {
    if (_isPrintingTest) return;

    setState(() {
      _isPrintingTest = true;
      _printerTestMessage = null;
      _errorMessage = null;
    });

    try {
      final result =
          await ReceiptPrinterService.instance.printLoginHardwareTest();
      if (!mounted) return;
      setState(() {
        _isPrintingTest = false;
        _printerTestSucceeded = result.isSuccess;
        _printerTestMessage = result.isSuccess
            ? '${result.message} Cash drawer pulse sent.'
            : result.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPrintingTest = false;
        _printerTestSucceeded = false;
        _printerTestMessage =
            'Printer and drawer test failed: ${error.toString()}';
      });
    }
  }

  Future<bool> _ensureSessionReady() async {
    final sessionService = ref.read(posSessionServiceProvider);
    final canCloseSession =
        ref.read(authProvider).permissions['can_close_session'] == true;

    try {
      final status = await sessionService.fetchStatus();
      if (status.hasActiveSession) {
        if (status.activeSessionDateDiffDays == 1) {
          final choice = await _showClosePreviousSessionDialog(
            previousSessionDate: status.activeSessionDate,
            allowContinue: true,
          );
          if (choice == 'continue') {
            ref.invalidate(activeSessionStatusProvider);
            return true;
          } else if (choice == 'start_new') {
            if (!canCloseSession) {
              await ref.read(authProvider.notifier).logout();
              setState(() {
                _errorMessage =
                    'Access Denied: Your account cannot close daily sessions.';
              });
              return false;
            }
            if (!mounted) return false;
            final previousDate =
                Uri.encodeComponent(status.activeSessionDate ?? '');
            context.go(
              '${AppRoutes.sessionClosure}?forced=1&previous_date=$previousDate',
            );
            return false;
          } else {
            await ref.read(authProvider.notifier).logout();
            return false;
          }
        } else if (status.activeSessionDateDiffDays >= 2) {
          if (!canCloseSession) {
            await ref.read(authProvider.notifier).logout();
            setState(() {
              _errorMessage =
                  'Access Denied: Your account cannot close daily sessions.';
            });
            return false;
          }
          final choice = await _showClosePreviousSessionDialog(
            previousSessionDate: status.activeSessionDate,
            allowContinue: false,
          );
          if (choice == 'start_new') {
            if (!mounted) return false;
            final previousDate =
                Uri.encodeComponent(status.activeSessionDate ?? '');
            context.go(
              '${AppRoutes.sessionClosure}?forced=1&previous_date=$previousDate',
            );
            return false;
          } else {
            await ref.read(authProvider.notifier).logout();
            return false;
          }
        }
        ref.invalidate(activeSessionStatusProvider);
        return true;
      }

      if (status.isTodaySessionClosed) {
        final shouldReopen = await _showReopenSessionDialog();
        if (shouldReopen == true) {
          await sessionService.reopenTodaySession();
          ref.invalidate(activeSessionStatusProvider);
          return true;
        } else {
          await ref.read(authProvider.notifier).logout();
          return false;
        }
      }

      final shouldStart = await _showStartSessionDialog(DateTime.now());
      if (shouldStart != true) {
        await ref.read(authProvider.notifier).logout();
        return false;
      }

      await sessionService.openTodaySession();
      ref.invalidate(activeSessionStatusProvider);
      return true;
    } catch (error) {
      final message = sessionService.describeApiError(
        error,
        fallback: 'Unable to verify the current POS session.',
      );
      if (!mounted) return false;
      await _showSessionInfoDialog(
        title: 'Session Check Failed',
        message: message,
        primaryLabel: 'Back to Login',
      );
      await ref.read(authProvider.notifier).logout();
      return false;
    }
  }

  Future<bool?> _showStartSessionDialog(DateTime sessionDate) {
    final layout = context.posLayout;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.blue,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Start Session',
                style: AppTextStyles.h3.copyWith(color: AppColors.blue),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: layout.isCompact ? 360 : 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No active session is open for the POS.',
                style:
                    AppTextStyles.title.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                'Would you like to start the session of ${_formatSessionDate(sessionDate)} now?',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          SizedBox(
            height: layout.touchTarget - 2,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Start Session'),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showClosePreviousSessionDialog({
    required String? previousSessionDate,
    required bool allowContinue,
  }) {
    final layout = context.posLayout;
    final displayDate =
        previousSessionDate == null || previousSessionDate.isEmpty
            ? 'a previous business day'
            : previousSessionDate;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.lock_clock_rounded,
                color: AppColors.warning,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                allowContinue
                    ? 'Previous Session Open'
                    : 'Start Today\'s Session',
                style: AppTextStyles.h3.copyWith(color: AppColors.blue),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: layout.isCompact ? 360 : 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A previous session from $displayDate is still open.',
                style:
                    AppTextStyles.title.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                allowContinue
                    ? 'You can either continue working in this session, or close it to start a new session for today.'
                    : 'To start today\'s session, please close the previous one first. Navigation will stay locked until the closure is completed.',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('cancel'),
            child: const Text('Cancel'),
          ),
          if (allowContinue)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('continue'),
              style: TextButton.styleFrom(foregroundColor: AppColors.blue),
              child: const Text('Continue Session'),
            ),
          SizedBox(
            height: layout.touchTarget - 2,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop('start_new'),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(allowContinue ? 'Close & Start New' : 'Start Today'),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showReopenSessionDialog() {
    final layout = context.posLayout;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.restore_page_rounded,
                color: AppColors.blue,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Reopen Today\'s Session',
                style: AppTextStyles.h3.copyWith(color: AppColors.blue),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: layout.isCompact ? 360 : 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s session has already been closed.',
                style:
                    AppTextStyles.title.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                'Do you want to reopen it? Reopening the session will revert the cash drawer closure and stock verifications.',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          SizedBox(
            height: layout.touchTarget - 2,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.restore_rounded, size: 20),
              label: const Text('Reopen Session'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSessionInfoDialog({
    required String title,
    required String message,
    required String primaryLabel,
  }) {
    final layout = context.posLayout;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: AppColors.error,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.h3.copyWith(color: AppColors.blue),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: layout.isCompact ? 360 : 440),
          child: Text(
            message,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
        actions: [
          SizedBox(
            height: layout.touchTarget - 2,
            child: ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(primaryLabel),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSessionDate(DateTime date) {
    return DateFormat('EEEE, dd MMM yyyy').format(date);
  }
}
