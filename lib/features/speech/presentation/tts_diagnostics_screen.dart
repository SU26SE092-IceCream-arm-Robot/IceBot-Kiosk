import 'dart:async';

import 'package:flutter/material.dart';
import 'package:icebot_kiosk/config/themes/app_theme.dart';
import 'package:icebot_kiosk/features/speech/application/kiosk_speech_service.dart';

class TtsDiagnosticsApp extends StatelessWidget {
  const TtsDiagnosticsApp({required this.speechService, super.key});

  final KioskSpeechService speechService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IceBot TTS Diagnostics',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: TtsDiagnosticsScreen(speechService: speechService),
    );
  }
}

class TtsDiagnosticsScreen extends StatefulWidget {
  const TtsDiagnosticsScreen({required this.speechService, super.key});

  final KioskSpeechService speechService;

  @override
  State<TtsDiagnosticsScreen> createState() => _TtsDiagnosticsScreenState();
}

class _TtsDiagnosticsScreenState extends State<TtsDiagnosticsScreen> {
  final TextEditingController _orderNumberController = TextEditingController(
    text: 'ORD-001',
  );
  bool _busy = false;
  String _activity = 'Đang khởi tạo TTS...';
  SpeechPlaybackResult? _lastResult;
  OrderAnnouncementType? _lastType;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await widget.speechService.initialize();
    if (!mounted) {
      return;
    }
    final ready =
        widget.speechService.diagnostics.status == SpeechEngineStatus.ready;
    setState(() {
      _activity = ready
          ? 'TTS đã sẵn sàng. Chọn một thông báo để phát thử.'
          : 'Không thể khởi tạo TTS.';
    });
  }

  Future<void> _play(OrderAnnouncementType type) async {
    if (_busy) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _activity = 'Đang sinh và phát thông báo...';
      _lastType = type;
    });
    final result = await widget.speechService.playOrderAnnouncement(
      orderId: 'tts-diagnostics',
      orderNumber: _orderNumberController.text,
      type: type,
      forceRegenerate: true,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _lastResult = result;
      _activity = result.success
          ? 'Phát âm thanh thành công.'
          : 'Phát âm thanh thất bại: ${result.error ?? 'Không rõ lỗi'}';
    });
  }

  Future<void> _playBoth() async {
    if (_busy) {
      return;
    }
    await _play(OrderAnnouncementType.paymentSuccess);
    if (mounted && _lastResult?.success == true) {
      await _play(OrderAnnouncementType.completed);
    }
  }

  @override
  void dispose() {
    _orderNumberController.dispose();
    unawaited(widget.speechService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diagnostics = widget.speechService.diagnostics;
    final ready = diagnostics.status == SpeechEngineStatus.ready;
    return Scaffold(
      appBar: AppBar(title: const Text('Kiểm tra TTS cục bộ')),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFFB91C1C),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: const Text(
                'TTS TEST MODE — KHÔNG DÙNG CHO BÁN HÀNG',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(32),
                children: [
                  TextField(
                    controller: _orderNumberController,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Mã đơn hàng',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      FilledButton.icon(
                        onPressed: ready && !_busy
                            ? () => _play(OrderAnnouncementType.paymentSuccess)
                            : null,
                        icon: const Icon(Icons.payment_rounded),
                        label: const Text('Kiểm tra thanh toán thành công'),
                      ),
                      FilledButton.icon(
                        onPressed: ready && !_busy
                            ? () => _play(OrderAnnouncementType.completed)
                            : null,
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('Kiểm tra đơn đã hoàn thành'),
                      ),
                      OutlinedButton.icon(
                        onPressed: ready && !_busy ? _playBoth : null,
                        icon: const Icon(Icons.playlist_play_rounded),
                        label: const Text('Phát thử cả hai'),
                      ),
                      OutlinedButton.icon(
                        onPressed: ready && !_busy && _lastType != null
                            ? () => _play(_lastType!)
                            : null,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Phát lại'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _activity,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 20),
                          _MetricRow(
                            label: 'Trạng thái engine',
                            value: diagnostics.status.name,
                          ),
                          _MetricRow(
                            label: 'Đường dẫn model',
                            value: diagnostics.modelDirectory,
                          ),
                          _MetricRow(
                            label: 'Warm-up',
                            value: _duration(diagnostics.warmupDuration),
                          ),
                          _MetricRow(
                            label: 'Sinh âm thanh',
                            value: _duration(
                              _lastResult?.generationDuration ??
                                  diagnostics.generationDuration,
                            ),
                          ),
                          _MetricRow(
                            label: 'Bắt đầu phát',
                            value: _duration(
                              _lastResult?.playbackStartDuration ??
                                  diagnostics.playbackStartDuration,
                            ),
                          ),
                          _MetricRow(
                            label: 'Độ dài audio',
                            value: _duration(
                              _lastResult?.audioDuration ??
                                  diagnostics.audioDuration,
                            ),
                          ),
                          _MetricRow(
                            label: 'Lỗi gần nhất',
                            value:
                                _lastResult?.error ??
                                diagnostics.lastError ??
                                'Không có',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 24),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _duration(Duration? duration) {
    if (duration == null) {
      return 'Chưa có dữ liệu';
    }
    return '${duration.inMilliseconds} ms';
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
