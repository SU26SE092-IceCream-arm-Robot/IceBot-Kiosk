import 'package:flutter/material.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/config/themes/app_theme.dart';
import 'package:icebot_kiosk/core/di/injection_container.dart' as di;
import 'package:icebot_kiosk/features/kiosk/data/local/order_recovery_store.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/menu_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/order_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/payment_repository.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_session_manager.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_controller.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.kioskController});

  final KioskController? kioskController;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp.router(
      title: 'IceBot Kiosk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        if (!AppConfig.demoMode) {
          return child ?? const SizedBox.shrink();
        }

        return _DemoModeFrame(child: child ?? const SizedBox.shrink());
      },
    );

    return KioskScope(
      controller: kioskController ?? _buildKioskController(),
      disposeController: kioskController == null,
      child: app,
    );
  }

  KioskController _buildKioskController() {
    return KioskController(
      menuRepository: di.sl<MenuRepository>(),
      orderRepository: di.sl<OrderRepository>(),
      paymentRepository: di.sl<PaymentRepository>(),
      orderRecoveryStore: di.sl<OrderRecoveryStore>(),
      clientDeviceSession: AppConfig.demoMode
          ? null
          : di.sl<ClientDeviceSessionManager>(),
      kioskId: AppConfig.demoMode ? AppConfig.demoKioskId : null,
    );
  }
}

class _DemoModeFrame extends StatelessWidget {
  const _DemoModeFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          right: 18,
          bottom: 18,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFB45309),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Chế độ demo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
