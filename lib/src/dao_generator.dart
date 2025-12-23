import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:flutter_fast/flutter_fast_annotations.dart';
import 'package:flutter_fast_generators/src/common_generator.dart';
import 'package:source_gen/source_gen.dart';

class DaoGenerator extends CommonGenerator<Dao> {
  @override
  String generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    super.generateForAnnotatedElement(element, annotation, buildStep);

    final DartObject rawDao = typeChecker.firstAnnotationOfExact(element)!;
    var visitor = CommonModelVisitor(element as ClassElement);
    checkForErrors(element);

    final GenDao dao = _rebuildDao(rawDao);

    TypeChecker queryChecker = TypeChecker.typeNamed(Query);
    Iterable<GenQuery> queries = visitor.methods.values.where((f) => queryChecker.hasAnnotationOf(f)).map((method) {
      final DartObject rawQuery = queryChecker.firstAnnotationOf(method)!;
      return _rebuildQuery(rawQuery, method);
    });

    final buffer = StringBuffer();
    buffer.writeln(_createDaoImpl(dao, visitor.element.displayName, queries));
    buffer.writeln(_createDbHelperExtension(visitor.element.displayName));

    return buffer.toString();
  }

  void checkForErrors(ClassElement element) {
    final className = element.displayName;
    final supertypeNames = element.allSupertypes.map((e) => e.getDisplayString());
    if (!supertypeNames.contains('FastDao')) {
      throw Exception('$className class must implement FastDao');
    }
  }

  /// Generates the mapping class, with its constructor and a copyWith() method:
  /// ```dart
  /// class MyEntity {
  ///   final int id;
  /// }
  ///
  /// MyEntity({
  ///   required this.id,
  /// });
  /// MyEntity copyWith({
  ///   final int? id,
  /// }) =>
  ///     MyEntity(
  ///       id: id ?? this.id,
  ///     );
  /// }
  /// ```
  String _createDaoImpl(GenDao dao, String daoClassName, Iterable<GenQuery> queries) {
    final buffer = StringBuffer();
    final entityType = dao.entityType;
    final entityName = entityType?.getDisplayString().replaceAll('?', '');
    final daoImplName = '_${daoClassName}Impl';

    // Class declaration
    buffer.writeln('class $daoImplName extends $daoClassName with FastDaoMixin {');
    buffer.writeln('static final $daoImplName instance = $daoImplName._();');
    buffer.writeln('\n');

    // Default empty private constructor
    buffer.writeln('_${daoClassName}Impl._();');
    buffer.writeln('\n');

    // Queries
    for (GenQuery query in queries) {
      buffer.writeln(_createQueryImpl(query, daoClassName));
    }

    // End class
    buffer.writeln('}');
    buffer.writeln('\n');

    buffer.writeln('extension ${daoClassName}DaoExtension on $daoClassName {');
    // Add db() extension
    buffer.writeln('db() => (this as $daoImplName).db;');
    // Add inserts extensions
    if (dao.tableName != null && entityName != null) {
      buffer.writeln('\n');
      buffer.writeln(
          '  Future<void> insertOrReplace($entityName data) async => (this as $daoImplName).insertOrReplace(\'${dao.tableName}\', data, (this as $daoImplName).${_buildParseToDb(entityName)});');
      buffer.writeln('\n');
      buffer.writeln(
          '  Future<void> insertOrIgnore($entityName data) async => (this as $daoImplName).insertOrIgnore(\'${dao.tableName}\', data, (this as $daoImplName).${_buildParseToDb(entityName)});');
      buffer.writeln('\n');
      buffer.writeln(
          '  Future<void> insertOrReplaceAll(Iterable<$entityName> data) async => (this as $daoImplName).insertOrReplaceAll(\'${dao.tableName}\', data, (this as $daoImplName).${_buildParseToDb(entityName)});');
      buffer.writeln('\n');
      buffer.writeln(
          '  Future<void> insertOrIgnoreAll(Iterable<$entityName> data) async => (this as $daoImplName).insertOrIgnoreAll(\'${dao.tableName}\', data, (this as $daoImplName).${_buildParseToDb(entityName)});');
    }
    buffer.writeln('}');
    buffer.writeln('\n');

    return buffer.toString();
  }

  String _createDbHelperExtension(String daoClassName) {
    final buffer = StringBuffer();

    buffer.writeln('extension ${daoClassName}FastDatabaseHelperExtension on FastDatabaseHelper {');
    buffer.writeln('$daoClassName ${toCamelCase(daoClassName)}() => _${daoClassName}Impl.instance;');
    buffer.writeln('}');
    buffer.writeln('\n');

    return buffer.toString();
  }

  String _createQueryImpl(GenQuery query, String daoClassName) {
    query.checkReturnType(daoClassName);

    final buffer = StringBuffer();
    final methodName = query.method.name;
    final Iterable<String> queryParams = query.queryParams();
    final Iterable<String> missingFunctionParams = query.functionParams().where((p) => !queryParams.contains(p));
    final Iterable<String> missingQueryParams = queryParams.where((p) => !query.functionParams().contains(p));
    final String rawQueryCall = query.rawQueryCall();
    final String rawUpdateCall = query.rawUpdateCall();
    final String retType = query.innerType();
    final bool isIterable = retType.startsWith('Iterable<');
    final String type = isIterable ? retType.substring('Iterable<'.length, retType.length - 1) : retType;

    if (missingFunctionParams.isNotEmpty) {
      throw Exception('$methodName declared parameters not used by the query: $daoClassName.$missingFunctionParams\n');
    }
    if (missingQueryParams.isNotEmpty) {
      throw Exception(
          '$methodName should declare the following parameters used by the query: $daoClassName.$missingQueryParams\n');
    }

    buffer.writeln('@override');
    buffer.writeln(query.rebuiltMethodDeclaration());

    if (query.isInsertOrUpdate) {
      buffer.writeln('$rawUpdateCall;');
      buffer.writeln('dbHelper.notifyTableChange(\'${query.updateTable}\');');
      buffer.writeln('return;');
    } else if (query.isStream) {
      buffer.writeln('final toRet = streamResult(');
      buffer.writeln('\'_$daoClassName#$methodName\',');
      buffer.writeln('[${query.tables.map((t) => '\'$t\'').join(', ')}],');
      buffer.writeln('() async => ${query.toItemsToCall()}(');
      buffer.writeln('$rawQueryCall,');
      buffer.writeln('${_buildParseFromDb(type)}),');
      buffer.writeln(');');
      buffer.writeln('return toRet;');
    } else {
      buffer.writeln('final toRet = ${query.toItemsToCall()}($rawQueryCall, ${_buildParseFromDb(type)});');
      buffer.writeln('return toRet;');
    }

    buffer.writeln('}');
    buffer.writeln('\n');

    return buffer.toString();
  }

  GenDao _rebuildDao(DartObject rawDao) {
    final DartType? entityType = rawDao.getField('entityClass')?.toTypeValue();
    final String? tableName = rawDao.getField('tableName')?.toStringValue();
    return tableName != null ? GenDao.table(entityType: entityType, tableName: tableName) : GenDao();
  }

  GenQuery _rebuildQuery(DartObject rawQuery, MethodElement method) {
    final String query = rawQuery.getField('value')!.toStringValue()!;
    final Iterable<String> tables = rawQuery.getField('tables')!.toListValue()!.map((e) => e.toStringValue()!);
    final bool isInsertOrUpdate = rawQuery.getField('isInsertOrUpdate')!.toBoolValue()!;
    final String updateTable = rawQuery.getField('updateTable')!.toStringValue()!;
    final bool isStream = rawQuery.getField('isStream')!.toBoolValue()!;

    return isInsertOrUpdate
        ? GenQuery.update(query, updateTable: updateTable, method: method)
        : isStream
            ? GenQuery.stream(query, tables: tables, method: method)
            : GenQuery(query, method: method);
  }

  String _buildParseFromDb(String type) {
    return 'parse${toPascalCase(type.replaceAll('?', '').replaceAll('<', '_').replaceAll('>', '_'))}FromDb';
  }

  String _buildParseToDb(String type) {
    return 'parse${toPascalCase(type.replaceAll('?', '').replaceAll('<', '_').replaceAll('>', '_'))}ToDb';
  }
}

