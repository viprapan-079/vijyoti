import 'dart:math';
import 'package:sweph/sweph.dart';

const rashis = ['Aries','Taurus','Gemini','Cancer','Leo','Virgo','Libra','Scorpio','Sagittarius','Capricorn','Aquarius','Pisces'];
const nakshatras = ['Ashwini','Bharani','Krittika','Rohini','Mrigashira','Ardra','Punarvasu','Pushya','Ashlesha','Magha','Purva Phalguni','Uttara Phalguni','Hasta','Chitra','Swati','Vishakha','Anuradha','Jyeshtha','Mula','Purva Ashadha','Uttara Ashadha','Shravana','Dhanishta','Shatabhisha','Purva Bhadrapada','Uttara Bhadrapada','Revati'];
const dashaLords = ['Ketu','Venus','Sun','Moon','Mars','Rahu','Jupiter','Saturn','Mercury'];
const dashaYears = [7,20,6,10,7,18,16,19,17];
const double nakSpan = 360 / 27;

double norm(double value) => (value % 360 + 360) % 360;
int rashi(double longitude) => (norm(longitude) / 30).floor() % 12;

// D9: each sign divided into nine 3°20' amshas. Movable starts same sign;
// fixed starts ninth; dual starts fifth.
int navamsha(double longitude) {
  final sign = rashi(longitude);
  final part = ((norm(longitude) % 30) / (30 / 9)).floor().clamp(0, 8);
  final start = sign % 3 == 0 ? sign : sign % 3 == 1 ? (sign + 8) % 12 : (sign + 4) % 12;
  return (start + part) % 12;
}

class Placement {
  final String label;
  final double longitude;
  const Placement(this.label, this.longitude);
  int get d1 => rashi(longitude);
  int get d9 => navamsha(longitude);
  String get formatted => '${rashis[d1]} ${(norm(longitude) % 30).toStringAsFixed(2)}°';
}

class Period {
  final String lord;
  final DateTime startUtc;
  final DateTime endUtc;
  final List<Period> subPeriods;
  const Period(this.lord, this.startUtc, this.endUtc, [this.subPeriods = const []]);
}

class Horoscope {
  final List<Placement> planets;
  final int nakshatraIndex;
  final int pada;
  final double ayanamsa;
  final List<Period> periods;
  const Horoscope(this.planets, this.nakshatraIndex, this.pada, this.ayanamsa, this.periods);
}

DateTime _fromMicros(double value) => DateTime.fromMicrosecondsSinceEpoch(value.round(), isUtc: true);
// Uses 365.2425 days per dasha year. Different traditional calendar-year
// conventions can shift boundaries; verify before professional use.
const double microsPerYear = 365.2425 * 86400 * 1000000;

List<Period> _antaraPeriods(DateTime start, DateTime end, int bhuktiLord) {
  final items = <Period>[];
  var now = start.microsecondsSinceEpoch.toDouble();
  final length = end.microsecondsSinceEpoch - start.microsecondsSinceEpoch;
  for (var i = 0; i < 9; i++) {
    final idx = (bhuktiLord + i) % 9;
    final finish = i == 8 ? end.microsecondsSinceEpoch.toDouble()
        : now + length * dashaYears[idx] / 120;
    items.add(Period(dashaLords[idx], _fromMicros(now), _fromMicros(finish)));
    now = finish;
  }
  return items;
}

List<Period> _subPeriods(DateTime start, DateTime end, int parentLord) {
  final result = <Period>[];
  var current = start.microsecondsSinceEpoch.toDouble();
  final span = end.microsecondsSinceEpoch - start.microsecondsSinceEpoch;
  for (var i = 0; i < 9; i++) {
    final idx = (parentLord + i) % 9;
    final next = i == 8 ? end.microsecondsSinceEpoch.toDouble() : current + span * dashaYears[idx] / 120;
    result.add(Period(dashaLords[idx], _fromMicros(current), _fromMicros(next),
      _antaraPeriods(_fromMicros(current), _fromMicros(next), idx)));
    current = next;
  }
  return result;
}

