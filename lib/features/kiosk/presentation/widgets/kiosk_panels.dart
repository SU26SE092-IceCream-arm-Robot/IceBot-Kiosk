import 'package:flutter/material.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/config/themes/icebot_spacing.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/bot_loading_indicator.dart';

// ─── Layout helper ────────────────────────────────────────────────────────────

/// Responsive layout breakpoints and computed values for kiosk portrait screens.
///
/// All screens obtain this via [KioskLayoutSpec.of(context)]. Values adapt to
/// 1080×1920, 1080×2400 and 1080×2520 portrait ratios as well as landscape
/// debug views.
class KioskLayoutSpec {
  const KioskLayoutSpec({
    required this.width,
    required this.height,
    required this.isPortrait,
    required this.isTallKiosk,
  });

  final double width;
  final double height;
  final bool isPortrait;
  final bool isTallKiosk;

  bool get isCompact => width < 700;
  bool get isWideLandscape => !isPortrait && width >= 980;
  bool get useSingleColumn => isTallKiosk || !isWideLandscape;
  int get portraitMenuColumns => width < 700 ? 1 : 2;

  double get screenPadding =>
      isCompact ? IceBotSpacing.screenPaddingCompact : IceBotSpacing.screenPaddingNormal;

  double get sectionGap =>
      isCompact ? IceBotSpacing.sectionGapCompact : IceBotSpacing.sectionGapNormal;

  double get maxPortraitPanelWidth => isCompact ? double.infinity : 780;

  double get bottomOverlayPadding => isCompact
      ? IceBotSpacing.bottomOverlayPaddingCompact
      : IceBotSpacing.bottomOverlayPaddingNormal;

  static KioskLayoutSpec of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isPortrait = size.height > size.width;
    return KioskLayoutSpec(
      width: size.width,
      height: size.height,
      isPortrait: isPortrait,
      // Tall kiosk: portrait ratio ≥ 1.6 (covers 1080×1920 and taller)
      isTallKiosk: isPortrait && size.height / size.width >= 1.6,
    );
  }
}

// ─── KioskBackdrop ────────────────────────────────────────────────────────────

/// Full-bleed background used as the root of every screen body.
///
/// Renders the Frost-Tech gradient: a very subtle top-to-bottom shift from
/// [IceBotColors.frostSurface] to white, giving screens a cool, airy feel
/// without being distracting.
class KioskBackdrop extends StatelessWidget {
  const KioskBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            IceBotColors.frostSurface,        // #F4FAFF
            Color(0xFFF9FCFF),                // mid
            IceBotColors.snowCard,             // #FFFFFF
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: child,
    );
  }
}

// ─── KioskSectionCard ─────────────────────────────────────────────────────────

/// White card panel used as the primary content container on every screen.
///
/// Uses Frost-Tech card tokens: 20 dp radius, frost border, soft shadow.
class KioskSectionCard extends StatelessWidget {
  const KioskSectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(28),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: IceBotColors.snowCard,
        borderRadius: BorderRadius.circular(IceBotSpacing.cardRadius),
        border: Border.all(color: IceBotColors.frostBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A102033),
            blurRadius: IceBotSpacing.shadowBlur,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

// ─── KioskBottomActionBar ─────────────────────────────────────────────────────

/// Fixed bottom action bar with a primary CTA and optional secondary CTA.
///
/// Primary button height: [IceBotSpacing.primaryCTAHeight] (72 dp).
/// Secondary button height: [IceBotSpacing.secondaryCTAHeight] (64 dp).
///
/// On compact screens buttons are stacked vertically.
/// On wide screens they are laid out horizontally: [leading] | secondary | primary.
class KioskBottomActionBar extends StatelessWidget {
  const KioskBottomActionBar({
    required this.primaryLabel,
    required this.onPrimary,
    required this.primaryIcon,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryIcon,
    this.leading,
    super.key,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final IconData primaryIcon;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final IconData? secondaryIcon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final layout = KioskLayoutSpec.of(context);
    final padding = EdgeInsets.fromLTRB(
      layout.screenPadding,
      12,
      layout.screenPadding,
      layout.isCompact ? 18 : 26,
    );

    return SafeArea(
      minimum: padding,
      child: KioskSectionCard(
        padding: EdgeInsets.all(layout.isCompact ? 14 : 16),
        child: layout.isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: _actionsVertical(context),
              )
            : Row(
                children: _actionsHorizontal(context),
              ),
      ),
    );
  }

