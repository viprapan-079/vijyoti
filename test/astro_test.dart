import 'package:flutter_test/flutter_test.dart';
import 'package:jyotishya_kundali/astro.dart';

void main() {
  test('Rashi boundaries', () {
    expect(rashi(0), 0);
    expect(rashi(29.999), 0);
    expect(rashi(30), 1);
    expect(rashi(360), 0);
  });
  test('Navamsha start rules', () {
    expect(navamsha(0), 0); // movable Aries starts Aries
    expect(navamsha(30), 9); // fixed Taurus starts Capricorn
    expect(navamsha(60), 4); // dual Gemini starts Leo
    expect(navamsha(29.999), 8);
  });
  test('Vimshottari lord at Ashwini start', () {
    final periods = vimshottari(DateTime.utc(2000, 1, 1), 0);
    expect(periods.first.lord, 'Ketu');
    expect(periods[1].lord, 'Venus');
    expect(periods.first.subPeriods.length, 9);
  });
}
