import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:flutter_fast/flutter_fast_annotations.dart';
import 'package:flutter_fast_generators/src/common_generator.dart';
import 'package:source_gen/source_gen.dart';

class QueryableGenerator extends CommonGenerator<Queryable> {
  @override
  String generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    super.generateForAnnotatedElement(element, annotation, buildStep);

    final DartObject rawQueryable = typeChecker.firstAnnotationOfExact(element)!;
    var visitor = CommonModelVisitor(element as ClassElement);
    final Queryable queryable = _rebuildQueryable(rawQueryable);

    TypeChecker fieldChecker = TypeChecker.fromRuntime(QueryableField);
    Iterable<GenQueryableField> fields = visitor.fields.values.map((field) {
      if (fieldChecker.hasAnnotationOf(field)) {
        final DartObject rawField = fieldChecker.firstAnnotationOf(field)!;
        return _rebuildField(rawField, field);
      }
      return GenQueryableField.fromField(field);
    });
    fields = fields.where((field) => !field.ignore);

    checkForErrors(element, fields);

    final buffer = StringBuffer();
    buffer.writeln(_createParseExtension(fields, queryable, visitor.element.name));
    buffer.writeln(_createCommentedQueries(fields, queryable, visitor.element.name));

    return buffer.toString();
  }

  void checkForErrors(ClassElement element, Iterable<GenQueryableField> fields) {
    final className = element.name;
    final supertypeNames = element.allSupertypes.map((e) => e.getDisplayString());
    if (!supertypeNames.contains('FastQueryable')) {
      throw Exception('$className class must implement FastQueryable');
    }

    for (GenQueryableField field in fields) {
      if ((field.fromDbElem == null && field.toDbElem != null) ||
          (field.fromDbElem != null && field.toDbElem == null)) {
        throw Exception('Field $className.${field.fieldName} must have both fromDb and toDb methods');
      }
      if (field.fromDbElem != null && field.toDbElem != null) {
        if (field.classType != field.fieldType.toString()) {
          throw Exception(
              '$className.${field.fieldName} must be the same type of ${field.fromDbElem!.name} return type, but they are ${field.fieldType} and ${field.classType}');
        }

        if (field.fromDbElem!.returnType.toString() != field.classType ||
            field.fromDbElem!.parameters.first.type.toString() != field.columnType) {
          throw Exception(
              '$className.${field.fieldName} ${field.fromDbElem!.name} method must be a ${field.classType} Function(${field.columnType})');
        }
        if (field.toDbElem!.returnType.toString() != field.columnType ||
            field.toDbElem!.parameters.first.type.toString() != field.classType) {
          throw Exception(
              '$className.${field.fieldName} ${field.toDbElem!.name} method must be a ${field.columnType} Function(${field.classType})');
        }
      }
    }
  }

  String _createParseExtension(Iterable<GenQueryableField> fields, Queryable queryable, String className) {
    final buffer = StringBuffer();

    buffer.writeln('extension FastDaoMixin${className}Extension on FastDaoMixin {');

    String constructor = queryable.constructorName.isEmpty ? '' : '.${queryable.constructorName}';
    // ParseFromDb method
    buffer.writeln('  $className parse${className}FromDb(Map<String, Object?> map) => $className$constructor(');
    for (GenQueryableField field in fields) {
      String name = field.columnName ?? field.fieldName;
      String alias = field.columnName != null ? ', alias: \'${field.columnName}\'' : '';
      bool isNotNullRequired =
          field.fromDbElem == null && field.fieldType.nullabilitySuffix != NullabilitySuffix.question;
      String methodValues = field.fromDbElem != null ? 'map[\'$name\'] as ${field.columnType}' : 'map, \'$name\'$alias';
      //id: fromDb(map, 'id', alias: 'expectedId')!,
      buffer.writeln('$name: ${field.fromDbMethod()}($methodValues)${isNotNullRequired ? '!' : ''},');
    }
    buffer.writeln(');');
    buffer.writeln('\n');

    // ParseToDb method
    buffer.writeln('  Map<String, Object?> parse${className}ToDb($className data) => {');
    for (GenQueryableField field in fields) {
      String name = field.columnName ?? field.fieldName;
      //'id': toDb<int>(data.id),
      buffer.writeln('\'$name\': ${field.toDbMethod()}(data.${field.fieldName}),');
    }
    buffer.writeln('};');
    buffer.writeln('\n');

    // End extension class
    buffer.writeln('}');
    buffer.writeln('\n');

    return buffer.toString();
  }

  String _createCommentedQueries(Iterable<GenQueryableField> fields, Queryable queryable, String className) {
    final buffer = StringBuffer();

    buffer.writeln('\n');
    buffer.writeln('/*');
    buffer.writeln('Query for table creation. Adjust as needed');
    buffer.writeln('\'\'\'');
    buffer.writeln('CREATE TABLE `${toCamelCase(className)}` (');
    for (GenQueryableField field in fields) {
      buffer.writeln('  `${field.columnOrFieldName()}` ${field.sqlQueryType()},');
    }
    buffer.writeln('  PRIMARY KEY (${fields.take(2).map((f) => '`${f.columnOrFieldName()}`').join(', ')})');
    buffer.writeln(')');
    buffer.writeln('\'\'\'');
    buffer.writeln('*/');
    buffer.writeln('\n');

    return buffer.toString();
  }

  Queryable _rebuildQueryable(DartObject rawQueryable) {
    final String constructorName = rawQueryable.getField('constructorName')!.toStringValue()!;
    return Queryable(constructorName: constructorName);
  }

  GenQueryableField _rebuildField(DartObject rawField, FieldElement field) {
    final ExecutableElement? fromDbElem = rawField.getField('fromDb')?.toFunctionValue();
    final ExecutableElement? toDbElem = rawField.getField('toDb')?.toFunctionValue();
    final String? columnName = rawField.getField('columnName')?.toStringValue();
    final bool ignore = rawField.getField('ignore')!.toBoolValue()!;

    return GenQueryableField(
      fieldName: field.name,
      fieldType: field.type,
      columnType: parseTypeParameters(rawField).first,
      classType: parseTypeParameters(rawField).last,
      fromDbElem: fromDbElem,
      toDbElem: toDbElem,
      columnName: columnName,
      ignore: ignore,
    );
  }
}

