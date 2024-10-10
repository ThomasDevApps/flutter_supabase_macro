// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:macros/macros.dart';

part 'mixins/shared.dart';
part 'mixins/to_json_supabase.dart';

final _dartCore = Uri.parse('dart:core');

macro class FlutterSupabaseMacro with _Shared, _ToJsonSupabase implements ClassDeclarationsMacro, ClassDefinitionMacro {
  final String idLabel;
  const FlutterSupabaseMacro({this.idLabel = 'id'});

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
    await _buildToJsonSupabase(clazz, builder, introspectionData);
  }
}

////////////////////////////////////////////////////////////////////////////////

/// Shared logic for macros that want to generate a `toJsonSupabase` method.
mixin _ToJsonSupabase on _Shared {
  /// Builds the actual `toJsonSupabase` method.
  Future<void> _buildToJsonSupabase(
      ClassDeclaration clazz,
      TypeDefinitionBuilder typeBuilder,
      _SharedIntrospectionData introspectionData) async {
    final methods = await typeBuilder.methodsOf(clazz);
    final toJsonSupabase =
    methods.firstWhereOrNull((c) => c.identifier.name == 'toJsonSupabase');
    if (toJsonSupabase == null) return;
    if (!(await _checkValidToJsonSupabase(toJsonSupabase, introspectionData, typeBuilder))) {
      return;
    }

    final builder = await typeBuilder.buildMethod(toJsonSupabase.identifier);

    // If extending something other than `Object`, it must have a `toJsonSupabase`
    // method.
    var superclassHasToJsonSupabase = false;
    final superclassDeclaration = introspectionData.superclass;
    if (superclassDeclaration != null &&
        !superclassDeclaration.isExactly('Object', _dartCore)) {
      final superclassMethods = await builder.methodsOf(superclassDeclaration);
      for (final superMethod in superclassMethods) {
        if (superMethod.identifier.name == 'toJsonSupabase') {
          if (!(await _checkValidToJsonSupabase(
              superMethod, introspectionData, builder))) {
            return;
          }
          superclassHasToJsonSupabase = true;
          break;
        }
      }
      if (!superclassHasToJsonSupabase) {
        builder.report(Diagnostic(
            DiagnosticMessage(
                'Serialization of classes that extend other classes is only '
                    'supported if those classes have a valid '
                    '`Map<String, Object?> toJsonSupabase()` method.',
                target: introspectionData.clazz.superclass?.asDiagnosticTarget),
            Severity.error));
        return;
      }
    }

    final fields = introspectionData.fields;
    final parts = <Object>[
      '{\n    final json = ',
      if (superclassHasToJsonSupabase)
        'super.toJsonSupabase()'
      else ...[
        '<',
        introspectionData.stringCode,
        ', ',
        introspectionData.objectCode.asNullable,
        '>{}',
      ],
      ';\n    ',
    ];

    Future<Code> addEntryForField(FieldDeclaration field) async {
      final parts = <Object>[];
      final doNullCheck = field.type.isNullable;
      if (doNullCheck) {
        parts.addAll([
          'if (',
          field.identifier,
          // `null` is a reserved word, we can just use it.
          ' != null) {\n      ',
        ]);
      }
      parts.addAll([
        "json[r'",
        field.identifier.name,
        "'] = ",
        await _convertTypeToJsonSupabase(
            field.type,
            RawCode.fromParts([
              field.identifier,
              if (doNullCheck) '!',
            ]),
            builder,
            introspectionData),
        ';\n    ',
      ]);
      if (doNullCheck) {
        parts.add('}\n    ');
      }
      return RawCode.fromParts(parts);
    }

    parts.addAll(await Future.wait(fields.map(addEntryForField)));

    parts.add('return json;\n  }');

    builder.augment(FunctionBodyCode.fromParts(parts));
  }

  /// Emits an error [Diagnostic] if there is an existing `toJsonSupabase` method on
  /// [clazz].
  ///
  /// Returns `true` if the check succeeded (there was no `toJsonSupabase`) and false
  /// if it didn't (a diagnostic was emitted).
  Future<bool> _checkNoToJsonSupabase(
      DeclarationBuilder builder, ClassDeclaration clazz) async {
    final methods = await builder.methodsOf(clazz);
    final toJsonSupabase =
    methods.firstWhereOrNull((m) => m.identifier.name == 'toJsonSupabase');
    if (toJsonSupabase != null) {
      builder.report(Diagnostic(
          DiagnosticMessage(
              'Cannot generate a toJsonSupabase method due to this existing one.',
              target: toJsonSupabase.asDiagnosticTarget),
          Severity.error));
      return false;
    }
    return true;
  }

  /// Checks that [method] is a valid `toJsonSupabase` method, and throws a
  /// [DiagnosticException] if not.
  Future<bool> _checkValidToJsonSupabase(
      MethodDeclaration method,
      _SharedIntrospectionData introspectionData,
      DefinitionBuilder builder) async {
    if (method.namedParameters.isNotEmpty ||
        method.positionalParameters.isNotEmpty ||
        !(await (await builder.resolve(method.returnType.code))
            .isExactly(introspectionData.jsonMapType))) {
      builder.report(Diagnostic(
          DiagnosticMessage(
              'Expected no parameters, and a return type of '
                  'Map<String, Object?>',
              target: method.asDiagnosticTarget),
          Severity.error));
      return false;
    }
    return true;
  }

  /// Returns a [Code] object which is an expression that converts an instance
  /// of type [type] (referenced by [valueReference]) into a JSON map.
  Future<Code> _convertTypeToJsonSupabase(
      TypeAnnotation rawType,
      Code valueReference,
      DefinitionBuilder builder,
      _SharedIntrospectionData introspectionData) async {
    final type = _checkNamedType(rawType, builder);
    if (type == null) {
      return RawCode.fromString(
          "throw 'Unable to serialize type ${rawType.code.debugString}'");
    }

    // Follow type aliases until we reach an actual named type.
    var classDecl = await type.classDeclaration(builder);
    if (classDecl == null) {
      return RawCode.fromString(
          "throw 'Unable to serialize type ${type.code.debugString}'");
    }

    var nullCheck = type.isNullable
        ? RawCode.fromParts([
      valueReference,
      // `null` is a reserved word, we can just use it.
      ' == null ? null : ',
    ])
        : null;

    // Check for the supported core types, and serialize them accordingly.
    if (classDecl.library.uri == _dartCore) {
      switch (classDecl.identifier.name) {
        case 'List' || 'Set':
          return RawCode.fromParts([
            if (nullCheck != null) nullCheck,
            '[ for (final item in ',
            valueReference,
            ') ',
            await _convertTypeToJsonSupabase(type.typeArguments.single,
                RawCode.fromString('item'), builder, introspectionData),
            ']',
          ]);
        case 'Map':
          return RawCode.fromParts([
            if (nullCheck != null) nullCheck,
            '{ for (final ',
            introspectionData.mapEntry,
            '(:key, :value) in ',
            valueReference,
            '.entries) key: ',
            await _convertTypeToJsonSupabase(type.typeArguments.last,
                RawCode.fromString('value'), builder, introspectionData),
            '}',
          ]);
        case 'int' || 'double' || 'num' || 'String' || 'bool':
          return valueReference;
      }
    }

    // Next, check if it has a `toJsonSupabase()` method and call that.
    final methods = await builder.methodsOf(classDecl);
    final toJsonSupabase = methods
        .firstWhereOrNull((c) => c.identifier.name == 'toJsonSupabase')
        ?.identifier;
    if (toJsonSupabase != null) {
      return RawCode.fromParts([
        if (nullCheck != null) nullCheck,
        valueReference,
        '.toJsonSupabase()',
      ]);
    }

    // Unsupported type, report an error and return valid code that throws.
    builder.report(Diagnostic(
        DiagnosticMessage(
            'Unable to serialize type, it must be a native JSON type or a '
                'type with a `Map<String, Object?> toJsonSupabase()` method.',
            target: type.asDiagnosticTarget),
        Severity.error));
    return RawCode.fromString(
        "throw 'Unable to serialize type ${type.code.debugString}'");
  }

  /// Declares a `toJsonSupabase` method in [clazz], if one does not exist already.
  Future<void> _declareToJsonSupabase(
      ClassDeclaration clazz,
      MemberDeclarationBuilder builder,
      NamedTypeAnnotationCode mapStringObject) async {
    if (!(await _checkNoToJsonSupabase(builder, clazz))) return;
    builder.declareInType(DeclarationCode.fromParts([
      // TODO(language#3580): Remove/replace 'external'?
      '  external ',
      mapStringObject,
      ' toJsonSupabase();',
    ]));
  }
}

