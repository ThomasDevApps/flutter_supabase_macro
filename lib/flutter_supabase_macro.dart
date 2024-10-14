library;

import 'dart:async';

import 'package:macros/macros.dart';

part 'src/extensions/iterable_extension.dart';
part 'src/mixins/shared.dart';
part 'src/mixins/to_json_supabase.dart';
part 'src/models/shared_introspection_data.dart';

final _dartCore = Uri.parse('dart:core');

final _toJsonMethodName = 'toJsonSupabase';

macro class FlutterSupabaseMacro
    with _Shared, _ToJsonSupabase
    implements ClassDeclarationsMacro, ClassDefinitionMacro {

  /// Primary key to exclude from the `toJsonSupabase`.
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
        builder.report(
          Diagnostic(
            DiagnosticMessage(
                'Only fields with named types are allowed on serializable '
                    'classes',
                target: asDiagnosticTarget,
            ),
          Severity.error,
          ),
        );
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
