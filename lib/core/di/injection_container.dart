import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_registration_store.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_session_manager.dart';
import 'package:icebot_kiosk/features/kiosk/data/local/order_recovery_store.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/demo_kiosk_repositories.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/menu_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/order_repository.dart';
import 'package:icebot_kiosk/features/kiosk/data/repositories/payment_repository.dart';
import 'package:icebot_kiosk/features/speech/application/kiosk_speech_service.dart';
import 'package:icebot_kiosk/features/speech/application/order_announcement_coordinator.dart';
import 'package:icebot_kiosk/features/speech/infrastructure/offline_kiosk_speech_service.dart';
import 'package:icebot_kiosk/features/setup/data/local/auth_session_store.dart';
import 'package:icebot_kiosk/features/setup/data/repositories/auth_repository.dart';
import 'package:icebot_kiosk/features/setup/presentation/state/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GetIt sl = GetIt.instance;

/// Initialize all app dependencies using Service Locator pattern (GetIt).
Future<void> init() async {
  _registerSpeechServices();

  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  sl.registerLazySingleton<AuthSessionStore>(
    () => SecureAuthSessionStore(sl<FlutterSecureStorage>()),
  );
  sl.registerLazySingleton<ClientDeviceRegistrationStore>(
    () => ClientDeviceRegistrationStore(sl<FlutterSecureStorage>()),
  );
  sl.registerLazySingleton<OrderAccessTokenStore>(
    () => SecureOrderAccessTokenStore(sl<FlutterSecureStorage>()),
  );
  sl.registerLazySingleton<OrderRecoveryStore>(
    () => AppConfig.demoMode
        ? const NoopOrderRecoveryStore()
        : SharedPreferencesOrderRecoveryStore(
            sl<SharedPreferences>(),
            tokenStore: sl<OrderAccessTokenStore>(),
          ),
  );

  // Network
  sl.registerLazySingleton<Dio>(
    () => Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    ),
  );
  sl.registerLazySingleton<ClientDeviceSessionManager>(
    () => ClientDeviceSessionManager(
      sl<Dio>(),
      sl<ClientDeviceRegistrationStore>(),
    ),
  );
  sl.registerLazySingleton<DioClient>(() {
    final runtimeDio = Dio();
    return DioClient(
      baseUrl: AppConfig.apiBaseUrl,
      dio: runtimeDio,
      interceptors: [
        ClientDeviceAuthInterceptor(
          runtimeDio,
          sl<ClientDeviceSessionManager>(),
        ),
      ],
    );
  });
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepository(DioClient(baseUrl: AppConfig.apiBaseUrl)),
  );
  sl.registerLazySingleton<AuthController>(
    () => AuthController(
      repository: sl<AuthRepository>(),
      legacySessionStore: sl<AuthSessionStore>(),
      registrationStore: sl<ClientDeviceRegistrationStore>(),
      sessionManager: sl<ClientDeviceSessionManager>(),
    ),
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

Future<void> initTtsOnly() async {
  _registerSpeechServices();
}

void _registerSpeechServices() {
  if (!sl.isRegistered<KioskSpeechService>()) {
    sl.registerLazySingleton<KioskSpeechService>(
      () =>
          OfflineKioskSpeechService(modelDirectory: resolveTtsModelDirectory()),
      dispose: (service) => service.dispose(),
    );
  }
  if (!sl.isRegistered<OrderAnnouncementCoordinator>()) {
    sl.registerLazySingleton<OrderAnnouncementCoordinator>(
      () => OrderAnnouncementCoordinator(sl<KioskSpeechService>()),
    );
  }
}

String resolveTtsModelDirectory() {
  final override = AppConfig.ttsModelDirectory.trim();
  if (override.isNotEmpty) {
    return Directory(override).absolute.path;
  }
  final executableDirectory = File(Platform.resolvedExecutable).parent.path;
  return '$executableDirectory${Platform.pathSeparator}tts'
      '${Platform.pathSeparator}vits-piper-vi_VN-vais1000-medium';
}
