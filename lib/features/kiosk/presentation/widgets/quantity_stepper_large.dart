import 'package:flutter/material.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/config/themes/icebot_spacing.dart';

/// Kiosk-sized quantity stepper (+/–) with touch targets ≥ 64 × 64 dp.
///
/// The [–] button is disabled (shown as dimmed) when [quantity] ≤ [minQuantity].
/// Callbacks are null-safe: pass null to [onDecrease] to disable the button
/// (equivalent to passing [quantity] == [minQuantity]).
///
/// Usage:
/// ```dart
/// QuantityStepperLarge(
///   quantity: _qty,
///   onDecrease: _qty <= 1 ? null : () => setState(() => _qty--),
///   onIncrease: () => setState(() => _qty++),
/// )
/// ```
class QuantityStepperLarge extends StatelessWidget {
  const QuantityStepperLarge({
    required this.quantity,
    required this.onIncrease,
    this.onDecrease,
    this.minQuantity = 1,
    super.key,
  });

  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;
  final int minQuantity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canDecrease = onDecrease != null && quantity > minQuantity;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove_rounded,
          onTap: canDecrease ? onDecrease : null,
          scheme: scheme,
        ),
        const SizedBox(width: IceBotSpacing.sm),
        _CountDisplay(quantity: quantity, scheme: scheme),
        const SizedBox(width: IceBotSpacing.sm),
        _StepButton(icon: Icons.add_rounded, onTap: onIncrease, scheme: scheme),
      ],
    );
  }
}

// ─── Internal ─────────────────────────────────────────────────────────────────

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.scheme,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bg = enabled
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final fg = enabled ? scheme.primary : IceBotColors.botNavyMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(IceBotSpacing.innerRadius),
        child: Ink(
          width: IceBotSpacing.stepperButtonSize,
          height: IceBotSpacing.stepperButtonSize,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(IceBotSpacing.innerRadius),
            border: Border.all(
              color: enabled
                  ? scheme.primary.withValues(alpha: 0.25)
                  : IceBotColors.frostBorder,
            ),
          ),
          child: Icon(icon, size: 28, color: fg),
        ),
      ),
    );
  }
}

class _CountDisplay extends StatelessWidget {
  const _CountDisplay({required this.quantity, required this.scheme});

  final int quantity;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: IceBotSpacing.stepperCountWidth,
      height: IceBotSpacing.stepperButtonSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: IceBotColors.frostSurface,
        borderRadius: BorderRadius.circular(IceBotSpacing.innerRadius),
        border: Border.all(color: IceBotColors.frostBorder),
      ),
      child: Text(
        '$quantity',
        style: Theme.of(context).textTheme.displayMedium?.copyWith(
          color: IceBotColors.botNavy,
          fontSize: 28,
        ),
      ),
    );
  }
}
