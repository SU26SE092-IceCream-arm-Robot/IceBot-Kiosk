class KioskFormatters {
  KioskFormatters._();

  static String money(double value, {String currency = 'VND'}) {
    final rounded = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < rounded.length; i++) {
      final position = rounded.length - i;
      buffer.write(rounded[i]);
      if (position > 1 && position % 3 == 1) {
        buffer.write('.');
      }
    }

    return '${buffer.toString()} $currency';
  }

  static String durationSeconds(int? seconds) {
    if (seconds == null || seconds <= 0) {
      return 'Thời gian chuẩn bị đang cập nhật';
    }
    if (seconds < 60) {
      return '$seconds giây';
    }

    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return '$minutes phút';
    }

    return '$minutes phút $remainingSeconds giây';
  }

  static String shortDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Không có hạn';
    }

    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$hour:$minute $day/$month/${local.year}';
  }
}
