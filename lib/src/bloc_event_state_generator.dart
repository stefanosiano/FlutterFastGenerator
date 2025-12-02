import 'package:analyzer/dart/constant/value.dart';
import 'package:flutter_fast/flutter_fast_annotations.dart';
import 'package:flutter_fast_generators/src/common_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';
import 'package:analyzer/dart/element/element.dart';

class BlocEventStateGenerator extends CommonGenerator<BlocEventState> {
  final _blocEventChecker = const TypeChecker.fromRuntime(BlocEventState);

  @override
  String generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    final DartObject annotation = _blocEventChecker.firstAnnotationOfExact(element)!;
    final BlocEventState bloc = _parseBloc(annotation);
    final StringBuffer buffer = StringBuffer();
    final String blocClassName = element.name!;
    final String blocProviderClassName = _toPascalCase('${bloc.classPrefix}BlocProvider');
    final String eventClassName = _toPascalCase('${bloc.classPrefix}Event');
    final String stateClassName = _toPascalCase('${bloc.classPrefix}State');

    // Write static methods of bloc class
    buffer.writeln(_generateBlocProvider(blocClassName, blocProviderClassName, stateClassName, bloc));

    // Write Event class and static methods
    buffer.writeln(_generateEventClass(eventClassName, bloc));

    // Write classes for each event
    for (BlocEvent event in bloc.events) {
      buffer.writeln(_generateEventDetailClass(eventClassName, event));
    }

    // Write State class, if specified in annotation
    if (bloc.state != null) {
      buffer.writeln(_generateStateClass(stateClassName, bloc));
    }

