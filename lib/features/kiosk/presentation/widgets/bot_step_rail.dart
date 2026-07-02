import 'package:flutter/material.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/config/themes/icebot_spacing.dart';

/// BotStepRail — the signature 4-step horizontal purchase flow indicator.
///
/// Steps:
///   0 → Chọn món
///   1 → Giỏ hàng
///   2 → Thanh toán
///   3 → Trạng thái
///
/// The active step node renders a glowing "bot eye" using [IceBotColors.icePrimary].
/// Completed steps are filled solid. Future steps are outlined in muted colour.
///
/// [isError] — when true, the active step node renders in [IceBotColors.dangerRed].
///
/// This widget is sized to fit within any screen header (fixed height ~56 dp).
/// It is stateless and purely driven by the passed [currentStep] integer.
class BotStepRail extends StatelessWidget {
  const BotStepRail({
    required this.currentStep,
    this.isError = false,
    super.key,
  });

  final int currentStep;
  final bool isError;

  static const List<String> _labels = [
    'Chọn món',
    'Giỏ hàng',
    'Thanh toán',
    'Trạng thái',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        return SizedBox(
          height: IceBotSpacing.stepRailHeight,
          child: Row(
            children: [
              for (int i = 0; i < _labels.length; i++) ...[
                Expanded(
                  flex: 4,
                  child: _StepNode(
                    label: _labels[i],
                    index: i,
                    currentStep: currentStep,
                    isError: isError,
                    isCompact: isCompact,
                  ),
                ),
                if (i < _labels.length - 1)
                  Expanded(
                    child: _Connector(index: i, currentStep: currentStep),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Step node ────────────────────────────────────────────────────────────────

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.label,
    required this.index,
    required this.currentStep,
    required this.isError,
    required this.isCompact,
  });

  final String label;
  final int index;
  final int currentStep;
  final bool isError;
  final bool isCompact;

  bool get _isCompleted => index < currentStep;
  bool get _isActive => index == currentStep;
  bool get _isFuture => index > currentStep;

  Color _nodeColor(ColorScheme scheme) {
    if (_isActive && isError) return IceBotColors.dangerRed;
    if (_isActive) return IceBotColors.icePrimary;
    if (_isCompleted) return IceBotColors.mintSuccess;
    return IceBotColors.frostBorder;
  }

  Color _labelColor(ColorScheme scheme) {
    if (_isActive && isError) return IceBotColors.dangerRed;
    if (_isActive) return IceBotColors.icePrimary;
    if (_isCompleted) return IceBotColors.mintSuccess;
    return IceBotColors.botNavyMuted;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nodeColor = _nodeColor(scheme);
    final labelColor = _labelColor(scheme);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NodeCircle(
          isActive: _isActive,
          isCompleted: _isCompleted,
          isFuture: _isFuture,
          isError: isError,
          color: nodeColor,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: labelColor,
            fontWeight: _isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: isCompact ? 10 : null,
          ),
        ),
      ],
    );
  }
}

// ─── Animated node circle ─────────────────────────────────────────────────────

class _NodeCircle extends StatefulWidget {
  const _NodeCircle({
    required this.isActive,
    required this.isCompleted,
    required this.isFuture,
    required this.isError,
    required this.color,
  });

  final bool isActive;
  final bool isCompleted;
  final bool isFuture;
  final bool isError;
  final Color color;

  @override
  State<_NodeCircle> createState() => _NodeCircleState();
}

class _NodeCircleState extends State<_NodeCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _glow = Tween<double>(
      begin: 1.0,
      end: 1.35,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_NodeCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const nodeSize = IceBotSpacing.stepNodeSize;
    final color = widget.color;
    final disableAnim = MediaQuery.of(context).disableAnimations;

    if (widget.isCompleted) {
      // Solid filled circle with checkmark icon
      return Container(
        width: nodeSize,
        height: nodeSize,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      );
    }

    if (widget.isFuture) {
      // Outlined empty circle
      return Container(
        width: nodeSize,
        height: nodeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(color: color, width: 1.5),
        ),
      );
    }

    // Active node — glowing bot-eye
    if (disableAnim) {
      return _ActiveNodeStatic(nodeSize: nodeSize, color: color);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: nodeSize,
          height: nodeSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Opacity(
                opacity: (1.0 - _controller.value) * 0.3,
                child: Transform.scale(
                  scale: _glow.value,
                  child: Container(
                    width: nodeSize,
                    height: nodeSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),
              // Filled core
              Container(
                width: nodeSize,
                height: nodeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              // "Bot eye" pupil
              Container(
                width: IceBotSpacing.stepEyeSize,
                height: IceBotSpacing.stepEyeSize,
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

class _ActiveNodeStatic extends StatelessWidget {
  const _ActiveNodeStatic({required this.nodeSize, required this.color});

  final double nodeSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: nodeSize,
      height: nodeSize,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Center(
        child: Container(
          width: IceBotSpacing.stepEyeSize,
          height: IceBotSpacing.stepEyeSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─── Connector line ───────────────────────────────────────────────────────────

class _Connector extends StatelessWidget {
  const _Connector({required this.index, required this.currentStep});

  final int index;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final completed = index < currentStep;
    return Padding(
      // Align the line with the circle centres (not the label row)
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          color: completed
              ? IceBotColors.mintSuccess
              : IceBotColors.frostBorder,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
