import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/config/themes/app_theme.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/payment_qr_panel.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  const qrPayload =
      '00020101021238570010A00000072701270006970422011312345678901230208QRIBFTTA53037045405100005802VN';

  PaymentSessionResult session({
    String? payload = qrPayload,
    String? checkoutUrl = 'https://pay.payos.vn/web/test',
  }) {
    return PaymentSessionResult(
      paymentTransactionId: 'payment-1',
      orderId: 'order-1',
      transactionNumber: 'PAY-001',
      provider: 'PayOS',
      checkoutUrl: checkoutUrl,
      qrCodePayload: payload,
      amount: 10000,
      currency: 'VND',
      status: PaymentTransactionStatus.pending,
    );
  }

  Future<void> pumpPanel(
    WidgetTester tester,
    PaymentSessionResult paymentSession, {
    Size size = const Size(1080, 1920),
    bool isExpired = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PaymentQrPanel(
              session: paymentSession,
              isExpired: isExpired,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders a scannable QR without exposing the raw payload', (
    tester,
  ) async {
    await pumpPanel(tester, session());

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(qrPayload), findsNothing);
    expect(find.text('Sao chép mã'), findsOneWidget);
    expect(find.text('Mở trang thanh toán'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the fallback state when the QR payload is empty', (
    tester,
  ) async {
    await pumpPanel(tester, session(payload: ''));

    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('Chưa có nội dung QR'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('open-checkout-button')),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the QR panel usable on a compact layout', (tester) async {
    await pumpPanel(tester, session(), size: const Size(600, 960));

    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides expired payment access and requires a new code', (
    tester,
  ) async {
    await pumpPanel(tester, session(), isExpired: true);

    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('Mã thanh toán đã hết hạn'), findsOneWidget);
    expect(
      tester
          .widget<ButtonStyleButton>(
            find.byKey(const ValueKey('copy-payment-code-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ButtonStyleButton>(
            find.byKey(const ValueKey('open-checkout-button')),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
