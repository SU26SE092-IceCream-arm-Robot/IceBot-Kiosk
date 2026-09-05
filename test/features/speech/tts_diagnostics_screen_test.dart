import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/features/speech/application/kiosk_speech_service.dart';
import 'package:icebot_kiosk/features/speech/presentation/tts_diagnostics_screen.dart';

void main() {
  testWidgets('opens diagnostics directly and allows unrestricted replay', (
    WidgetTester tester,
  ) async {
    final speech = _DiagnosticsSpeechService();
    await tester.pumpWidget(TtsDiagnosticsApp(speechService: speech));
    await tester.pumpAndSettle();

    expect(
      find.text('TTS TEST MODE — KHÔNG DÙNG CHO BÁN HÀNG'),
      findsOneWidget,
    );
    expect(find.text('Thiết lập IceBot Kiosk'), findsNothing);
    expect(find.widgetWithText(TextField, 'ORD-001'), findsOneWidget);

    await tester.tap(find.text('Kiểm tra thanh toán thành công'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phát lại'));
    await tester.pumpAndSettle();

    expect(speech.played, [
      OrderAnnouncementType.paymentSuccess,
      OrderAnnouncementType.paymentSuccess,
    ]);
    expect(speech.forceRegenerateValues, [true, true]);
    expect(find.text('Phát âm thanh thành công.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(speech.disposed, isTrue);
  });
}

class _DiagnosticsSpeechService implements KioskSpeechService {
  final List<OrderAnnouncementType> played = [];
  final List<bool> forceRegenerateValues = [];
  bool disposed = false;

  @override
  SpeechDiagnostics get diagnostics => const SpeechDiagnostics(
    status: SpeechEngineStatus.ready,
    modelDirectory: r'C:\tts\model',
    warmupDuration: Duration(milliseconds: 120),
  );

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<SpeechPlaybackResult> playOrderAnnouncement({
    required String orderId,
    required String orderNumber,
    required OrderAnnouncementType type,
    bool forceRegenerate = false,
  }) async {
    played.add(type);
    forceRegenerateValues.add(forceRegenerate);
    return const SpeechPlaybackResult(
      success: true,
      generationDuration: Duration(milliseconds: 200),
      playbackStartDuration: Duration(milliseconds: 20),
      audioDuration: Duration(seconds: 2),
    );
  }

  @override
  Future<void> prepareOrder({
    required String orderId,
    required String orderNumber,
  }) async {}
}
