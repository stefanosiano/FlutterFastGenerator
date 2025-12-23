// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pref.dart';

// **************************************************************************
// PrefGenerator
// **************************************************************************

class PreferencesRepository extends FastPreferencesRepository {
  final AppPreferences _appPreferences = AppPreferences();
  bool _appPreferencesLoaded = false;

  // ignore: non_constant_identifier_names
  final String _app_prefs_dat_ThemeModeStreamKey =
      'app_prefs_dat_ThemeModeStreamKey';

  ThemeMode getThemeMode() => _appPreferences.themeMode.value;

  void saveThemeMode(ThemeMode data) {
    _appPreferences.themeMode.value = data;
    refreshStream(_app_prefs_dat_ThemeModeStreamKey);
  }

  StreamSubscription<ThemeMode> getThemeModeStream(
    void Function(ThemeMode) onData,
  ) => subscribe(
    _app_prefs_dat_ThemeModeStreamKey,
    () async => _appPreferences.themeMode.value,
    onData,
  );

  // ignore: non_constant_identifier_names
  final String _app_prefs_dat_LocaleStreamKey = 'app_prefs_dat_LocaleStreamKey';

  Locale getLocale() => _appPreferences.locale.value;

  void saveLocale(Locale data) {
    _appPreferences.locale.value = data;
    refreshStream(_app_prefs_dat_LocaleStreamKey);
  }

  StreamSubscription<Locale> getLocaleStream(void Function(Locale) onData) =>
      subscribe(
        _app_prefs_dat_LocaleStreamKey,
        () async => _appPreferences.locale.value,
        onData,
      );

  Future<void> _loadAppPreferences() async {
    if (_appPreferencesLoaded) {
      return;
    }
    if (_appPreferencesLoaded) {
      return;
    }
    _appPreferencesLoaded = true;
    final List<FastPreference> prefs = [
      _appPreferences.themeMode,
      _appPreferences.locale,
    ]..sort((a, b) => a.deferLoad ? 1 : -1);
    for (final FastPreference p in prefs) {
      _appPreferences.register(p, saveDelayMillis: p.saveDelayMillis);
      if (!p.deferLoad) {
        p.value = await _appPreferences.get(p.value, p.key);
      } else {
        _appPreferences.get(p.value, p.key).then((v) {
          p.value = v;
        });
      }
    }
  }

  Future<void> load() async {
    await _loadAppPreferences();
  }

  PreferencesRepository() {
    _appPreferences.setup(fileName: 'app_prefs.dat', logEverything: true);
  }
}
