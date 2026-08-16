import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/status/runtime_menu_availability_presenter.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_error_panel.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';

class KioskSplashScreen extends StatefulWidget {
  const KioskSplashScreen({super.key});

  @override
  State<KioskSplashScreen> createState() => _KioskSplashScreenState();
}

class _KioskSplashScreenState extends State<KioskSplashScreen> {
  bool _requestedLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedLoad || AppConfig.runtimeConfigurationError != null) {
      return;
    }

    _requestedLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initialize();
      }
    });
  }

  Future<void> _initialize() async {
    final controller = KioskScope.of(context);
    final recoveredOrder = await controller.restoreActiveOrder();
    if (!mounted) {
      return;
    }
    if (recoveredOrder != null) {
      context.go(AppRouter.orderPath(recoveredOrder.id));
      return;
    }
    if (controller.recoveryError == null) {
      await controller.loadMenu(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasKioskId) {
      return const _MissingKioskConfigView();
    }

    final configurationError = AppConfig.runtimeConfigurationError;
    if (configurationError != null) {
      return _InvalidKioskConfigView(message: configurationError);
    }

    final controller = KioskScope.of(context);
    final recoveryError = controller.recoveryError;
    if (recoveryError != null) {
      return Scaffold(
        body: KioskBackdrop(
          child: KioskErrorPanel(
            title: 'Không thể khôi phục đơn hàng',
            error: recoveryError,
            actionLabel: recoveryError.type == ApiErrorType.unauthorized
                ? 'Bắt đầu đơn mới'
                : 'Thử lại',
            onAction: _initialize,
          ),
        ),
      );
    }

    final menuError = controller.menuError;
    if (menuError != null) {
      final availability = RuntimeMenuAvailabilityPresenter.fromError(
        menuError,
      );
      return Scaffold(
        body: KioskBackdrop(
          child: KioskErrorPanel(
            title: availability.title,
            error: menuError,
            primaryMessage: availability.message,
            actionLabel: 'Thử lại',
            onAction: () => controller.loadMenu(force: true),
          ),
        ),
      );
    }

    if (controller.hasMenu) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go(AppRouter.menu);
        }
      });
    }

    return const Scaffold(
      body: KioskBackdrop(
        child: KioskLoadingPanel(
          title: 'IceBot Kiosk',
          message: 'Đang chuẩn bị menu hôm nay. Vui lòng chờ trong giây lát.',
        ),
      ),
    );
  }
}

class _InvalidKioskConfigView extends StatelessWidget {
  const _InvalidKioskConfigView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KioskBackdrop(
        child: KioskEmptyState(
          title: 'Cấu hình kiosk không hợp lệ',
          message: message,
          icon: Icons.settings_outlined,
        ),
      ),
    );
  }
}

class _MissingKioskConfigView extends StatelessWidget {
  const _MissingKioskConfigView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: const KioskBackdrop(
        child: KioskEmptyState(
          title: 'Chưa cấu hình kiosk',
          message:
              'Tablet cần mã kiosk hợp lệ để tải đúng menu và nhận đơn hàng.',
          icon: Icons.settings_outlined,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
          child: Text(
            'Biến cấu hình cần có: ICEBOT_KIOSK_ID',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
