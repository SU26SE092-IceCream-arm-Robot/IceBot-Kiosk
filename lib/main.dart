import 'dart:async';

import 'package:flutter/material.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/config/themes/app_theme.dart';
import 'package:icebot_kiosk/core/di/injection_container.dart' as di;
import 'package:icebot_kiosk/features/kiosk/data/local/order_recovery_store.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/menu_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/order_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/payment_repository.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_controller.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';
import 'package:icebot_kiosk/features/speech/application/kiosk_speech_service.dart';
import 'package:icebot_kiosk/features/speech/application/order_announcement_coordinator.dart';
import 'package:icebot_kiosk/features/speech/presentation/tts_diagnostics_screen.dart';
import 'package:icebot_kiosk/features/setup/presentation/screens/manager_login_screen.dart';
import 'package:icebot_kiosk/features/setup/presentation/state/auth_controller.dart';
import 'package:icebot_kiosk/features/setup/presentation/state/auth_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configurationError = AppConfig.runtimeConfigurationError;
  if (configurationError != null) {
    runApp(_ConfigurationErrorApp(message: configurationError));
    return;
  }

  if (AppConfig.ttsTestMode) {
    await di.initTtsOnly();
    runApp(TtsDiagnosticsApp(speechService: di.sl<KioskSpeechService>()));
    return;
  }

  await di.init();
  final authController = di.sl<AuthController>();
  await authController.restore();

  runApp(MyApp(authController: authController));
  unawaited(di.sl<KioskSpeechService>().initialize());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.kioskController, this.authController});

  final KioskController? kioskController;
  final AuthController? authController;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AuthController? _authController;
  KioskController? _ownedKioskController;
  String? _ownedKioskId;

  @override
  void initState() {
    super.initState();
    _attachAuthController();
  }

  @override
  void didUpdateWidget(MyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authController != widget.authController) {
      _detachAuthController();
      _attachAuthController();
    }
  }

  void _attachAuthController() {
    _authController =
        widget.authController ??
        (di.sl.isRegistered<AuthController>() ? di.sl<AuthController>() : null);
    _authController?.addListener(_handleAuthChanged);
  }

  void _detachAuthController() {
    _authController?.removeListener(_handleAuthChanged);
    _authController = null;
  }

  void _handleAuthChanged() {
    if (!mounted) {
      return;
    }
    if (_authController?.isAuthenticated != true) {
      _disposeOwnedKioskController();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _detachAuthController();
    _disposeOwnedKioskController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppConfig.demoMode || widget.kioskController != null) {
      final kioskController =
          widget.kioskController ?? _controllerFor(AppConfig.demoKioskId);
      return KioskScope(
        controller: kioskController,
        disposeController: false,
        child: _buildRouterApp(),
      );
    }

    final authController = _authController;
    if (authController == null) {
      return _buildStaticApp(
        const KioskEmptyState(
          title: 'Thiết lập IceBot Kiosk',
          message: 'Ứng dụng cần được khởi động qua cấu hình hệ thống.',
          icon: Icons.settings_outlined,
        ),
      );
    }

    if (authController.isRestoring) {
      return AuthScope(
        controller: authController,
        child: _buildStaticApp(
          const KioskLoadingPanel(
            title: 'IceBot Kiosk',
            message: 'Đang khôi phục cấu hình điểm bán.',
          ),
        ),
      );
    }

    if (!authController.isAuthenticated) {
      return AuthScope(
        controller: authController,
        child: _buildStaticApp(const ManagerLoginScreen()),
      );
    }

    final kioskController = _controllerFor(authController.session!.kioskId);
    return AuthScope(
      controller: authController,
      child: KioskScope(
        controller: kioskController,
        disposeController: false,
        child: _buildRouterApp(),
      ),
    );
  }

  Widget _buildRouterApp() {
    return MaterialApp.router(
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
  }

  Widget _buildStaticApp(Widget child) {
    return MaterialApp(
      title: 'IceBot Kiosk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: Scaffold(body: KioskBackdrop(child: child)),
    );
  }

  KioskController _controllerFor(String kioskId) {
    if (_ownedKioskController != null && _ownedKioskId == kioskId) {
      return _ownedKioskController!;
    }
    _disposeOwnedKioskController();
    _ownedKioskId = kioskId;
    return _ownedKioskController = KioskController(
      menuRepository: di.sl<MenuRepository>(),
      orderRepository: di.sl<OrderRepository>(),
      paymentRepository: di.sl<PaymentRepository>(),
      orderRecoveryStore: di.sl<OrderRecoveryStore>(),
      announcementCoordinator: di.sl<OrderAnnouncementCoordinator>(),
      kioskId: kioskId,
    );
  }

  void _disposeOwnedKioskController() {
    _ownedKioskController?.dispose();
    _ownedKioskController = null;
    _ownedKioskId = null;
  }
}

class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
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
