enum OrderAnnouncementType { paymentSuccess, completed }

enum SpeechEngineStatus { uninitialized, initializing, ready, unavailable }

class SpeechDiagnostics {
  const SpeechDiagnostics({
    this.status = SpeechEngineStatus.uninitialized,
    this.modelDirectory = '',
    this.warmupDuration,
    this.generationDuration,
    this.playbackStartDuration,
    this.audioDuration,
    this.lastError,
  });

  final SpeechEngineStatus status;
  final String modelDirectory;
  final Duration? warmupDuration;
  final Duration? generationDuration;
  final Duration? playbackStartDuration;
  final Duration? audioDuration;
  final String? lastError;

  SpeechDiagnostics copyWith({
    SpeechEngineStatus? status,
    String? modelDirectory,
    Duration? warmupDuration,
    Duration? generationDuration,
    Duration? playbackStartDuration,
    Duration? audioDuration,
    String? lastError,
    bool clearError = false,
  }) {
    return SpeechDiagnostics(
      status: status ?? this.status,
      modelDirectory: modelDirectory ?? this.modelDirectory,
      warmupDuration: warmupDuration ?? this.warmupDuration,
      generationDuration: generationDuration ?? this.generationDuration,
      playbackStartDuration:
          playbackStartDuration ?? this.playbackStartDuration,
      audioDuration: audioDuration ?? this.audioDuration,
      lastError: clearError ? null : lastError ?? this.lastError,
    );
  }
}

class SpeechPlaybackResult {
  const SpeechPlaybackResult({
    required this.success,
    this.generationDuration,
    this.playbackStartDuration,
    this.audioDuration,
    this.error,
  });

  final bool success;
  final Duration? generationDuration;
  final Duration? playbackStartDuration;
  final Duration? audioDuration;
  final String? error;
}

abstract interface class KioskSpeechService {
  SpeechDiagnostics get diagnostics;

  Future<void> initialize();

  Future<void> prepareOrder({
    required String orderId,
    required String orderNumber,
  });

  Future<SpeechPlaybackResult> playOrderAnnouncement({
    required String orderId,
    required String orderNumber,
    required OrderAnnouncementType type,
    bool forceRegenerate = false,
  });

  Future<void> dispose();
}

class NoopKioskSpeechService implements KioskSpeechService {
  const NoopKioskSpeechService();

  @override
  SpeechDiagnostics get diagnostics => const SpeechDiagnostics(
    status: SpeechEngineStatus.unavailable,
    lastError: 'TTS không khả dụng trong cấu hình hiện tại.',
  );

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<SpeechPlaybackResult> playOrderAnnouncement({
    required String orderId,
    required String orderNumber,
    required OrderAnnouncementType type,
    bool forceRegenerate = false,
  }) async {
    return SpeechPlaybackResult(success: false, error: diagnostics.lastError);
  }

  @override
  Future<void> prepareOrder({
    required String orderId,
    required String orderNumber,
  }) async {}
}
