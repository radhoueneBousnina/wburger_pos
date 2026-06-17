part of '../payment_modal.dart';

class _PaymentSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool dense;

  const _PaymentSectionCard({
    required this.title,
    required this.child,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentFor(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dense ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.label.copyWith(color: accent)),
          SizedBox(height: dense ? 8 : 12),
          child,
        ],
      ),
    );
  }
}

class _PaymentChoiceTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool compact;

  const _PaymentChoiceTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = AppColors.selectedSurfaceFor(context);
    final selectedText = AppColors.selectedTextFor(context);
    final accent = AppColors.accentFor(context);
    final textColor = AppColors.textPrimaryFor(context);
    return Material(
      color: selected ? selectedColor : AppColors.panelFor(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: compact ? 128 : 150,
          constraints: BoxConstraints(minHeight: compact ? 64 : 70),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 16,
            vertical: compact ? 14 : 16,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? selectedColor : AppColors.borderFor(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: compact ? 19 : 24,
                color: selected ? selectedText : accent,
              ),
              SizedBox(width: compact ? 6 : 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSm.copyWith(
                    color: selected ? selectedText : textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffPicker extends ConsumerWidget {
  final String? selectedStaffId;
  final TextEditingController searchController;
  final ValueChanged<String> onChanged;

  const _StaffPicker({
    required this.selectedStaffId,
    required this.searchController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider);
    return staffAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text(error.toString(),
          style: const TextStyle(color: AppColors.error)),
      data: (staff) => Column(
        children: [
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search staff...',
            ),
            onChanged: (_) => (context as Element).markNeedsBuild(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.separated(
              itemCount: staff
                  .where((s) => s.fullName
                      .toLowerCase()
                      .contains(searchController.text.toLowerCase()))
                  .length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final filtered = staff
                    .where((s) => s.fullName
                        .toLowerCase()
                        .contains(searchController.text.toLowerCase()))
                    .toList();
                final user = filtered[index];
                final selected = selectedStaffId == user.id;
                final accent = AppColors.accentFor(context);
                return ListTile(
                  selected: selected,
                  selectedTileColor: accent.withValues(alpha: 0.14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: CircleAvatar(
                      child: Text(user.fullName.isEmpty
                          ? '?'
                          : user.fullName[0].toUpperCase())),
                  title: Text(
                    user.fullName,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimaryFor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: selected
                      ? Icon(Icons.check_circle_rounded, color: accent)
                      : null,
                  onTap: () => onChanged(user.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentInfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _PaymentInfoPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bgAlpha = AppColors.isTraining(context) ? 0.16 : 0.1;
    final borderAlpha = AppColors.isTraining(context) ? 0.34 : 0.22;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: borderAlpha)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTextStyles.titleSm.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _CashNumberPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final bool dense;

  const _CashNumberPad({
    required this.onDigit,
    required this.onDelete,
    required this.onClear,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0'];
    final accent = AppColors.accentFor(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.panelFor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderFor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppColors.isTraining(context) ? 0.22 : 0.08,
            ),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.touch_app_rounded, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Touch amount',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondaryFor(context),
                  ),
                ),
              ),
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  minimumSize: Size(96, context.posLayout.touchTarget - 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
          SizedBox(height: dense ? 6 : 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 12,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: dense ? 6 : 8,
              crossAxisSpacing: dense ? 6 : 8,
              childAspectRatio: dense ? 1.18 : 1.12,
            ),
            itemBuilder: (context, index) {
              if (index == 11) {
                return _CashPadKey(
                  icon: Icons.backspace_rounded,
                  tone: _CashPadKeyTone.danger,
                  dense: dense,
                  onTap: onDelete,
                );
              }
              final value = keys[index];
              return _CashPadKey(
                label: value,
                tone: value == '.'
                    ? _CashPadKeyTone.accent
                    : _CashPadKeyTone.normal,
                dense: dense,
                onTap: () => onDigit(value),
              );
            },
          ),
        ],
      ),
    );
  }
}

enum _CashPadKeyTone { normal, accent, danger }

class _CashPadKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final _CashPadKeyTone tone;
  final VoidCallback onTap;
  final bool dense;

  const _CashPadKey({
    this.label,
    this.icon,
    required this.tone,
    required this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color foreground;
    final Color background;
    final Color border;
    final isTraining = AppColors.isTraining(context);

    switch (tone) {
      case _CashPadKeyTone.accent:
        foreground = AppColors.accentFor(context);
        background = AppColors.accentFor(context).withValues(alpha: 0.16);
        border = AppColors.accentFor(context).withValues(alpha: 0.38);
      case _CashPadKeyTone.danger:
        foreground = AppColors.error;
        background = AppColors.error.withValues(alpha: isTraining ? 0.16 : 0.1);
        border = AppColors.error.withValues(alpha: isTraining ? 0.32 : 0.18);
      case _CashPadKeyTone.normal:
        foreground = AppColors.textPrimaryFor(context);
        background = AppColors.elevatedSurfaceFor(context);
        border = AppColors.borderFor(context);
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: border),
          ),
          child: icon == null
              ? Text(
                  label!,
                  style: (dense ? AppTextStyles.h3 : AppTextStyles.h2)
                      .copyWith(color: foreground),
                )
              : Icon(icon, size: dense ? 24 : 28, color: foreground),
        ),
      ),
    );
  }
}
