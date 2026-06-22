import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/state/kiosk_scope.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_error_panel.dart';

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
    if (_requestedLoad || !AppConfig.hasKioskId) {
      return;
    }

    _requestedLoad = true;
    KioskScope.of(context).loadMenu();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasKioskId) {
      return const _MissingKioskConfigView();
    }

    final controller = KioskScope.of(context);
    final menuError = controller.menuError;
    if (menuError != null) {
      return Scaffold(
        body: KioskErrorPanel(
          title: _isUnavailable(menuError)
              ? 'Kiosk đang tạm ngưng'
              : 'Không thể tải kiosk',
          error: menuError,
          actionLabel: 'Thử lại',
          onAction: () => controller.loadMenu(force: true),
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

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 44,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.icecream_outlined,
                        size: 76,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'IceBot Kiosk',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Đang tải menu cho kiosk. Vui lòng chờ trong giây lát.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 280,
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isUnavailable(ApiException error) {
    return error.type == ApiErrorType.notFound ||
        error.type == ApiErrorType.conflict;
  }
}

class _MissingKioskConfigView extends StatelessWidget {
  const _MissingKioskConfigView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.settings_outlined,
                        color: colorScheme.onPrimaryContainer,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Chưa cấu hình kiosk',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Vui lòng khởi chạy app với mã kiosk hợp lệ để tablet '
                      'biết đang phục vụ kiosk nào.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Biến cấu hình cần có: ICEBOT_KIOSK_ID',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.primary,
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
    );
  }
}
