import 'package:get_it/get_it.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/demo_kiosk_repositories.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/menu_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/order_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/payment_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GetIt sl = GetIt.instance;

/// Initialize all app dependencies using Service Locator pattern (GetIt).
Future<void> init() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  // Network
  sl.registerLazySingleton<DioClient>(
    () => DioClient(baseUrl: AppConfig.apiBaseUrl),
  );

  // Kiosk runtime/customer API repositories
  if (AppConfig.demoMode) {
    sl.registerLazySingleton<DemoKioskStore>(DemoKioskStore.new);
    sl.registerLazySingleton<MenuRepository>(
      () => DemoMenuRepository(sl<DemoKioskStore>()),
    );
    sl.registerLazySingleton<OrderRepository>(
      () => DemoOrderRepository(sl<DemoKioskStore>()),
    );
    sl.registerLazySingleton<PaymentRepository>(
      () => DemoPaymentRepository(sl<DemoKioskStore>()),
    );
  } else {
    sl.registerLazySingleton<MenuRepository>(
      () => MenuRepository(sl<DioClient>()),
    );
    sl.registerLazySingleton<OrderRepository>(
      () => OrderRepository(sl<DioClient>()),
    );
    sl.registerLazySingleton<PaymentRepository>(
      () => PaymentRepository(sl<DioClient>()),
    );
  }
}
