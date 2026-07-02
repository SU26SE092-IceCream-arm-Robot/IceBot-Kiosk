import 'package:flutter/material.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/config/themes/icebot_spacing.dart';

/// A kiosk-sized primary CTA button using the Frost-Tech icePrimary colour.
///
/// Height is locked at [IceBotSpacing.primaryCTAHeight] (72 dp).
/// When [isLoading] is true the label is replaced with a small spinner so the
/// button stays the same size and the layout never jumps.
///
/// Usage:
/// ```dart
/// IcePrimaryButton(
///   label: 'Thêm vào giỏ hàng',
///   icon: Icons.add_shopping_cart,
///   onPressed: () { … },
/// )
/// ```
class IcePrimaryButton extends StatelessWidget {
  const IcePrimaryButton({
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.expand = true,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// When true (default) the button stretches to fill its parent's width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final buttonChild = _ButtonContent(
      label: label,
      icon: icon,
      isLoading: isLoading,
    );

    final btn = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(
          double.minPositive,
          IceBotSpacing.primaryCTAHeight,
        ),
      ),
      child: buttonChild,
    );

    if (!expand) return btn;
    return SizedBox(width: double.infinity, child: btn);
  }
}

/// A kiosk-sized secondary / outlined CTA button.
///
/// Height is locked at [IceBotSpacing.secondaryCTAHeight] (64 dp).
class IceSecondaryButton extends StatelessWidget {
  const IceSecondaryButton({
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.expand = true,
    this.isDanger = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool expand;

  /// When true renders with [IceBotColors.dangerRed] border and text colour
  /// for destructive actions (e.g. "Hủy đơn hàng").
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? IceBotColors.dangerRed : IceBotColors.icePrimary;

    final btn = OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color, width: 1.8),
        minimumSize: const Size(
          double.minPositive,
          IceBotSpacing.secondaryCTAHeight,
        ),
      ),
      child: _ButtonContent(label: label, icon: icon, isLoading: isLoading),
    );

    if (!expand) return btn;
    return SizedBox(width: double.infinity, child: btn);
  }
}

// ─── Internal ─────────────────────────────────────────────────────────────────

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (icon == null) {
      return Text(label);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}
