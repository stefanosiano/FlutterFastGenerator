import 'package:analyzer/dart/constant/value.dart';
import 'package:flutter_fast/flutter_fast_annotations.dart';
import 'package:flutter_fast_generators/src/common_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';
import 'package:analyzer/dart/element/element.dart';

class PrefGenerator extends CommonGenerator<Pref> {
  final _prefChecker = const TypeChecker.fromRuntime(Pref);
  late final StringBuffer _preferencesRepository =
      StringBuffer('class PreferencesRepository extends FastPreferencesRepository {\n');
  final _preferences = <String, Pref>{};

  @override
  String onGenerationEnd() {
    _preferencesRepository.writeln('Future<void> load() async {');
    for (String prefClass in _preferences.keys) {
      _preferencesRepository.writeln('await _load${toPascalCase(prefClass)}();');
    }
    _preferencesRepository.writeln('}');
    _preferencesRepository.writeln('\n');

    _preferencesRepository.writeln('PreferencesRepository() {');
    for (MapEntry<String, Pref> pref in _preferences.entries) {
      _preferencesRepository.writeln(
          '_${toCamelCase(pref.key)}.setup(fileName: \'${pref.value.fileName}\', logEverything: ${pref.value.logEverything});');
    }
    _preferencesRepository.writeln('}');

    _preferencesRepository.writeln('}');
    return _preferencesRepository.toString();
  }

  @override
  String generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    super.generateForAnnotatedElement(element, annotation, buildStep);

    final DartObject prefAnnotation = _prefChecker.firstAnnotationOfExact(element)!;
    var visitor = CommonModelVisitor(element as ClassElement);
    final String fileName = prefAnnotation.getField('fileName')!.toStringValue()!;
    final bool logEverything = prefAnnotation.getField('logEverything')!.toBoolValue()!;
    _preferences[visitor.element.name] = Pref(fileName: fileName, logEverything: logEverything);

    final buffer = StringBuffer();
    _preferencesRepository.writeln(_instantiatePreferences(visitor.element));
    _preferencesRepository.writeln(_createSaveGetSubscribeMethods(visitor, fileName));
    _preferencesRepository.writeln(_createLoadMethod(visitor, fileName));

    return buffer.toString();
  }

  /// Checks the annotated class for mistakes and instantiates the preferences objects in the PreferencesProvider:
  /// ```dart
  /// class PreferencesRepository extends FastPreferencesRepository {
  ///   final AppPreferences _appPreferences = AppPreferences();
  ///   bool _appPreferencesLoaded = false;
  /// }
  /// ```
  String _instantiatePreferences(ClassElement element) {
    final buffer = StringBuffer();
    final className = element.name;
    final supertypeNames = element.allSupertypes.map((e) => e.getDisplayString());
    if (!supertypeNames.contains('FastPreferenceManager')) {
      throw Exception('$className class must extend FastPreferenceManager');
    }
    if (!element.isConstructable) {
      throw Exception('$className cannot be instanced');
    }
    // Generate static provider method
    buffer.writeln('final $className _${toCamelCase(className)} = $className();');
    // Generate static provider method
    buffer.writeln('bool _${toCamelCase(className)}Loaded = false;');
    return buffer.toString();
  }

  /// Generates the save, get and subscribe methods in the PreferencesProvider:
  /// ```dart
  /// final String _prefStreamKey = 'prefStreamKey';
  /// ThemeMode getPref() => _preferences.pref.value;
  ///
  /// void savePref(Pref pref) {
  ///   _preferences.pref.value = mode;
  ///   refreshStream(_prefStreamKey);
  /// }
  ///
  /// StreamSubscription<Pref> getPrefStream(void Function(Pref pref) onPref) =>
  ///   subscribe(_prefStreamKey, () async => _preferences.pref.value, onPref);
  /// ```
  String _createSaveGetSubscribeMethods(CommonModelVisitor visitor, String prefFileName) {
    final buffer = StringBuffer();
    final prefs = _getDeclaredPreferences(visitor);
    final className = visitor.element.name;
    final instanceName = '_${toCamelCase(className)}';

    for (var pref in prefs) {
      final name = pref.name;
      final upperName = toPascalCase(pref.name);
      final streamKey = '${prefFileName.replaceAll('.', '_')}_${upperName}StreamKey';
      final type = pref.type.getDisplayString().split('<').last.split('>').first;
      buffer.writeln('// ignore: non_constant_identifier_names');
      buffer.writeln('final String _$streamKey = \'$streamKey\';');
      buffer.writeln('\n');
      buffer.writeln('$type get$upperName() => $instanceName.$name.value;');
      buffer.writeln('\n');
      buffer.writeln('void save$upperName($type data) {');
      buffer.writeln('$instanceName.$name.value = data;');
      buffer.writeln('refreshStream(_$streamKey);');
      buffer.writeln('}');
      buffer.writeln('\n');
      buffer.writeln('StreamSubscription<$type> get${upperName}Stream(void Function($type) onData) =>');
      buffer.writeln('subscribe(_$streamKey, () async => $instanceName.$name.value, onData,);');
      buffer.writeln('\n');
    }
    return buffer.toString();
  }

  /// Generates the loadMyPrefences() methods in the FastPreferencesProvider:
  /// ```dart
  ///  Future<void> _loadMyPreferences() async {
  ///    if (_myPreferencesLoaded) {
  ///      return;
  ///    }
  ///    _myPreferencesLoaded = true;
  ///
  ///    List<FastPreference> prefs = [_myPreferences.pref1, _myPreferences.pref2]..sort((a, b) => a.deferLoad ? 1 : -1);
  ///    for (FastPreference p in prefs) {
  ///      _myPreferences.register(p, saveDelayMillis: p.saveDelayMillis);
  ///      if (!p.deferLoad) {
  ///        p.value = await _myPreferences.get(p.value, p.key);
  ///      } else {
  ///        _myPreferences.get(p.value, p.key).then((v) {
  ///          p.value = v;
  ///        });
  ///      }
  ///    }
  /// ```
  String _createLoadMethod(CommonModelVisitor visitor, String prefFileName) {
    final buffer = StringBuffer();
    final prefs = _getDeclaredPreferences(visitor);
    final className = visitor.element.name;
    final instanceName = '_${toCamelCase(className)}';
    final List<String> prefAccessors = prefs.map((e) => '$instanceName.${e.name}').toList();

    buffer.writeln('Future<void> _load${toPascalCase(className)}() async {');
    buffer.writeln('if (${instanceName}Loaded) { return; }');
    buffer.writeln('if (${instanceName}Loaded) { return; }');
    buffer.writeln('${instanceName}Loaded = true;');
    buffer
        .writeln('final List<FastPreference> prefs = [${prefAccessors.join(', ')}]..sort((a, b) => a.deferLoad ? 1 : -1);');
    buffer.writeln('for (final FastPreference p in prefs) {');
    buffer.writeln('$instanceName.register(p, saveDelayMillis: p.saveDelayMillis);');
    buffer.writeln('if (!p.deferLoad) {');
    buffer.writeln('p.value = await $instanceName.get(p.value, p.key);');
    buffer.writeln('} else {');
    buffer.writeln('$instanceName.get(p.value, p.key).then((v) { p.value = v; });');
    buffer.writeln('}');
    // End for
    buffer.writeln('}');
    // End method
    buffer.writeln('}');
    buffer.writeln('\n');
    return buffer.toString();
  }

  Iterable<FieldElement> _getDeclaredPreferences(CommonModelVisitor visitor) =>
      visitor.fields.values.where((e) => e.type.getDisplayString().startsWith('FastPreference<'));
}
