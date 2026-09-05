import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/features/speech/application/kiosk_speech_service.dart';
import 'package:icebot_kiosk/features/speech/infrastructure/offline_kiosk_speech_service.dart';
import 'package:icebot_kiosk/features/speech/presentation/tts_diagnostics_screen.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('generates and plays Vietnamese speech with the bundled engine', (
    WidgetTester tester,
  ) async {
    expect(AppConfig.ttsTestMode, isTrue);
    expect(AppConfig.ttsModelDirectory, isNotEmpty);

    final initialRss = ProcessInfo.currentRss;
    final speech = OfflineKioskSpeechService(
      modelDirectory: AppConfig.ttsModelDirectory,
    );
    await tester.pumpWidget(TtsDiagnosticsApp(speechService: speech));

    await _pumpUntil(
      tester,
      () => find
          .text('TTS đã sẵn sàng. Chọn một thông báo để phát thử.')
          .evaluate()
          .isNotEmpty,
      timeout: const Duration(seconds: 45),
    );

    await tester.tap(find.text('Kiểm tra thanh toán thành công'));
    await _pumpUntil(
      tester,
      () => find.text('Phát âm thanh thành công.').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 60),
    );

    expect(find.text('Phát âm thanh thành công.'), findsOneWidget);

    await speech.prepareOrder(
      orderId: 'performance-order',
      orderNumber: 'ORD-001',
    );
    final preparedResult = await speech.playOrderAnnouncement(
      orderId: 'performance-order',
      orderNumber: 'ORD-001',
      type: OrderAnnouncementType.completed,
    );

    expect(preparedResult.success, isTrue);
    expect(preparedResult.playbackStartDuration, isNotNull);
    expect(
      preparedResult.playbackStartDuration!.inMilliseconds,
      lessThanOrEqualTo(500),
    );
    expect(preparedResult.audioDuration, isNotNull);
    expect(preparedResult.audioDuration, greaterThan(Duration.zero));
    expect(
      ProcessInfo.currentRss - initialRss,
      lessThanOrEqualTo(250 * 1024 * 1024),
    );
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > timeout) {
      fail('Timed out after ${timeout.inSeconds} seconds.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}
