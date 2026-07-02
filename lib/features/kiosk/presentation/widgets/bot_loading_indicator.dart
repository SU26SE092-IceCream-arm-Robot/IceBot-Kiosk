import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Branded loading indicator for IceBot Kiosk.
///
/// Renders an animated "bot eye" pulse — a glowing [icePrimary] circle that
/// breathes in/out. This replaces the generic [CircularProgressIndicator]
/// throughout the app.
///
/// The animation is kept purely in Flutter (no extra packages) using a simple
/// scale + opacity [AnimationController]. The animation respects
/// [MediaQuery.disableAnimations].
///
/// Usage:
/// ```dart
/// // Inline spinner (e.g. inside a button)
/// BotLoadingIndicator(size: 26)
///
/// // Standalone larger version for loading panels
/// BotLoadingIndicator(size: 56)
/// ```
class BotLoadingIndicator extends StatefulWidget {
  const BotLoadingIndicator({
    this.size = 40,
    this.color,
    super.key,
  });

  final double size;
  final Color? color;

  @override
  State<BotLoadingIndicator> createState() => _BotLoadingIndicatorState();
}

class _BotLoadingIndicatorState extends State<BotLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _ringScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacity = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _ringScale = Tween<double>(begin: 1.0, end: 1.55).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.of(context).disableAnimations;
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final size = widget.size;

    if (disableAnim) {
      return _StaticDot(size: size, color: color);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer expanding ring (glow halo)
              Opacity(
                opacity: (1.0 - _controller.value).clamp(0.0, 0.35),
                child: Transform.scale(
                  scale: _ringScale.value,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
              // Core "eye" dot
              Transform.scale(
                scale: _scale.value,
                child: Opacity(
                  opacity: _opacity.value,
                  child: Container(
                    width: size * 0.5,
                    height: size * 0.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.40),
                          blurRadius: size * 0.35,
                          spreadRadius: size * 0.08,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Tiny "pupil" highlight
              Container(
                width: size * 0.12,
                height: size * 0.12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Fallback static dot for when animations are disabled.
class _StaticDot extends StatelessWidget {
  const _StaticDot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Container(
          width: size * 0.5,
          height: size * 0.5,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

/// Horizontal "bot beam" scan animation used during payment processing.
///
/// A thin coloured beam sweeps left-to-right (ping-pong) to signal active
/// polling without implying a specific percentage of completion.
///
/// Usage:
/// ```dart
/// BotBeamScanner(height: 5)
/// ```
class BotBeamScanner extends StatefulWidget {
  const BotBeamScanner({
    this.height = 5,
    this.color,
    super.key,
  });

  final double height;
  final Color? color;

  @override
  State<BotBeamScanner> createState() => _BotBeamScannerState();
}

class _BotBeamScannerState extends State<BotBeamScanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.of(context).disableAnimations;
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final trackColor = color.withValues(alpha: 0.15);

    if (disableAnim) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(widget.height / 2),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            // Pingpong via sin: 0→1→0 over one period
            final t = (math.sin(_controller.value * math.pi * 2) + 1) / 2;
            final beamWidth = totalWidth * 0.38;
            final left = t * (totalWidth - beamWidth);

            return Stack(
              children: [
                // Track
                Container(
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: BorderRadius.circular(widget.height / 2),
                  ),
                ),
                // Beam
                Positioned(
                  left: left,
                  child: Container(
                    width: beamWidth,
                    height: widget.height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.height / 2),
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.0),
                          color,
                          color.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
