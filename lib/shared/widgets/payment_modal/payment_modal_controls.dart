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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dense ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTextStyles.label.copyWith(color: AppColors.blue)),
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
    return Material(
      color: selected ? AppColors.blue : AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: compact ? 128 : 150,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 11 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: selected ? AppColors.blue : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: compact ? 19 : 24,
                color: selected ? AppColors.white : AppColors.blue,
              ),
              SizedBox(width: compact ? 6 : 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSm.copyWith(
                    color: selected ? AppColors.white : AppColors.textPrimary,
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
                return ListTile(
                  selected: selected,
                  selectedTileColor: AppColors.blue.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: CircleAvatar(
                      child: Text(user.fullName.isEmpty
                          ? '?'
                          : user.fullName[0].toUpperCase())),
                  title: Text(user.fullName),
                  trailing: selected
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.blue)
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
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

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.blueBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.blueDark.withValues(alpha: 0.08),
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
              const Icon(Icons.touch_app_rounded,
                  size: 16, color: AppColors.blue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Touch amount',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
              childAspectRatio: dense ? 1.35 : 1.25,
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

    switch (tone) {
      case _CashPadKeyTone.accent:
        foreground = AppColors.blue;
        background = AppColors.blueSurface;
        border = AppColors.blueBorder;
      case _CashPadKeyTone.danger:
        foreground = AppColors.error;
        background = AppColors.errorLight;
        border = AppColors.error.withValues(alpha: 0.18);
      case _CashPadKeyTone.normal:
        foreground = AppColors.textPrimary;
        background = AppColors.neutral50;
        border = AppColors.neutral200;
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
