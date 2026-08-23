import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/config/themes/icebot_spacing.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/runtime_menu_models.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_formatters.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';

/// Menu product card representing a [RuntimeMenuItem].
///
/// Fully tappable card prioritizing the product image.
class ProductCard extends StatelessWidget {
  const ProductCard({required this.item, required this.onTap, super.key});

  final RuntimeMenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return KioskSectionCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(IceBotSpacing.cardRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image area (~60%)
              Expanded(
                flex: 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(IceBotSpacing.cardRadius),
                      ),
                      child: item.image?.cardUrl.isEmpty ?? true
                          ? Container(
                              color: scheme.primaryContainer,
                              child: Icon(
                                Icons.icecream_outlined,
                                size: 86,
                                color: scheme.onPrimaryContainer,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: item.image!.cardUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Container(
                                color: scheme.primaryContainer,
                                child: Icon(
                                  Icons.icecream_outlined,
                                  size: 86,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                    ),
                    // Gradient overlay to make price pop
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 80,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black38],
                          ),
                        ),
                      ),
                    ),
                    // Price pill at bottom-left
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            IceBotSpacing.pillRadius,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          KioskFormatters.money(
                            item.finalPrice,
                            currency: item.currency,
                          ),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: IceBotColors.icePrimary,
                                fontSize: 20,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Info area (~40%)
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 8),
                      // Prep time / options info
                      const Spacer(),
                      if (item.preparationTimeSeconds != null &&
                          item.preparationTimeSeconds! > 0)
                        KioskInfoPill(
                          icon: Icons.timer_outlined,
                          label: KioskFormatters.durationSeconds(
                            item.preparationTimeSeconds,
                          ),
                          backgroundColor: const Color(0xFFFFF7ED),
                          foregroundColor: const Color(0xFF8A5200),
                        ),
                    ],
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