class GenDao extends Dao {
  final DartType? entityType;
  GenDao.table({
    required this.entityType,
    required String super.tableName,
  }) : super.table(entityClass: null);

  GenDao() : entityType = null;
}

class GenQuery extends Query {
  final MethodElement method;

  const GenQuery(super.value, {required this.method});

  const GenQuery.update(super.value, {required super.updateTable, required this.method}) : super.update();

  const GenQuery.stream(super.value, {required super.tables, required this.method}) : super.stream();

  @override
  String toString() {
    return 'GenQuery{value: $value, tables: $tables, isInsertOrUpdate: $isInsertOrUpdate}';
  }

  Iterable<String> queryParams() {
    final RegExp paramRegex = RegExp(":[\\w]+");
    return paramRegex.allMatches(value).map((r) => r.group(0)?.replaceAll(':', '')).nonNulls;
  }

  Iterable<String> functionParams() => method.typeParameters.map((p) => p.displayName);

  String innerType() {
    final String retType = method.returnType.toString();
    return isStream
        ? retType.substring('Stream<'.length, retType.length - 1)
        : isSelect
            ? retType.substring('Future<'.length, retType.length - 1)
            : retType;
  }

  void checkReturnType(String daoClassName) {
    final String retType = method.returnType.toString();
    if (isInsertOrUpdate && retType != 'Future<void>') {
      throw Exception('Insert or update queries must return a Future<void>. Check $daoClassName.${method.name}');
    } else if (isStream && !retType.startsWith('Stream<')) {
      throw Exception('Stream queries must return a Stream. Check $daoClassName.${method.name}');
    } else if (isSelect && !retType.startsWith('Future<')) {
      throw Exception('Query method must return a Future and be async. Check $daoClassName.${method.name}');
    }
    if (isStream && tables.isEmpty) {
      throw Exception('Stream queries must specify tables to listen for changes. Check $daoClassName.${method.name}');
    }
    if (isSelect || isStream) {
      String innertype = innerType();
      final bool isIterable = innertype.startsWith('Iterable<');
      final String type = isIterable ? innertype.substring('Iterable<'.length, innertype.length - 1) : innertype;
      if (!isIterable && !type.endsWith('?')) {
        throw Exception(
            'Queries returning a single value must have nullable types. Change the return type of $daoClassName.${method.name}');
      }
    }
  }

  String parseQuery() {
    String sql = value;
    for (String param in queryParams()) {
      sql = sql.replaceAll(':$param', '?');
    }
    return sql.trim();
  }

  String rawQueryCall() {
    final params = queryParams();
    String callParams = params.isEmpty ? '' : ', [${params.join(', ')}]';
    return 'db.rawQuery(\'\'\'${parseQuery()} \'\'\'$callParams)';
  }

  String rawUpdateCall() {
    final params = queryParams();
    String callParams = params.isEmpty ? '' : ', [${params.join(', ')}]';
    return 'db.rawUpdate(\'\'\'${parseQuery()} \'\'\'$callParams)';
  }

  String rebuiltMethodDeclaration() {
    return isStream ? '$method {' : '$method async {';
  }

  String toItemsToCall() {
    final String retType = innerType();
    final bool isIterable = retType.startsWith('Iterable<');
    final String type = isIterable ? retType.substring('Iterable<'.length, retType.length - 1) : retType;
    final bool isNullableType = type.endsWith('?');
    return isIterable && isNullableType
        ? 'toItems'
        : isIterable
            ? 'toItemsNonNulls'
            : 'toSingleItem';
  }
}
