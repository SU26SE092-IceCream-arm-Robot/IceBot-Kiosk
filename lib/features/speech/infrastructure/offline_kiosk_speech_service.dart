import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:icebot_kiosk/features/speech/application/kiosk_speech_service.dart';
import 'package:icebot_kiosk/features/speech/application/order_announcement_text_builder.dart';
import 'package:icebot_kiosk/features/speech/domain/order_number_speech_formatter.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class OfflineKioskSpeechService implements KioskSpeechService {
  OfflineKioskSpeechService({
    required String modelDirectory,
    AudioPlayer? audioPlayer,
    OrderNumberSpeechFormatter formatter = const OrderNumberSpeechFormatter(),
  }) : _modelDirectory = modelDirectory,
       _audioPlayer = audioPlayer ?? AudioPlayer(),
       _textBuilder = OrderAnnouncementTextBuilder(formatter: formatter),
       _diagnostics = SpeechDiagnostics(modelDirectory: modelDirectory);

  static const String modelFileName = 'vi_VN-vais1000-medium.onnx';
  static const String tokensFileName = 'tokens.txt';
  static const String dataDirectoryName = 'espeak-ng-data';

  final String _modelDirectory;
  final AudioPlayer _audioPlayer;
  final OrderAnnouncementTextBuilder _textBuilder;
  final _TtsWorkerClient _worker = _TtsWorkerClient();
  final Map<String, Future<_PreparedAudio>> _prepared = {};

  SpeechDiagnostics _diagnostics;
  Future<void>? _initialization;
  Future<void> _playbackTail = Future<void>.value();
  bool _disposed = false;

  @override
  SpeechDiagnostics get diagnostics => _diagnostics;

  @override
  Future<void> initialize() {
    if (_disposed) {
      return Future<void>.value();
    }
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    _diagnostics = _diagnostics.copyWith(
      status: SpeechEngineStatus.initializing,
      clearError: true,
    );
    final stopwatch = Stopwatch()..start();
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        _validateModelFiles();
        await _worker.start(_modelDirectory);
        stopwatch.stop();
        _diagnostics = _diagnostics.copyWith(
          status: SpeechEngineStatus.ready,
          warmupDuration: stopwatch.elapsed,
          clearError: true,
        );
        return;
      } on Object catch (error) {
        lastError = error;
        await _worker.dispose();
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
    }

    stopwatch.stop();
    _diagnostics = _diagnostics.copyWith(
      status: SpeechEngineStatus.unavailable,
      warmupDuration: stopwatch.elapsed,
      lastError: _safeError(lastError ?? 'Không thể khởi tạo TTS.'),
    );
    developer.log(
      'TTS initialization failed after one retry.',
      name: 'icebot.tts',
      error: lastError,
    );
  }

  void _validateModelFiles() {
    final directory = Directory(_modelDirectory);
    final requiredPaths = [
      _path(modelFileName),
      _path(tokensFileName),
      _path(dataDirectoryName),
    ];
    if (!directory.existsSync() ||
        !File(requiredPaths[0]).existsSync() ||
        !File(requiredPaths[1]).existsSync() ||
        !Directory(requiredPaths[2]).existsSync()) {
      throw StateError('Không tìm thấy đầy đủ model TTS tại $_modelDirectory.');
    }
  }

  @override
  Future<void> prepareOrder({
    required String orderId,
    required String orderNumber,
  }) async {
    await initialize();
    if (_diagnostics.status != SpeechEngineStatus.ready) {
      return;
    }

    await Future.wait([
      _audioFor(orderId, orderNumber, OrderAnnouncementType.paymentSuccess),
      _audioFor(orderId, orderNumber, OrderAnnouncementType.completed),
    ]);
    _trimCache(orderId);
  }

  @override
  Future<SpeechPlaybackResult> playOrderAnnouncement({
    required String orderId,
    required String orderNumber,
    required OrderAnnouncementType type,
    bool forceRegenerate = false,
  }) async {
    await initialize();
    if (_diagnostics.status != SpeechEngineStatus.ready) {
      return SpeechPlaybackResult(
        success: false,
        error: _diagnostics.lastError ?? 'TTS chưa sẵn sàng.',
      );
    }

    final key = _cacheKey(orderId, orderNumber, type);
    if (forceRegenerate) {
      _prepared.remove(key);
    }

    try {
      final audio = await _audioFor(orderId, orderNumber, type);
      final completer = Completer<SpeechPlaybackResult>();
      _playbackTail = _playbackTail
          .then((_) async {
            final result = await _playWithRetry(audio);
            if (!completer.isCompleted) {
              completer.complete(result);
            }
          })
          .catchError((Object error) {
            if (!completer.isCompleted) {
              completer.complete(
                SpeechPlaybackResult(success: false, error: _safeError(error)),
              );
            }
          });
      return completer.future;
    } on Object catch (error) {
      final message = _safeError(error);
      _diagnostics = _diagnostics.copyWith(lastError: message);
      developer.log(
        'TTS generation failed after one retry.',
        name: 'icebot.tts',
        error: error,
      );
      return SpeechPlaybackResult(success: false, error: message);
    }
  }

  Future<SpeechPlaybackResult> _playWithRetry(_PreparedAudio audio) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      final stopwatch = Stopwatch()..start();
      try {
        await _audioPlayer.stop();
        final completed = _audioPlayer.onPlayerComplete.first;
        await _audioPlayer.play(
          BytesSource(audio.wavBytes, mimeType: 'audio/wav'),
        );
        stopwatch.stop();
        final playbackStart = stopwatch.elapsed;
        _diagnostics = _diagnostics.copyWith(
          generationDuration: audio.generationDuration,
          playbackStartDuration: playbackStart,
          audioDuration: audio.audioDuration,
          clearError: true,
        );
        await completed.timeout(
          audio.audioDuration + const Duration(seconds: 5),
        );
        return SpeechPlaybackResult(
          success: true,
          generationDuration: audio.generationDuration,
          playbackStartDuration: playbackStart,
          audioDuration: audio.audioDuration,
        );
      } on Object catch (error) {
        stopwatch.stop();
        lastError = error;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
    }

    final message = _safeError(lastError ?? 'Không thể phát âm thanh.');
    _diagnostics = _diagnostics.copyWith(lastError: message);
    developer.log(
      'TTS playback failed after one retry.',
      name: 'icebot.tts',
      error: lastError,
    );
    return SpeechPlaybackResult(
      success: false,
      generationDuration: audio.generationDuration,
      audioDuration: audio.audioDuration,
      error: message,
    );
  }

  Future<_PreparedAudio> _audioFor(
    String orderId,
    String orderNumber,
    OrderAnnouncementType type,
  ) {
    final key = _cacheKey(orderId, orderNumber, type);
    return _prepared.putIfAbsent(key, () async {
      try {
        final generated = await _generateWithRetry(
          _textBuilder.build(orderNumber, type),
        );
        final audio = _PreparedAudio(
          wavBytes: generated.wavBytes,
          generationDuration: generated.generationDuration,
          audioDuration: generated.audioDuration,
        );
        _diagnostics = _diagnostics.copyWith(
          generationDuration: audio.generationDuration,
          audioDuration: audio.audioDuration,
          clearError: true,
        );
        return audio;
      } on Object {
        _prepared.remove(key);
        rethrow;
      }
    });
  }

  Future<_GeneratedAudio> _generateWithRetry(String text) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _worker.generate(text);
      } on Object catch (error) {
        lastError = error;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
    }
    throw lastError ?? StateError('Không thể sinh âm thanh TTS.');
  }

  void _trimCache(String currentOrderId) {
    if (_prepared.length <= 4) {
      return;
    }
    _prepared.removeWhere((key, _) => !key.startsWith('$currentOrderId|'));
  }

  String _cacheKey(
    String orderId,
    String orderNumber,
    OrderAnnouncementType type,
  ) => '$orderId|${type.name}|$orderNumber';

  String _path(String name) => '$_modelDirectory${Platform.pathSeparator}$name';

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _audioPlayer.dispose();
    await _worker.dispose();
    _prepared.clear();
  }
}