  List<Widget> _actionsVertical(BuildContext context) {
    return [
      if (leading != null) ...[leading!, const SizedBox(height: 12)],
      _PrimaryButton(
        label: primaryLabel,
        icon: primaryIcon,
        onPressed: onPrimary,
      ),
      if (secondaryLabel != null && onSecondary != null) ...[
        const SizedBox(height: 10),
        _SecondaryButton(
          label: secondaryLabel!,
          icon: secondaryIcon ?? Icons.arrow_back,
          onPressed: onSecondary,
        ),
      ],
    ];
  }

  List<Widget> _actionsHorizontal(BuildContext context) {
    return [
      if (leading != null) ...[
        Expanded(child: leading!),
        const SizedBox(width: 16),
      ],
      if (secondaryLabel != null && onSecondary != null) ...[
        _SecondaryButton(
          label: secondaryLabel!,
          icon: secondaryIcon ?? Icons.arrow_back,
          onPressed: onSecondary,
          expand: false,
        ),
        const SizedBox(width: 12),
      ],
      SizedBox(
        width: 300,
        child: _PrimaryButton(
          label: primaryLabel,
          icon: primaryIcon,
          onPressed: onPrimary,
        ),
      ),
    ];
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size(
          double.minPositive,
          IceBotSpacing.primaryCTAHeight,
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.expand = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(
          double.minPositive,
          IceBotSpacing.secondaryCTAHeight,
        ),
      ),
    );
    if (!expand) return btn;
    return SizedBox(width: double.infinity, child: btn);
  }
}

// ─── KioskLoadingPanel ────────────────────────────────────────────────────────

/// Full-screen centred loading panel — Frost-Tech reskin.
///
/// Uses [BotLoadingIndicator] instead of the generic linear progress bar.
class KioskLoadingPanel extends StatelessWidget {
  const KioskLoadingPanel({
    required this.title,
    required this.message,
    this.icon = Icons.icecream_outlined,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final layout = KioskLayoutSpec.of(context);
    final iconBoxSize = layout.isCompact ? 108.0 : 128.0;
    final iconSize = layout.isCompact ? 64.0 : 78.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: layout.maxPortraitPanelWidth),
        child: Padding(
          padding: EdgeInsets.all(layout.screenPadding),
          child: KioskSectionCard(
            padding: EdgeInsets.symmetric(
              horizontal: layout.isCompact ? 28 : 52,
              vertical: layout.isCompact ? 36 : 56,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon container
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(IceBotSpacing.cardRadius),
                    border: Border.all(
                      color: IceBotColors.frostBorder,
                    ),
                  ),
                  child: Icon(icon, size: iconSize, color: scheme.primary),
                ),
                const SizedBox(height: 32),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: layout.isCompact
                      ? Theme.of(context).textTheme.displayMedium
                      : Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 40),
                // Branded loading indicator
                BotLoadingIndicator(size: layout.isCompact ? 44 : 56),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── KioskEmptyState ──────────────────────────────────────────────────────────

/// Full-screen empty-state panel — Frost-Tech reskin.
class KioskEmptyState extends StatelessWidget {
  const KioskEmptyState({
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final layout = KioskLayoutSpec.of(context);
    final iconBoxSize = layout.isCompact ? 104.0 : 120.0;
    final iconSize = layout.isCompact ? 58.0 : 70.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: layout.maxPortraitPanelWidth),
        child: Padding(
          padding: EdgeInsets.all(layout.screenPadding),
          child: KioskSectionCard(
            padding: EdgeInsets.all(layout.isCompact ? 28 : 44),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(IceBotSpacing.cardRadius),
                    border: Border.all(color: IceBotColors.frostBorder),
                  ),
                  child: Icon(icon, color: scheme.primary, size: iconSize),
                ),
                const SizedBox(height: 28),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.touch_app_outlined, size: 22),
                    label: Text(actionLabel!),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(
                        double.minPositive,
                        IceBotSpacing.primaryCTAHeight,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── KioskInfoPill ────────────────────────────────────────────────────────────

/// Compact pill / label chip used for metadata tags (price, prep time, count).
///
/// Fully rounded by default ([IceBotSpacing.pillRadius]).
class KioskInfoPill extends StatelessWidget {
  const KioskInfoPill({
    required this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? scheme.primaryContainer;
    final fg = foregroundColor ?? scheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(IceBotSpacing.pillRadius),
        border: Border.all(color: fg.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
