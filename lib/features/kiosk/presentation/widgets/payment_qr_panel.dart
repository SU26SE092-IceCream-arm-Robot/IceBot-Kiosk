import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/config/themes/icebot_colors.dart';
import 'package:icebot_kiosk/config/themes/icebot_spacing.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/payment_models.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentQrPanel extends StatelessWidget {
  const PaymentQrPanel({required this.session, super.key});

  final PaymentSessionResult session;

  @override
  Widget build(BuildContext context) {
    final payload = session.qrCodePayload?.trim();
    final checkoutUrl = session.hasUsableCheckoutUrl ? session.checkoutUrl!.trim() : null;
    final layout = KioskLayoutSpec.of(context);

    return KioskSectionCard(
      padding: EdgeInsets.all(layout.isCompact ? 24 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: IceBotColors.botNavy, size: 32),
              const SizedBox(width: 16),
              Text(
                'Quét mã để thanh toán',
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Dùng ứng dụng ngân hàng hoặc ví điện tử để quét mã. Nếu kiosk không hiển thị ảnh QR, hãy dùng mã thanh toán bên dưới.',
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
            child: payload == null || payload.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có nội dung QR.\nVui lòng mở trang thanh toán nếu có.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: IceBotColors.botNavyMuted,
                          ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.qr_code_2_rounded,
                        size: layout.isCompact ? 96 : 120,
                        color: IceBotColors.botNavy,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Mã thanh toán (Payload)',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: IceBotColors.botNavyMuted,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: IceBotColors.frostBorder),
                        ),
                        child: SelectableText(
                          payload,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: IceBotColors.botNavy,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
          ),
          if (AppConfig.demoMode) ...[
            const SizedBox(height: 16),
            const _DemoQrNotice(),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: payload == null || payload.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: payload));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã sao chép mã thanh toán')),
                            );
                          }
                        },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Sao chép mã'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: checkoutUrl == null || checkoutUrl.isEmpty
                      ? null
                      : () => launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Mở trang thanh toán'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
              ),
            ],
          ),
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