    return buffer.toString();
  }

  /// Parse and rebuild the [BlocEventState] annotation object.
  BlocEventState _parseBloc(DartObject annotation) {
    final String blocPrefix = annotation.getField('classPrefix')!.toStringValue()!;
    final List<DartObject>? events = annotation.getField('events')?.toListValue();
    final Set<DartObject>? state = annotation.getField('state')?.toSetValue();
    Set<_GenParam>? stateParams = state?.map((value) => _rebuildParam(value)).toSet();
    final BlocEventState bloc = BlocEventState(blocPrefix, [], state: stateParams);
    events?.forEach((eventDetail) {
      bloc.events.add(_rebuildBlocEvent(eventDetail));
    });
    return bloc;
  }

  /// Parse and rebuild the [BlocEvent] annotation object.
  BlocEvent _rebuildBlocEvent(DartObject rawEvent) {
    final String eventName = rawEvent.getField('eventName')!.toStringValue()!;
    final Set<DartObject>? params = rawEvent.getField('params')?.toSetValue();
    return BlocEvent(_toPascalCase(eventName), params: params?.map((value) => _rebuildParam(value)).toSet());
  }

  /// Parse and rebuild the [Param] annotation object, as [_GenParam].
  _GenParam _rebuildParam(DartObject rawParam) {
    final String name = rawParam.getField('name')!.toStringValue()!;
    final String type = parseParamType(rawParam);
    return _GenParam(name, type);
  }

  /// Generates the bloc provider class, in the following form.
  /// ```dart
  /// class MainBlocProvider extends FastBlocProvider<MainBloc, MainState> {
  ///   MainBlocProvider({
  ///     super.key,
  ///     super.blocListener,
  ///     super.lazy = true,
  ///     super.disposeBloc = false,
  ///     required super.child,
  ///   }) : super(create: (BuildContext context) => MainBloc._create(context));
  /// }
  /// ```
  String _generateBlocProvider(
      String blocClassName, String blocProviderClassName, String stateClassName, BlocEventState bloc) {
    final buffer = StringBuffer();
    // Generate static provider method
    buffer.writeln('class $blocProviderClassName extends FastBlocProvider<$blocClassName, $stateClassName> {'
        '  $blocProviderClassName({'
        '    super.key,'
        '    super.blocListener,'
        '    super.lazy = true,'
        '    super.disposeBloc = false,'
        '    required super.child,'
        '  }) : super(create: (BuildContext context) => $blocClassName._create(context));'
        '}');

    return buffer.toString();
  }

  /// Generates the main Event class and all static functions to generate other event instances, in the following form.
  /// ```dart
  /// class MainEvent extends FastBlocEvent {
  ///   MainEvent._();
  ///   static Event1 event1({required int param1, String? param2}) => Event1._(param1: param1, param2: param2);
  ///   static Event2 event2({required int param1}) => Event2._(param1: param1);
  ///   static Event3 event3() => Event3._();
  /// }
  /// ```
  String _generateEventClass(String eventClassName, BlocEventState bloc) {
    final buffer = StringBuffer();
    // Generate class declaration
    buffer.writeln('sealed class $eventClassName extends FastBlocEvent {');

    // Write static methods for each event
    for (var event in bloc.events) {
      final String eventClassName = _toPascalCase(event.eventName);
      final String eventMethodName = _toCamelCase(event.eventName);
      final methodParamBuffer = StringBuffer();
      final constructorParamBuffer = StringBuffer();
      final Set<_GenParam>? params = event.params as Set<_GenParam>?;

      if (params != null) {
        // Generate static method parameters
        methodParamBuffer.write('{');
        methodParamBuffer.write(params.map((e) => e.toRequiredTypeName()).join(', '));
        methodParamBuffer.write('}');
        // Generate event constructor parameters
        constructorParamBuffer.write(params.map((e) => e.toNameName()).join(', '));
      }

      // Generate static method
      buffer.writeln(
          'static $eventClassName $eventMethodName($methodParamBuffer) => $eventClassName._($constructorParamBuffer);');
    }
    // Generate class close
    buffer.writeln('}');
    return buffer.toString();
  }

  /// Generates the Event class extending the main Event, in the following form.
  /// ```dart
  /// class Event1 extends MainEvent {
  ///   final int param1;
  ///   final String? param2;
  ///   Event1._({required this.param1, this.param2}) : super._();
  /// }
  /// ```
  String _generateEventDetailClass(String blocEventClassName, BlocEvent event) {
    final Set<_GenParam>? params = event.params as Set<_GenParam>?;
    final String eventClassName = _toPascalCase(event.eventName);
    final buffer = StringBuffer();
    final constructorParamsBuffer = StringBuffer();

    // Generate class declaration
    buffer.writeln('final class $eventClassName extends $blocEventClassName {');
    if (params != null) {
      // Generate constructor parameters
      constructorParamsBuffer.write('{');
      constructorParamsBuffer.write(params.map((e) => e.toRequiredThisName()).join(', '));
      constructorParamsBuffer.write('}');
      // Generate class variables
      buffer.writeln(params.map((e) => e.toFinalTypeName()).join('\n'));
    }

    // Generate constructor
    buffer.writeln('$eventClassName._($constructorParamsBuffer);');
    // Generate class close
    buffer.writeln('}');
    return buffer.toString();
  }

  /// Generates the State class extending the FastBlocState, in the following form.
  /// ```dart
  /// class State extends FastBlocState {
  ///   final int param1;
  ///   final String? param2;
  ///   State._({
  ///     required this.param1,
  ///     this.param2,
  ///   });
  ///   State.create({
  ///     required this.param1,
  ///     this.param2,
  ///   });
  ///   State copyWith({
  ///     int? param1,
  ///     String? param2,
  ///   }) =>
  ///     State._(
  ///       param1: param1 ?? this.param1,
  ///       param2: param2 ?? this.param2,
  ///     );
  /// }
  /// ```
  String _generateStateClass(String stateClassName, BlocEventState bloc) {
    final Set<_GenParam>? variables = bloc.state as Set<_GenParam>?;
    final buffer = StringBuffer();
    final constructorParamsBuffer = StringBuffer();
    final copyWithParamsBuffer = StringBuffer();
    final copyWithImplParamsBuffer = StringBuffer();

    // Generate class declaration
    buffer.writeln('class $stateClassName extends FastBlocState {');
    if (variables != null) {
      // Generate constructor parameters
      constructorParamsBuffer.write('{');
      constructorParamsBuffer.write(variables.map((e) => e.toRequiredThisName()).join(', '));
      constructorParamsBuffer.write('}');
      // Generate class variables
      buffer.writeln(variables.map((e) => e.toFinalTypeName()).join('\n'));
      // Generate copyWith parameters
      copyWithParamsBuffer.write('{');
      copyWithParamsBuffer.write(variables.map((e) => e.toNullableTypeName()).join(', '));
      copyWithParamsBuffer.write('}');
      // Generate copyWith implementation parameters
      copyWithImplParamsBuffer.write(variables.map((e) => e.toNameOrThisName()).join(', '));
    }

    // Generate private constructor
    buffer.writeln('$stateClassName._($constructorParamsBuffer);');
    // Generate public named constructor
    buffer.writeln('$stateClassName.create($constructorParamsBuffer);');
    // Generate copyWith method
    buffer.writeln('@override');
    buffer.writeln('$stateClassName copyWith($copyWithParamsBuffer) => $stateClassName._(');
    buffer.writeln('$copyWithImplParamsBuffer');
    buffer.writeln(');');
    // Generate class close
    buffer.writeln('}');
    return buffer.toString();
  }

  /// Lowercase the first letter of [text]
  String _toCamelCase(String text) =>
      text[0] == '_' ? '_${text[1].toLowerCase()}${text.substring(2)}' : '${text[0].toLowerCase()}${text.substring(1)}';

  /// Capitalize the first letter of [text]
  String _toPascalCase(String text) =>
      text[0] == '_' ? '_${text[1].toUpperCase()}${text.substring(2)}' : '${text[0].toUpperCase()}${text.substring(1)}';
}

class _GenParam extends Param {
  final String type;

  _GenParam(super.name, this.type);

  /// Return 'name: name'
  String toNameName() => '$name: $name';

  /// Return 'required type: name' or 'type?: name'
  String toRequiredTypeName() => type.endsWith('?') ? '$type $name' : 'required $type $name';

  /// Return 'required this.name' or 'this.name'
  String toRequiredThisName() => type.endsWith('?') ? 'this.$name' : 'required this.$name';

  /// Return 'type? name'
  String toNullableTypeName() => type.endsWith('?') ? '$type $name' : '$type? $name';

  /// Return 'name: name ?? this.name'
  String toNameOrThisName() => '$name: $name ?? this.$name';

  /// Return 'final type name'
  String toFinalTypeName() => 'final $type $name;';
}
