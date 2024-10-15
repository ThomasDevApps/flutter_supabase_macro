library;

import 'dart:async';

import 'package:macros/macros.dart';

part 'src/extensions/code_extension.dart';
part 'src/extensions/iterable_extension.dart';
part 'src/extensions/named_type_annotation_extension.dart';
part 'src/extensions/type_declaration_extension.dart';
part 'src/mixins/shared.dart';
part 'src/mixins/to_json_supabase.dart';
part 'src/models/shared_introspection_data.dart';

final _dartCore = Uri.parse('dart:core');

final _toJsonMethodName = 'toJsonSupabase';

macro class FlutterSupabaseMacro
    with _Shared, _ToJsonSupabase
    implements ClassDeclarationsMacro, ClassDefinitionMacro {

  /// Primary key to exclude from the `toJsonSupabase`.
  @override
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
    );
  }
}