class _PreparedAudio {
  const _PreparedAudio({
    required this.wavBytes,
    required this.generationDuration,
    required this.audioDuration,
  });

  final Uint8List wavBytes;
  final Duration generationDuration;
  final Duration audioDuration;
}

class _GeneratedAudio {
  const _GeneratedAudio({
    required this.wavBytes,
    required this.generationDuration,
    required this.audioDuration,
  });

  final Uint8List wavBytes;
  final Duration generationDuration;
  final Duration audioDuration;
}

class _TtsWorkerClient {
  final Map<int, Completer<_GeneratedAudio>> _pending = {};
  ReceivePort? _receivePort;
  StreamSubscription<Object?>? _subscription;
  Isolate? _isolate;
  SendPort? _commandPort;
  int _nextRequestId = 1;

  Future<void> start(String modelDirectory) async {
    if (_commandPort != null) {
      return;
    }

    final ready = Completer<void>();
    final receivePort = ReceivePort();
    _receivePort = receivePort;
    _subscription = receivePort.listen((message) {
      if (message is! Map<Object?, Object?>) {
        return;
      }
      switch (message['type']) {
        case 'ready':
          _commandPort = message['port'] as SendPort;
          if (!ready.isCompleted) {
            ready.complete();
          }
        case 'initError':
          if (!ready.isCompleted) {
            ready.completeError(StateError(message['error'] as String));
          }
        case 'result':
          final id = message['id'] as int;
          final completer = _pending.remove(id);
          final bytes = (message['bytes'] as TransferableTypedData)
              .materialize()
              .asUint8List();
          completer?.complete(
            _GeneratedAudio(
              wavBytes: bytes,
              generationDuration: Duration(
                microseconds: message['generationMicros'] as int,
              ),
              audioDuration: Duration(
                microseconds: message['audioMicros'] as int,
              ),
            ),
          );
        case 'error':
          final id = message['id'] as int;
          _pending
              .remove(id)
              ?.completeError(StateError(message['error'] as String));
      }
    });

    _isolate = await Isolate.spawn<Map<String, Object>>(_ttsWorkerMain, {
      'replyPort': receivePort.sendPort,
      'modelDirectory': modelDirectory,
    }, debugName: 'icebot-tts-worker');
    await ready.future.timeout(const Duration(seconds: 30));
  }

