part of '../screens/session_closure_screen.dart';

class _StepTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool done;
  final bool enabled;
  final VoidCallback? onTap;

  const _StepTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.done,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final isInteractive = enabled || selected || done;
    final Color color = !isInteractive
        ? AppColors.neutral400
        : selected
            ? AppColors.blue
            : (done ? AppColors.success : AppColors.neutral500);
    final Color bgColor = !isInteractive
        ? AppColors.neutral50
        : selected
            ? AppColors.blueSurface
            : (done ? AppColors.successLight : AppColors.neutral100);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: BoxConstraints(minHeight: layout.touchTarget),
          padding: EdgeInsets.symmetric(
            horizontal: layout.isCompact ? 16 : 18,
            vertical: layout.isCompact ? 10 : 11,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: color.withValues(alpha: isInteractive ? 0.4 : 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(done ? Icons.check_circle_rounded : icon,
                  size: 20, color: color),
              const SizedBox(width: 10),
              Text(label, style: AppTextStyles.title.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EodKpi extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _EodKpi(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    return SizedBox(
      width: layout.isCompact ? 220 : 240,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.textSecondary)),
                Text(value, style: AppTextStyles.h4.copyWith(color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TheoreticalActualHeader extends StatelessWidget {
  const _TheoreticalActualHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.calculate_rounded,
                  color: AppColors.blue, size: 20),
              const SizedBox(width: 8),
              Text('Theoretical Values', style: AppTextStyles.h4),
            ],
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.edit_rounded,
                  color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text('Actual Values (Counted)', style: AppTextStyles.h4),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final double theoryAmount;
  final double totalRevenue;
  final Color color;
  final TextEditingController actualCtrl;
  final bool submitted;
  final VoidCallback onChanged;

  const _ComparisonRow({
    required this.label,
    required this.theoryAmount,
    required this.totalRevenue,
    required this.color,
    required this.actualCtrl,
    required this.submitted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalRevenue > 0 ? theoryAmount / totalRevenue : 0.0;

    final entered = double.tryParse(actualCtrl.text);
    final diff = entered != null ? entered - theoryAmount : null;
    final hasDiscrepancy = diff != null && diff.abs() > 0.001;

    return Row(
      children: [
        // Left: Theoretical Bar
        Expanded(
          child: Row(
            children: [
              SizedBox(
                  width: 90, child: Text(label, style: AppTextStyles.body)),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppColors.neutral100,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
                child: Text('${theoryAmount.toStringAsFixed(3)} DT',
                    style: AppTextStyles.priceSm, textAlign: TextAlign.right),
              ),
            ],
          ),
        ),
        const SizedBox(width: 32),
        // Right: Actual Input
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: actualCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    hintText: '0.000',
                    suffixText: 'DT',
                    errorText: submitted && actualCtrl.text.isEmpty
                        ? 'Required'
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: hasDiscrepancy
                              ? AppColors.error
                              : AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color:
                              hasDiscrepancy ? AppColors.error : AppColors.blue,
                          width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Difference indicator
              SizedBox(
                width: 70,
                child: diff != null
                    ? Text(
                        '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(3)}',
                        textAlign: TextAlign.right,
                        style: AppTextStyles.titleSm.copyWith(
                          color: hasDiscrepancy
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
