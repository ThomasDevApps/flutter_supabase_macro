// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:macros/macros.dart';

part 'mixins/shared.dart';
part 'mixins/to_json_supabase.dart';

final _dartCore = Uri.parse('dart:core');

final _toJsonMethodName = 'toJsonSupabase';

macro class FlutterSupabaseMacro
    with _Shared, _ToJsonSupabase
    implements ClassDeclarationsMacro, ClassDefinitionMacro {

  final String primaryKey;
  const FlutterSupabaseMacro({this.primaryKey = 'id'});

  /// Declares the `fromJson` constructor and `toJsonSupabase` method, but does not
  /// implement them.
  @override
  Future<void> buildDeclarationsForClass(
    ClassDeclaration clazz, 
    MemberDeclarationBuilder builder,
  ) async {
    final mapStringObject = await _setup(clazz, builder);
    await _declareToJsonSupabase(clazz, builder, mapStringObject);
  }

  /// Provides the actual definitions of the `fromJson` constructor and `toJsonSupabase`
  /// method, which were declared in the previous phase.
  @override
  Future<void> buildDefinitionForClass(
    ClassDeclaration clazz, 
    TypeDefinitionBuilder builder,
  ) async {
    final introspectionData =
      await _SharedIntrospectionData.build(builder, clazz);
    await _buildToJsonSupabase(
      clazz,
      builder,
      introspectionData,
      primaryKey,
    );
  }
}

////////////////////////////////////////////////////////////////////////////////

/// This data is collected asynchronously, so we only want to do it once and
/// share that work across multiple locations.
final class _SharedIntrospectionData {
  /// The declaration of the class we are generating for.
  final ClassDeclaration clazz;

  /// All the fields on the [clazz].
  final List<FieldDeclaration> fields;

  /// A [Code] representation of the type [List<Object?>].
  final NamedTypeAnnotationCode jsonListCode;

  /// A [Code] representation of the type [Map<String, dynamic>].
  final NamedTypeAnnotationCode jsonMapCode;

  /// The resolved [StaticType] representing the [Map<String, dynamic>] type.
  final StaticType jsonMapType;

  /// The resolved identifier for the [MapEntry] class.
  final Identifier mapEntry;

  /// A [Code] representation of the type [Object].
  final NamedTypeAnnotationCode dynamicCode;

  /// A [Code] representation of the type [String].
  final NamedTypeAnnotationCode stringCode;

  /// The declaration of the superclass of [clazz], if it is not [Object].
  final ClassDeclaration? superclass;

  _SharedIntrospectionData({
    required this.clazz,
    required this.fields,
    required this.jsonListCode,
    required this.jsonMapCode,
    required this.jsonMapType,
    required this.mapEntry,
    required this.dynamicCode,
    required this.stringCode,
    required this.superclass,
  });

  static Future<_SharedIntrospectionData> build(
      DeclarationPhaseIntrospector builder, ClassDeclaration clazz) async {
    final (list, map, mapEntry, dynamic, string) = await (
    builder.resolveIdentifier(_dartCore, 'List'),
    builder.resolveIdentifier(_dartCore, 'Map'),
    builder.resolveIdentifier(_dartCore, 'MapEntry'),
    builder.resolveIdentifier(_dartCore, 'dynamic'),
    builder.resolveIdentifier(_dartCore, 'String'),
    ).wait;
    final dynamicCode = NamedTypeAnnotationCode(name: dynamic);
    final jsonListCode = NamedTypeAnnotationCode(name: list, typeArguments: [
      dynamicCode,
    ]);
    final jsonMapCode = NamedTypeAnnotationCode(name: map, typeArguments: [
      NamedTypeAnnotationCode(name: string),
      dynamicCode,
    ]);
    final stringCode = NamedTypeAnnotationCode(name: string);
    final superclass = clazz.superclass;
    final (fields, jsonMapType, superclassDecl) = await (
    builder.fieldsOf(clazz),
    builder.resolve(jsonMapCode),
    superclass == null
        ? Future.value(null)
        : builder.typeDeclarationOf(superclass.identifier),
    ).wait;

    return _SharedIntrospectionData(
      clazz: clazz,
      fields: fields,
      jsonListCode: jsonListCode,
      jsonMapCode: jsonMapCode,
      jsonMapType: jsonMapType,
      mapEntry: mapEntry,
      dynamicCode: dynamicCode,
      stringCode: stringCode,
      superclass: superclassDecl as ClassDeclaration?,
    );
  }
}

////////////////////////////////////////////////////////////////////////////////

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) compare) {
    for (final item in this) {
      if (compare(item)) return item;
    }
    return null;
  }
}

////////////////////////////////////////////////////////////////////////////////

extension _IsExactly on TypeDeclaration {
  /// Cheaper than checking types using a [StaticType].
  bool isExactly(String name, Uri library) =>
      identifier.name == name && this.library.uri == library;
}

////////////////////////////////////////////////////////////////////////////////

extension on Code {
  /// Used for error messages.
  String get debugString {
    final buffer = StringBuffer();
    _writeDebugString(buffer);
    return buffer.toString();
  }

  void _writeDebugString(StringBuffer buffer) {
    for (final part in parts) {
      switch (part) {
        case Code():
          part._writeDebugString(buffer);
        case Identifier():
          buffer.write(part.name);
        case OmittedTypeAnnotation():
          buffer.write('<omitted>');
        default:
          buffer.write(part);
      }
    }
  }
}

////////////////////////////////////////////////////////////////////////////////

extension on NamedTypeAnnotation {
  /// Follows the declaration of this type through any type aliases, until it
  /// reaches a [ClassDeclaration], or returns null if it does not bottom out on
  /// a class.
  Future<ClassDeclaration?> classDeclaration(DefinitionBuilder builder) async {
    var typeDecl = await builder.typeDeclarationOf(identifier);
    while (typeDecl is TypeAliasDeclaration) {
      final aliasedType = typeDecl.aliasedType;
      if (aliasedType is! NamedTypeAnnotation) {
        builder.report(Diagnostic(
            DiagnosticMessage(
                'Only fields with named types are allowed on serializable '
                    'classes',
                target: asDiagnosticTarget),
            Severity.error));
        return null;
      }
      typeDecl = await builder.typeDeclarationOf(aliasedType.identifier);
    }
    if (typeDecl is! ClassDeclaration) {
      builder.report(Diagnostic(
          DiagnosticMessage(
              'Only classes are supported as field types for serializable '
                  'classes',
              target: asDiagnosticTarget),
          Severity.error));
      return null;
    }
    return typeDecl;
  }
}
