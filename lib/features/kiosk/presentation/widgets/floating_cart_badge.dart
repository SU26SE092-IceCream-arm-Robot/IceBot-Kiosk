import 'package:flutter/material.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/config/themes/icebot_spacing.dart';

/// A floating pill badge shown at the bottom of the screen when the cart has items.
///
/// It displays the cart icon, item count, and the formatted total price.
/// Tapping it triggers [onTap], which usually navigates to the Cart screen.
///
/// It uses a scale transition so it appears/disappears smoothly.
class FloatingCartBadge extends StatelessWidget {
  const FloatingCartBadge({
    required this.itemCount,
    required this.totalPriceFormatted,
    required this.onTap,
    super.key,
  });

  final int itemCount;
  final String totalPriceFormatted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: itemCount > 0 ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: itemCount > 0 ? onTap : null,
          borderRadius: BorderRadius.circular(IceBotSpacing.pillRadius),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: IceBotColors.botNavy,
              borderRadius: BorderRadius.circular(IceBotSpacing.pillRadius),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33102033),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Badge.count(
                  count: itemCount,
                  backgroundColor: IceBotColors.sorbetAccent,
                  textColor: Colors.white,
                  child: const Icon(
                    Icons.shopping_cart_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  totalPriceFormatted,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
