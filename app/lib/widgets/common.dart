import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme.dart';
import 'visuals.dart';

/// White rounded card with a soft shadow — the base surface of every screen.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.border,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(kRadius),
        border: border != null ? Border.all(color: border!, width: 2) : null,
        boxShadow: kShadow,
      ),
      child: child,
    );
  }
}

/// Section heading used inside screens.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Round tinted icon badge.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 52,
  });
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: color, size: size * 0.55),
  );
}

class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warnBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            color: AppColors.warn,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              S.of(context).t('disclaimer'),
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF5A3A00),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular +/- button used by the steppers.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.size = 54,
  });
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Material(
      color: filled ? AppColors.primary : AppColors.primaryLight,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Icon(
          icon,
          size: size * 0.5,
          color: filled ? Colors.white : AppColors.primary,
        ),
      ),
    ),
  );
}

Future<num?> _typeNumber(BuildContext context, String label, num value) {
  final text = '${value.round()}';
  // Pre-select the number so typing replaces it (no need to delete first).
  final controller = TextEditingController(text: text)
    ..selection = TextSelection(baseOffset: 0, extentOffset: text.length);
  return showDialog<num>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(label, style: Theme.of(context).textTheme.titleLarge),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
        textAlign: TextAlign.center,
        onSubmitted: (v) => Navigator.pop(ctx, num.tryParse(v)),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx, num.tryParse(controller.text)),
          child: Text(S.of(context).t('done')),
        ),
      ],
    ),
  );
}

/// Big horizontal +/- stepper so elderly users rarely need the keyboard. Tap the number to type.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.unit = '',
    this.min = 0,
    this.max = 300,
    this.step = 1,
    this.icon,
  });

  final String label;
  final num value;
  final ValueChanged<num> onChanged;
  final String unit;
  final num min;
  final num max;
  final num step;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
              ],
              Text(label, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _RoundButton(
                icon: Icons.remove_rounded,
                onPressed: () => onChanged((value - step).clamp(min, max)),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final v = await _typeNumber(context, label, value);
                    if (v != null) onChanged(v.clamp(min, max));
                  },
                  child: Column(
                    children: [
                      Text(
                        '${value.round()}',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      if (unit.isNotEmpty)
                        Text(
                          unit,
                          style: const TextStyle(
                            fontSize: 17,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _RoundButton(
                icon: Icons.add_rounded,
                filled: true,
                onPressed: () => onChanged((value + step).clamp(min, max)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact vertical number tile (used side by side for systolic / diastolic).
class NumberTile extends StatelessWidget {
  const NumberTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 300,
    this.color,
  });
  final String label;
  final num value;
  final ValueChanged<num> onChanged;
  final num min;
  final num max;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color ?? AppColors.border,
          width: color != null ? 2.5 : 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
              height: 1.2,
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final v = await _typeNumber(context, label, value);
              if (v != null) onChanged(v.clamp(min, max));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '${value.round()}',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: color ?? AppColors.ink,
                  height: 1.15,
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundButton(
                icon: Icons.remove_rounded,
                size: 46,
                onPressed: () => onChanged((value - 1).clamp(min, max)),
              ),
              const SizedBox(width: 12),
              _RoundButton(
                icon: Icons.add_rounded,
                size: 46,
                filled: true,
                onPressed: () => onChanged((value + 1).clamp(min, max)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Large selectable tile for single/multi choice questions (no typing).
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.enabled = true,
    this.badge,
    this.multi = false,
    this.image,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;
  final bool enabled;
  final String? badge;
  final bool multi;
  final String? image; // 3D illustration (assets/3d) shown instead of [icon]

  @override
  Widget build(BuildContext context) {
    final color = enabled ? (iconColor ?? AppColors.primary) : AppColors.border;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? AppColors.primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 2.5 : 1.5,
              ),
            ),
            child: Row(
              children: [
                if (image != null) ...[
                  Opacity(
                    opacity: enabled ? 1 : 0.45,
                    child: Img3DBadge(image!, color: color, size: 44),
                  ),
                  const SizedBox(width: 14),
                ] else if (icon != null) ...[
                  IconBadge(icon: icon!, color: color, size: 42),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: enabled ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  )
                else if (enabled) ...[
                  const SizedBox(width: 10),
                  _SelectMark(selected: selected, multi: multi),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectMark extends StatelessWidget {
  const _SelectMark({required this.selected, required this.multi});
  final bool selected;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    final radius = multi ? BorderRadius.circular(9) : BorderRadius.circular(20);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: radius,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.muted,
          width: 2.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 26)
          : null,
    );
  }
}

/// Pill-shaped segmented control (replaces small underline tabs).
class SegmentedPills extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kShadow,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: i == index ? Colors.white : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Circular progress ring with centred text.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.label,
    this.size = 96,
    this.color = Colors.white,
    this.track = const Color(0x40FFFFFF),
    this.textColor = Colors.white,
  });
  final double value;
  final String label;
  final double size;
  final Color color;
  final Color track;
  final Color textColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      fit: StackFit.expand,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1)),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => CircularProgressIndicator(
            value: v,
            strokeWidth: size * 0.11,
            strokeCap: StrokeCap.round,
            color: color,
            backgroundColor: track,
          ),
        ),
        Center(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              label,
              style: TextStyle(
                fontSize: size * 0.26,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.onRetry, this.detail});
  final VoidCallback onRetry;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconBadge(
              icon: Icons.cloud_off_rounded,
              color: AppColors.muted,
              size: 96,
            ),
            const SizedBox(height: 16),
            Text(
              s.t('error_generic'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (detail != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: Text(s.t('retry'))),
          ],
        ),
      ),
    );
  }
}