class GenQueryableField extends QueryableField {
  final String columnType;
  final String classType;
  final DartType fieldType;
  final ExecutableElement? fromDbElem;
  final ExecutableElement? toDbElem;
  final String fieldName;

  GenQueryableField({
    required this.fieldName,
    required this.fieldType,
    required this.columnType,
    required this.classType,
    this.fromDbElem,
    this.toDbElem,
    super.columnName,
    super.ignore,
  });

  GenQueryableField.fromField(FieldElement field)
      : this(
            fieldName: field.name,
            fieldType: field.type,
            columnName: field.name,
            ignore: false,
            columnType: 'dynamic',
            classType: field.type.getDisplayString());

  @override
  String toString() {
    return 'GenQueryableField(columnType: $columnType, classType: $classType, fromDbElem: $fromDbElem, toDbElem: $toDbElem, columnName: $columnName, ignore: $ignore)';
  }

  String columnOrFieldName() => columnName ?? fieldName;

  String sqlQueryType() => _sqlQueryType(fieldType.toString()) ?? _sqlQueryType(columnType) ?? 'TYPE';

  String? _sqlQueryType(String type) => switch (type) {
        'int?' => 'INTEGER',
        'int' => 'INTEGER NOT NULL DEFAULT 0',
        'double?' => 'REAL',
        'double' => 'REAL NOT NULL DEFAULT 0',
        'String?' => 'TEXT',
        'String' => 'TEXT NOT NULL DEFAULT \'\'',
        'bool?' => 'INTEGER',
        'bool' => 'INTEGER NOT NULL DEFAULT 0',
        'Iterable<int>?' => 'TEXT',
        'Iterable<int>' => 'TEXT NOT NULL DEFAULT \'\'',
        'DateTime?' => 'INTEGER',
        'DateTime' => 'INTEGER NOT NULL DEFAULT 0',
        _ => null,
      };

  String fromDbMethod() {
    String? methodClassName = fromDbElem?.enclosingElement3.name?.trim();
    String? methodName = fromDbElem?.name.trim();
    String toRet = methodClassName != null ? '$methodClassName.' : '';
    toRet += methodName ?? '';
    return toRet.isEmpty ? 'fromDb' : toRet;
  }

  String toDbMethod() {
    String? methodClassName = toDbElem?.enclosingElement3.name?.trim();
    String? methodName = toDbElem?.name.trim();
    String toRet = methodClassName != null ? '$methodClassName.' : '';
    toRet += methodName ?? '';
    return toRet.isEmpty ? 'toDb<${fieldType.getDisplayString()}>' : toRet;
  }
}