/// This data is collected asynchronously, so we only want to do it once and
/// share that work across multiple locations.
final class _SharedIntrospectionData {
  /// The declaration of the class we are generating for.
  final ClassDeclaration clazz;

  /// All the fields on the [clazz].
  final List<FieldDeclaration> fields;

  /// A [Code] representation of the type [List<Object?>].
  final NamedTypeAnnotationCode jsonListCode;

  /// A [Code] representation of the type [Map<String, Object?>].
  final NamedTypeAnnotationCode jsonMapCode;

  /// The resolved [StaticType] representing the [Map<String, Object?>] type.
  final StaticType jsonMapType;

  /// The resolved identifier for the [MapEntry] class.
  final Identifier mapEntry;

  /// A [Code] representation of the type [Object].
  final NamedTypeAnnotationCode objectCode;

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
    required this.objectCode,
    required this.stringCode,
    required this.superclass,
  });

  static Future<_SharedIntrospectionData> build(
      DeclarationPhaseIntrospector builder, ClassDeclaration clazz) async {
    final (list, map, mapEntry, object, string) = await (
    builder.resolveIdentifier(_dartCore, 'List'),
    builder.resolveIdentifier(_dartCore, 'Map'),
    builder.resolveIdentifier(_dartCore, 'MapEntry'),
    builder.resolveIdentifier(_dartCore, 'Object'),
    builder.resolveIdentifier(_dartCore, 'String'),
    ).wait;
    final objectCode = NamedTypeAnnotationCode(name: object);
    final nullableObjectCode = objectCode.asNullable;
    final jsonListCode = NamedTypeAnnotationCode(name: list, typeArguments: [
      nullableObjectCode,
    ]);
    final jsonMapCode = NamedTypeAnnotationCode(name: map, typeArguments: [
      NamedTypeAnnotationCode(name: string),
      nullableObjectCode,
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
      objectCode: objectCode,
      stringCode: stringCode,
      superclass: superclassDecl as ClassDeclaration?,
    );
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) compare) {
    for (final item in this) {
      if (compare(item)) return item;
    }
    return null;
  }
}

extension _IsExactly on TypeDeclaration {
  /// Cheaper than checking types using a [StaticType].
  bool isExactly(String name, Uri library) =>
      identifier.name == name && this.library.uri == library;
}

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
