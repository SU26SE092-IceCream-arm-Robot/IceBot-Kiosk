import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_registration_store.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_session_manager.dart';
import 'package:icebot_kiosk/features/setup/data/local/auth_session_store.dart';
import 'package:icebot_kiosk/features/setup/data/repositories/auth_repository.dart';
import 'package:icebot_kiosk/features/setup/presentation/screens/manager_login_screen.dart';
import 'package:icebot_kiosk/features/setup/presentation/state/auth_controller.dart';
import 'package:icebot_kiosk/features/setup/presentation/state/auth_scope.dart';

void main() {
  testWidgets(
    'does not use form controllers after successful login disposes screen',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      const secureStorage = FlutterSecureStorage();
      final registrationStore = ClientDeviceRegistrationStore(secureStorage);
      final controller = _PendingLoginAuthController(
        repository: AuthRepository(DioClient(baseUrl: 'https://api.test')),
        legacySessionStore: MemoryAuthSessionStore(),
        registrationStore: registrationStore,
        sessionManager: ClientDeviceSessionManager(Dio(), registrationStore),
      );
      addTearDown(controller.dispose);

      var showLogin = true;
      late StateSetter setHostState;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return AuthScope(
                controller: controller,
                child: showLogin
                    ? const ManagerLoginScreen()
                    : const SizedBox.shrink(),
              );
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'manager');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      await tester.ensureVisible(find.text('Đăng nhập và thiết lập'));
      await tester.tap(find.text('Đăng nhập và thiết lập'));
      await tester.pump();
      expect(controller.loginCalls, 1);

      setHostState(() => showLogin = false);
      await tester.pump();
      controller.loginResult.complete(true);
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}

class _PendingLoginAuthController extends AuthController {
  _PendingLoginAuthController({
    required super.repository,
    required super.legacySessionStore,
    required super.registrationStore,
    required super.sessionManager,
  });

  final loginResult = Completer<bool>();
  var loginCalls = 0;

  @override
  Future<bool> login({
    required String emailOrUsername,
    required String password,
  }) {
    loginCalls += 1;
    return loginResult.future;
  }
}
