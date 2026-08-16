import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/config/themes/icebot_spacing.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentQrPanel extends StatelessWidget {
  const PaymentQrPanel({
    required this.session,
    this.isExpired = false,
    super.key,
  });

  final PaymentSessionResult session;
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    final payload = isExpired ? null : session.qrCodePayload?.trim();
    final checkoutUrl = !isExpired && session.hasUsableCheckoutUrl
        ? session.checkoutUrl!.trim()
        : null;
    final layout = KioskLayoutSpec.of(context);

    return KioskSectionCard(
      padding: EdgeInsets.all(layout.isCompact ? 24 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                color: IceBotColors.botNavy,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Quét mã để thanh toán',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Dùng ứng dụng ngân hàng hoặc ví điện tử để quét mã. Nếu không quét được, hãy mở trang thanh toán.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Container(
            constraints: BoxConstraints(
              minHeight: layout.isCompact ? 280 : 360,
            ),
            padding: EdgeInsets.all(layout.isCompact ? 20 : 28),
            decoration: BoxDecoration(
              color: IceBotColors.frostSurface,
              borderRadius: BorderRadius.circular(IceBotSpacing.cardRadius),
              border: Border.all(color: IceBotColors.frostBorder),
            ),
            child: isExpired
                ? Center(
                    child: Text(
                      'Mã thanh toán đã hết hạn.\nVui lòng tạo mã mới để tiếp tục.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: IceBotColors.warningAmber),
                    ),
                  )
                : payload == null || payload.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có nội dung QR.\nVui lòng mở trang thanh toán nếu có.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: IceBotColors.botNavyMuted),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(layout.isCompact ? 16 : 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: IceBotColors.frostBorder),
                        ),
                        child: QrImageView(
                          data: payload,
                          version: QrVersions.auto,
                          size: layout.isCompact ? 220 : 280,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                          gapless: false,
                          semanticsLabel: 'Mã QR thanh toán PayOS',
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                          errorStateBuilder: (context, error) => SizedBox(
                            width: layout.isCompact ? 220 : 280,
                            height: layout.isCompact ? 220 : 280,
                            child: Center(
                              child: Text(
                                'Không thể tạo mã QR.\nVui lòng mở trang thanh toán.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: IceBotColors.botNavyMuted,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Mã QR do PayOS cung cấp cho phiên thanh toán này.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: IceBotColors.botNavyMuted,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('copy-payment-code-button'),
                  onPressed: payload != null && payload.isNotEmpty
                      ? () => Clipboard.setData(ClipboardData(text: payload))
                      : null,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Sao chép mã'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('open-checkout-button'),
                  onPressed: checkoutUrl != null && payload != null && payload.isNotEmpty
                      ? () => launchUrl(
                            Uri.parse(checkoutUrl),
                            mode: LaunchMode.externalApplication,
                          )
                      : null,
                  icon: const Icon(Icons.open_in_browser_outlined),
                  label: const Text('Mở trang thanh toán'),
                ),
              ),
            ],
          ),
          if (AppConfig.demoMode) ...[
            const SizedBox(height: 16),
            const _DemoQrNotice(),
          ],
        ],
      ),
    );
  }
}

class _DemoQrNotice extends StatelessWidget {
  const _DemoQrNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IceBotColors.warningContainer,
        borderRadius: BorderRadius.circular(IceBotSpacing.cardRadius),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Text(
        'QR demo - không dùng để thanh toán thật.\nMàn hình này chỉ phục vụ hiển thị trên môi trường thử nghiệm.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: IceBotColors.warningAmber,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