List<Period> vimshottari(DateTime birthUtc, double moonLongitude) {
  final moon = norm(moonLongitude);
  final nak = (moon / nakSpan).floor();
  final firstLord = nak % 9;
  final fractionElapsed = (moon % nakSpan) / nakSpan;
  final birthMicro = birthUtc.microsecondsSinceEpoch.toDouble();
  final firstStart = birthMicro - fractionElapsed * dashaYears[firstLord] * microsPerYear;
  var current = firstStart;
  final result = <Period>[];
  // 10 periods gives the current partial Mahadasha plus one complete 120-year cycle.
  for (var i = 0; i < 10; i++) {
    final idx = (firstLord + i) % 9;
    final end = current + dashaYears[idx] * microsPerYear;
    final startDt = _fromMicros(current);
    final endDt = _fromMicros(end);
    result.add(Period(dashaLords[idx], startDt, endDt, _subPeriods(startDt, endDt, idx)));
    current = end;
  }
  return result;
}

Future<void> initializeEphemeris() async {
  await Sweph.init(epheAssets: const [
    'packages/sweph/assets/ephe/sepl_18.se1',
    'packages/sweph/assets/ephe/semo_18.se1',
  ], epheFilesPath: 'ephe_files');
  Sweph.swe_set_sid_mode(SiderealMode.SE_SIDM_LAHIRI);
}

Horoscope calculateHoroscope({
  required DateTime localBirth,
  required double timezoneHours,
  required double latitude,
  required double longitude,
}) {
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    throw ArgumentError('Invalid latitude or longitude');
  }
  // Local wall-clock input is converted to UTC. DST must already be reflected
  // in timezoneHours. India is normally +5.5 hours.
  final utc = DateTime.utc(localBirth.year, localBirth.month, localBirth.day,
    localBirth.hour, localBirth.minute, localBirth.second).subtract(Duration(minutes: (timezoneHours * 60).round()));
  final jd = Sweph.swe_julday(utc.year, utc.month, utc.day,
    utc.hour + utc.minute / 60 + utc.second / 3600, CalendarType.SE_GREG_CAL);
  const flags = SwephFlag.SEFLG_SWIEPH | SwephFlag.SEFLG_SIDEREAL;
  final bodies = <String, HeavenlyBody>{
    'Sun': HeavenlyBody.SE_SUN,
    'Moon': HeavenlyBody.SE_MOON,
    'Mars': HeavenlyBody.SE_MARS,
    'Mercury': HeavenlyBody.SE_MERCURY,
    'Jupiter': HeavenlyBody.SE_JUPITER,
    'Venus': HeavenlyBody.SE_VENUS,
    'Saturn': HeavenlyBody.SE_SATURN,
    'Rahu': HeavenlyBody.SE_MEAN_NODE,
  };
  final result = <Placement>[];
  for (final item in bodies.entries) {
    final pos = Sweph.swe_calc_ut(jd, item.value, flags);
    result.add(Placement(item.key, norm(pos.longitude)));
  }
  final rahu = result.last.longitude;
  result.add(Placement('Ketu', norm(rahu + 180)));
  final asc = Sweph.swe_houses_ex(jd, SwephFlag.SEFLG_SIDEREAL, latitude, longitude, Hsys.SE_WHOLE_SIGN).ascmc[0];
  result.insert(0, Placement('Lagna', norm(asc)));
  final moon = result.firstWhere((p) => p.label == 'Moon').longitude;
  final nakIndex = (moon / nakSpan).floor() % 27;
  final pada = ((moon % nakSpan) / (nakSpan / 4)).floor() + 1;
  return Horoscope(result, nakIndex, pada, Sweph.swe_get_ayanamsa_ut(jd), vimshottari(utc, moon));
}
