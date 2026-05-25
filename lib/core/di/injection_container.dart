import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';

final GetIt sl = GetIt.instance;

/// Initialize all app dependencies using Service Locator pattern (GetIt) for Kiosk.
Future<void> init() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  // Network
  sl.registerLazySingleton<DioClient>(
    () => DioClient(baseUrl: 'https://api.icebot.com/'), // Replace with actual base API URL
  );

  // Features - Register features dependencies here
}
