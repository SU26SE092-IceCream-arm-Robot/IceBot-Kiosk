import 'package:flutter/material.dart';

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
  double get screenPadding => isCompact ? 18 : 32;
  double get sectionGap => isCompact ? 18 : 26;
  double get maxPortraitPanelWidth => isCompact ? double.infinity : 760;
  double get bottomOverlayPadding => isCompact ? 120 : 112;

  static KioskLayoutSpec of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isPortrait = size.height > size.width;
    return KioskLayoutSpec(
      width: size.width,
      height: size.height,
      isPortrait: isPortrait,
      isTallKiosk: isPortrait && size.height / size.width >= 1.8,
    );
  }
}

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
          colors: [Color(0xFFF1FAF6), Color(0xFFF8F7F0), Color(0xFFF6F8F4)],
        ),
      ),
      child: child,
    );
  }
}

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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8E3DF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F3D38),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

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

    return SafeArea(
      minimum: EdgeInsets.fromLTRB(
        layout.screenPadding,
        10,
        layout.screenPadding,
        layout.isCompact ? 16 : 24,
      ),
      child: KioskSectionCard(
        padding: EdgeInsets.all(layout.isCompact ? 14 : 16),
        child: layout.isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: _actions(context),
              )
            : Row(
                children: [
                  if (leading != null) ...[
                    Expanded(child: leading!),
                    const SizedBox(width: 16),
                  ],
                  if (secondaryLabel != null && onSecondary != null) ...[
                    OutlinedButton.icon(
                      onPressed: onSecondary,
                      icon: Icon(secondaryIcon ?? Icons.arrow_back),
                      label: Text(secondaryLabel!),
                    ),
                    const SizedBox(width: 12),
                  ],
                  SizedBox(
                    width: 300,
                    child: FilledButton.icon(
                      onPressed: onPrimary,
                      icon: Icon(primaryIcon),
                      label: Text(primaryLabel),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    return [
      if (leading != null) ...[leading!, const SizedBox(height: 12)],
      FilledButton.icon(
        onPressed: onPrimary,
        icon: Icon(primaryIcon),
        label: Text(primaryLabel),
      ),
      if (secondaryLabel != null && onSecondary != null) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onSecondary,
          icon: Icon(secondaryIcon ?? Icons.arrow_back),
          label: Text(secondaryLabel!),
        ),
      ],
    ];
  }
}

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
    final colorScheme = Theme.of(context).colorScheme;
    final layout = KioskLayoutSpec.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: layout.maxPortraitPanelWidth),
        child: Padding(
          padding: EdgeInsets.all(layout.screenPadding),
          child: KioskSectionCard(
            padding: EdgeInsets.symmetric(
              horizontal: layout.isCompact ? 26 : 48,
              vertical: layout.isCompact ? 34 : 52,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: layout.isCompact ? 108 : 124,
                  height: layout.isCompact ? 108 : 124,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xAAD8E3DF)),
                  ),
                  child: Icon(
                    icon,
                    size: layout.isCompact ? 66 : 76,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: layout.isCompact
                      ? Theme.of(context).textTheme.displayMedium
                      : Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: layout.isCompact ? 240 : 320,
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
    final colorScheme = Theme.of(context).colorScheme;
    final layout = KioskLayoutSpec.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: layout.maxPortraitPanelWidth),
        child: Padding(
          padding: EdgeInsets.all(layout.screenPadding),
          child: KioskSectionCard(
            padding: EdgeInsets.all(layout.isCompact ? 28 : 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: layout.isCompact ? 104 : 116,
                  height: layout.isCompact ? 104 : 116,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xAAD8E3DF)),
                  ),
                  child: Icon(
                    icon,
                    color: colorScheme.onPrimaryContainer,
                    size: layout.isCompact ? 58 : 66,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 30),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.touch_app_outlined),
                    label: Text(actionLabel!),
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
    final colorScheme = Theme.of(context).colorScheme;
    final background = backgroundColor ?? colorScheme.primaryContainer;
    final foreground = foregroundColor ?? colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: foreground.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: foreground, size: 22),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
