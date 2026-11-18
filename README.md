# Jyotishya Kundali offline Android prototype (v0.2)

This is **source code**, not a compiled APK. Built with Flutter and `sweph` (Swiss Ephemeris).

## Features
- Offline Lahiri sidereal D1 and D9, South Indian grids
- Page 1: birth details, name, Rashi, Nakshatra, Pada, Lagna, planet positions
- Page 2: Vimshottari Mahadasha, Bhukti/Antardasha, Antara/Pratyantardasha dates
- Page 3: Navamsha chart
- Page 4: Janma Rashi chart
- Today's Kundali: select date, time and Indian place to view the planetary chart
- Major Indian cities with coordinates bundled offline, manual place/coordinates fallback
- Local saved birth records via shared_preferences (no cloud)

## Build with GitHub
1. Extract zip and upload **contents** to a GitHub private repository, preserving `.github/workflows/build-apk.yml`.
2. Visit **Actions** and run `Build offline Jyotishya Android APK` on main, or let push trigger it.
3. Open the finished run and download artifact `jyotishya-android-apk`.
4. Extract ZIP artifact and install `app-release.apk` on your phone.
5. **Build is not verified in this environment.** Check logs if any Flutter/Android dependency errors occur.

## Test checklist
- Pick Mumbai, Bengaluru, Mangaluru and verify latitude/longitude update.
- Enter a known birth date/time and compare D1, D9, Nakshatra, Pada and Dasha against a reference astrology calculation using the same Lahiri/mean-node and calendar conventions.
- Use Save offline, restart the app, reopen the record, confirm it matches.
- Turn on airplane mode, restart the app and calculate another chart.
- Use Today's Kundali and change its date, time and city; verify result changes.
- Test on physical Android phones including Android 15/16 if available.

## Important limitations
- The day chart is a planetary chart for a selected instant, **not** a sunrise-based Panchanga or daily predictions.
- Coordinates for listed major cities are approximate city centers. Fine accuracy requires birth coordinates.
- Indian Standard Time only, no DST or outside-India timezone database.
- Dasha year convention: 365.2425 days. This can differ from traditional implementations.
- Some date displays use the phone's timezone and may show a different local calendar date outside IST.
- Swiss Ephemeris / sweph licensing must be reviewed before distribution.
- No backup or export yet; clearing app data or uninstalling can delete saved records.
- Project has not been compiled or device tested here. Not ready for professional consultation without cross-validation.
