import 'dart:async';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

abstract class CommonGenerator<T> extends GeneratorForAnnotation<T> {
  bool _annotationFound = false;

  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) async {
    var result = await super.generate(library, buildStep);
    if (!_annotationFound) {
      return result;
    }
    _annotationFound = false;
    StringBuffer buffer = StringBuffer(result);
    buffer.writeln(onGenerationEnd());
    buffer.writeln('\n\n');
    return buffer.toString();
  }

  @override
  dynamic generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    _annotationFound = true;
  }

  String onGenerationEnd() => '';

  /// Parse generic type parameters of a [DartObject]
  Iterable<String> parseTypeParameters(DartObject object) {
    String type = object.type!.toString();
    return type.substring(type.indexOf('<') + 1, type.lastIndexOf('>')).split(',').map((e) => e.trim());
  }

  /// Parses type of a Param<T> [DartObject]
  String parseParamType(DartObject object) {
    String type = object.type!.toString();
    return type.substring(type.indexOf('<') + 1, type.lastIndexOf('>')).trim();
  }

  /// Lowercase the first letter of [text]
  String toCamelCase(String text) =>
      text[0] == '_' ? '_${text[1].toLowerCase()}${text.substring(2)}' : '${text[0].toLowerCase()}${text.substring(1)}';

  /// Capitalize the first letter of [text]
  String toPascalCase(String text) =>
      text[0] == '_' ? '_${text[1].toUpperCase()}${text.substring(2)}' : '${text[0].toUpperCase()}${text.substring(1)}';
}

class CommonModelVisitor extends SimpleElementVisitor {
  final ClassElement element;
  Map<String, FieldElement> fields = {};
  Map<String, MethodElement> methods = {};

  CommonModelVisitor(this.element) {
    element.visitChildren(this);
  }

  @override
  visitFieldElement(FieldElement element) {
    fields[element.name] = element;
  }

  @override
  visitMethodElement(MethodElement element) {
    methods[element.name] = element;
  }
}
