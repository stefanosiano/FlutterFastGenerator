import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_fast/flutter_fast_annotations.dart';
import 'package:flutter_fast/flutter_fast_preferences.dart';
import 'package:flutter_fast/flutter_fast_utils.dart';

part 'pref.g.dart'; 

@Pref(fileName: 'app_prefs.dat', logEverything: true)
class AppPreferences extends FastPreferenceManager {
  late final themeMode = FastPreference<ThemeMode>(ThemeMode.light, 'theme_mode',
      decode: (id) => ThemeMode.values.byNameOr(id, ThemeMode.light), enc: (mode) => mode.name);

  late final locale = FastPreference<Locale>(
    const Locale(' '),
    'locale',
    future: () async => Locale('en'),
    decode: (code) => Locale(code),
    enc: (value) => value.languageCode,
    deferLoad: true,
  );
}
