import 'package:flutter_test/flutter_test.dart';
import 'package:icebot_kiosk/features/speech/domain/order_number_speech_formatter.dart';

void main() {
  const formatter = OrderNumberSpeechFormatter();

  test('reads the trailing numeric suffix and preserves leading zeroes', () {
    expect(formatter.format('ORD-001'), 'không, không, một');
  });

  test('reads every letter and number when there is no numeric suffix', () {
    expect(formatter.format('K9A'), 'ca, chín, a');
  });

  test('ignores separators in an alphanumeric fallback code', () {
    expect(formatter.format(' ab-c '), 'a, bê, xê');
  });

  test('returns an empty phrase for an empty order number', () {
    expect(formatter.format('   '), isEmpty);
  });
}
