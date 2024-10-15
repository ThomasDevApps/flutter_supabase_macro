// ignore_for_file: deprecated_member_use, unintended_html_in_doc_comment

part of '../../flutter_supabase_macro.dart';

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

  /// A [Code] representation of the type `dynamic`.
  final NamedTypeAnnotationCode dynamicCode;

  /// A [Code] representation of the type [bool].
  final NamedTypeAnnotationCode boolCode;

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
    required this.boolCode,
    required this.superclass,
  });

  static Future<_SharedIntrospectionData> build(
      DeclarationPhaseIntrospector builder, ClassDeclaration clazz) async {
    // Resolve identifiers
    final (list, map, mapEntry, dynamic, string, bool) = await (
      builder.resolveIdentifier(_dartCore, 'List'),
      builder.resolveIdentifier(_dartCore, 'Map'),
      builder.resolveIdentifier(_dartCore, 'MapEntry'),
      builder.resolveIdentifier(_dartCore, 'dynamic'),
      builder.resolveIdentifier(_dartCore, 'String'),
      builder.resolveIdentifier(_dartCore, 'bool'),
    ).wait;

    // Get all NamedTypeAnnotationCode
    final dynamicCode = NamedTypeAnnotationCode(name: dynamic);
    final jsonListCode = NamedTypeAnnotationCode(name: list, typeArguments: [
      dynamicCode,
    ]);
    final jsonMapCode = NamedTypeAnnotationCode(name: map, typeArguments: [
      NamedTypeAnnotationCode(name: string),
      dynamicCode,
    ]);
    final stringCode = NamedTypeAnnotationCode(name: string);
    final boolCode = NamedTypeAnnotationCode(name: bool);

    // Get the class's superclass (if exist)
    final superclass = clazz.superclass;

    // Get fields, jsonMapType and the declaration of the superclass.
    final (fields, jsonMapType, superclassDecl) = await (
      builder.fieldsOf(clazz),
      builder.resolve(jsonMapCode),
      superclass == null
          ? Future.value(null)
          : builder.typeDeclarationOf(superclass.identifier),
    ).wait;

    // Create _SharedIntrospectionData model
    return _SharedIntrospectionData(
      clazz: clazz,
      fields: fields,
      jsonListCode: jsonListCode,
      jsonMapCode: jsonMapCode,
      jsonMapType: jsonMapType,
      mapEntry: mapEntry,
      dynamicCode: dynamicCode,
      stringCode: stringCode,
      boolCode: boolCode,
      superclass: superclassDecl as ClassDeclaration?,
    );
  }
}
