import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/main.dart';

void main() {
  testWidgets('app builds and shows missing kiosk config state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Chưa cấu hình kiosk'), findsOneWidget);
    expect(find.textContaining('ICEBOT_KIOSK_ID'), findsOneWidget);
  });
}