  Future<_GeneratedAudio> generate(String text) {
    final port = _commandPort;
    if (port == null) {
      throw StateError('TTS worker chưa sẵn sàng.');
    }
    final id = _nextRequestId++;
    final completer = Completer<_GeneratedAudio>();
    _pending[id] = completer;
    port.send({'type': 'generate', 'id': id, 'text': text});
    return completer.future.timeout(const Duration(seconds: 30));
  }

  Future<void> dispose() async {
    _commandPort?.send({'type': 'dispose'});
    _commandPort = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('TTS worker đã dừng.'));
      }
    }
    _pending.clear();
    await _subscription?.cancel();
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }
}

void _ttsWorkerMain(Map<String, Object> bootstrap) {
  final replyPort = bootstrap['replyPort']! as SendPort;
  final modelDirectory = bootstrap['modelDirectory']! as String;
  sherpa_onnx.OfflineTts? tts;
  final commandPort = ReceivePort();
  try {
    sherpa_onnx.initBindings();
    tts = sherpa_onnx.OfflineTts(
      sherpa_onnx.OfflineTtsConfig(
        model: sherpa_onnx.OfflineTtsModelConfig(
          vits: sherpa_onnx.OfflineTtsVitsModelConfig(
            model:
                '$modelDirectory${Platform.pathSeparator}${OfflineKioskSpeechService.modelFileName}',
            tokens:
                '$modelDirectory${Platform.pathSeparator}${OfflineKioskSpeechService.tokensFileName}',
            dataDir:
                '$modelDirectory${Platform.pathSeparator}${OfflineKioskSpeechService.dataDirectoryName}',
          ),
          numThreads: 1,
          debug: false,
          provider: 'cpu',
        ),
        maxNumSenetences: 1,
        silenceScale: 0.2,
      ),
    );
    replyPort.send({'type': 'ready', 'port': commandPort.sendPort});
  } on Object catch (error) {
    commandPort.close();
    replyPort.send({'type': 'initError', 'error': _safeError(error)});
    return;
  }

  commandPort.listen((message) {
    if (message is! Map<Object?, Object?>) {
      return;
    }
    if (message['type'] == 'dispose') {
      tts?.free();
      commandPort.close();
      return;
    }
    if (message['type'] != 'generate') {
      return;
    }

    final id = message['id']! as int;
    final text = message['text']! as String;
    final stopwatch = Stopwatch()..start();
    try {
      final generated = tts!.generateWithConfig(
        text: text,
        config: const sherpa_onnx.OfflineTtsGenerationConfig(
          sid: 0,
          speed: 1.0,
          silenceScale: 0.2,
        ),
      );
      stopwatch.stop();
      if (generated.samples.isEmpty || generated.sampleRate <= 0) {
        throw StateError('TTS không sinh được dữ liệu âm thanh.');
      }
      final wav = _encodePcm16Wav(generated.samples, generated.sampleRate);
      replyPort.send({
        'type': 'result',
        'id': id,
        'bytes': TransferableTypedData.fromList([wav]),
        'generationMicros': stopwatch.elapsedMicroseconds,
        'audioMicros':
            (generated.samples.length * Duration.microsecondsPerSecond) ~/
            generated.sampleRate,
      });
    } on Object catch (error) {
      stopwatch.stop();
      replyPort.send({'type': 'error', 'id': id, 'error': _safeError(error)});
    }
  });
}

Uint8List _encodePcm16Wav(Float32List samples, int sampleRate) {
  const headerSize = 44;
  const bytesPerSample = 2;
  final dataSize = samples.length * bytesPerSample;
  final bytes = Uint8List(headerSize + dataSize);
  final data = ByteData.sublistView(bytes);

  void writeAscii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeAscii(0, 'RIFF');
  data.setUint32(4, 36 + dataSize, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * bytesPerSample, Endian.little);
  data.setUint16(32, bytesPerSample, Endian.little);
  data.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  data.setUint32(40, dataSize, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    final sample = math.max(-1.0, math.min(1.0, samples[i]));
    final pcm = sample < 0
        ? (sample * 32768).round()
        : (sample * 32767).round();
    data.setInt16(headerSize + i * bytesPerSample, pcm, Endian.little);
  }
  return bytes;
}

String _safeError(Object error) {
  final message = error.toString().replaceFirst(
    RegExp(r'^\w+(?:<.*>)?:\s*'),
    '',
  );
  return message.length <= 240 ? message : '${message.substring(0, 237)}...';
}
