import 'package:flutter/widgets.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_controller.dart';

class KioskScope extends StatefulWidget {
  const KioskScope({
    required this.controller,
    required this.child,
    this.disposeController = true,
    super.key,
  });

  final KioskController controller;
  final Widget child;
  final bool disposeController;

  static KioskController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_KioskInherited>();
    assert(scope != null, 'KioskScope was not found in the widget tree.');
    return scope!.controller;
  }

  static KioskController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_KioskInherited>()
        ?.controller;
  }

  @override
  State<KioskScope> createState() => _KioskScopeState();
}

class _KioskScopeState extends State<KioskScope> {
  @override
  void dispose() {
    if (widget.disposeController) {
      widget.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _KioskInherited(controller: widget.controller, child: widget.child);
  }
}

class _KioskInherited extends InheritedNotifier<KioskController> {
  const _KioskInherited({required this.controller, required super.child})
    : super(notifier: controller);

  final KioskController controller;
}
