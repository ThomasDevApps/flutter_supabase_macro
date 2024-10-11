part of '../supabase_macro.dart';

mixin _ToJsonSupabase on _Shared {
  /// Declare the [_toJsonMethodName] method.
  Future<void> _declareToJsonSupabase(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
    NamedTypeAnnotationCode mapStringObject,
  ) async {
    // Check that no toJsonSupabase method exist
    final checkNoToJson = await _checkNoToJson(builder, clazz);
    if (!checkNoToJson) return;
    builder.declareInType(
      DeclarationCode.fromParts(
        [' external ', mapStringObject, ' $_toJsonMethodName();'],
      ),
    );
  }

  /// Emits an error [Diagnostic] if there is an existing [_toJsonMethodName]
  /// method on [clazz].
  ///
  /// Returns `true` if the check succeeded (there was no `toJson`) and false
  /// if it didn't (a diagnostic was emitted).
  Future<bool> _checkNoToJson(
    DeclarationBuilder builder,
    ClassDeclaration clazz,
  ) async {
    final methods = await builder.methodsOf(clazz);
    final toJsonSupabase =
        methods.firstWhereOrNull((m) => m.identifier.name == _toJsonMethodName);
    if (toJsonSupabase != null) {
      builder.report(
        Diagnostic(
          DiagnosticMessage(
            'Cannot generate a toJson method due to this existing one.',
            target: toJsonSupabase.asDiagnosticTarget,
          ),
          Severity.error,
        ),
      );
      return false;
    }
    return true;
  }

  /// Build the `toJsonSupabase` method.
  ///
  /// - [primaryKey] is the key to remove from the `Map`.
  Future<void> _buildToJsonSupabase(
    ClassDeclaration clazz,
    TypeDefinitionBuilder typeBuilder,
    _SharedIntrospectionData introspectionData,
    String primaryKey,
  ) async {
    // Get all methods of the class
    final methods = await typeBuilder.methodsOf(clazz);
    // Get the toJsonSupabase method (if exist)
    final toJsonSupabase = methods.firstWhereOrNull(
      (m) => m.identifier.name == _toJsonMethodName,
    );
    // Do a initial check
    await _initialCheck(toJsonSupabase, typeBuilder, introspectionData);

    // Get the FunctionDefinitionBuilder
    final builder = await typeBuilder.buildMethod(toJsonSupabase!.identifier);

    // Check that superclass has toJsonSupabase
    final superclassHasToJson =
        await _checkSuperclassHasToJson(introspectionData, typeBuilder);
    if (superclassHasToJson == null) return;

    // Create different parts
    final parts = _createParts(introspectionData,
        superclassHasToJson: superclassHasToJson);

    // Get all fields
    final fields = introspectionData.fields.where((f) {
      bool canBeAdd = f.identifier.name != primaryKey;
      return canBeAdd;
    });
    parts.addAll(
      await Future.wait(
        fields.map(
          (field) => addEntryForField(
            field,
            builder,
            toJsonSupabase,
            introspectionData,
          ),
        ),
      ),
    );

    parts.add('return json;\n  }');
    builder.augment(FunctionBodyCode.fromParts(parts));
  }

  /// Returns void if [toJsonSupabase] not exist.
  ///
  /// Otherwise it will check that [toJsonSupabase] is valid with [_checkValidToJson].
  /// If it's not the case it will returns void.
  Future<void> _initialCheck(
    MethodDeclaration? toJsonSupabase,
    TypeDefinitionBuilder typeBuilder,
    _SharedIntrospectionData introspectionData,
  ) async {
    if (toJsonSupabase == null) return;
    final methodIsValid = await _checkValidToJson(
      toJsonSupabase,
      introspectionData,
      typeBuilder,
    );
    if (!methodIsValid) return;
  }

  /// Check that [method] is a valid `toJson` method, throws a
  /// [DiagnosticException] if not.
  Future<bool> _checkValidToJson(
    MethodDeclaration method,
    _SharedIntrospectionData introspectionData,
    DefinitionBuilder builder,
  ) async {
    final methodReturnType = await builder.resolve(method.returnType.code);
    final methodIsMap = await methodReturnType.isExactly(
      introspectionData.jsonMapType,
    );
    if (method.namedParameters.isNotEmpty ||
        method.positionalParameters.isNotEmpty ||
        !methodIsMap) {
      builder.report(
        Diagnostic(
          DiagnosticMessage(
            'Expected no parameters, and a return type of '
            'Map<String, dynamic>',
            target: method.asDiagnosticTarget,
          ),
          Severity.error,
        ),
      );
      return false;
    }
    return true;
  }

  /// Check if the superclass (if exist) has a [_toJsonMethodName].
  Future<bool?> _checkSuperclassHasToJson(
    _SharedIntrospectionData introspectionData,
    DefinitionBuilder builder,
  ) async {
    bool superclassHasToJson = false;
    final superclassDeclaration = introspectionData.superclass;
    final superClassIsObject =
        superclassDeclaration?.isExactly('Object', _dartCore);
    if (superclassDeclaration != null && !superClassIsObject!) {
      final superclassMethods = await builder.methodsOf(superclassDeclaration);
      for (final superMethod in superclassMethods) {
        if (superMethod.identifier.name == _toJsonMethodName) {
          final jsonMethodIsValid =
              await _checkValidToJson(superMethod, introspectionData, builder);
          if (!jsonMethodIsValid) return null;
          superclassHasToJson = true;
          break;
        }
      }
      // If the superclass has not a toJsonSupabase method
      if (!superclassHasToJson) {
        builder.report(
          Diagnostic(
            DiagnosticMessage(
              'Serialization of classes that extend other classes is only '
              'supported if those classes have a valid '
              '`Map<String, dynamic> $_toJsonMethodName()` method.',
              target: introspectionData.clazz.superclass?.asDiagnosticTarget,
            ),
            Severity.error,
          ),
        );
        return null;
      }
    }
    return superclassHasToJson;
  }

  // TODO à doc
  List<Object> _createParts(
    _SharedIntrospectionData introspectionData, {
    required bool superclassHasToJson,
  }) {
    return [
      '{\n    final json = ',
      if (superclassHasToJson)
        'super.$_toJsonMethodName()'
      else ...[
        '<',
        introspectionData.stringCode,
        ', ',
        introspectionData.dynamicCode,
        '>{}',
      ],
      ';\n    ',
    ];
  }

  Future<Code> addEntryForField(
    FieldDeclaration field,
    DefinitionBuilder builder,
    MethodDeclaration toJson,
    _SharedIntrospectionData introspectionData,
  ) async {
    final parts = <Object>[];
    final doNullCheck = field.type.isNullable;
    if (doNullCheck) {
      parts.addAll([
        'if (',
        field.identifier,
        ' != null) {\n      ',
      ]);
    }
    parts.addAll([
      "json[r'",
      field.identifier.name,
      "'] = ",
      await _convertTypeToJson(
        field.type,
        RawCode.fromParts([
          field.identifier,
          if (doNullCheck) '!',
        ]),
        builder,
        introspectionData,
      ),
      ';\n    ',
    ]);
    if (doNullCheck) {
      parts.add('}\n    ');
    }
    return RawCode.fromParts(parts);
  }

  // TODO à commenter
  Future<Code> _convertTypeToJson(
    TypeAnnotation rawType,
    Code valueReference,
    DefinitionBuilder builder,
    _SharedIntrospectionData introspectionData,
  ) async {
    // Get the type of rawType
    final type = _checkNamedType(rawType, builder);
    if (type == null) {
      return RawCode.fromString(
        "throw 'Unable to serialize type ${rawType.code.debugString}'",
      );
    }
    // Get the class declaration of the type
    final classDeclaration = await type.classDeclaration(builder);
    if (classDeclaration == null) {
      return RawCode.fromString(
        "throw 'Unable to serialize type ${type.code.debugString}';",
      );
    }
    // Handle if the type is nullable
    final nullCheck = type.isNullable
        ? RawCode.fromParts([
            valueReference,
            ' == null ? null : ',
          ])
        : null;

    // Convert the type to a serialized one
    final typeSerialized = await _serializeType(type, classDeclaration,
        nullCheck, valueReference, builder, introspectionData);
    if (typeSerialized != null) return typeSerialized;

    // Return toJsonSupabase method if already exist
    final toJsonMethod = await _getToJsonMethod(
        classDeclaration, builder, nullCheck, valueReference);
    if (toJsonMethod != null) return toJsonMethod;

    // Unsupported type, report an error and return valid code that throws.
    builder.report(
      Diagnostic(
        DiagnosticMessage(
            'Unable to serialize type, it must be a native JSON type or a '
            'type with a `Map<String, dynamic> toJson()` method.',
            target: type.asDiagnosticTarget),
        Severity.error,
      ),
    );
    return RawCode.fromString(
        "throw 'Unable to serialize type ${type.code.debugString}';");
  }

  /// TODO à doc
  Future<Code?> _serializeType(
    NamedTypeAnnotation type,
    ClassDeclaration classDeclaration,
    RawCode? nullCheck,
    Code valueReference,
    DefinitionBuilder builder,
    _SharedIntrospectionData introspectionData,
  ) async {
    if (classDeclaration.library.uri == _dartCore) {
      switch (classDeclaration.identifier.name) {
        case 'List' || 'Set':
          return RawCode.fromParts([
            if (nullCheck != null) nullCheck,
            '[ for (final item in ',
            valueReference,
            ') ',
            await _convertTypeToJson(type.typeArguments.single,
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
            '.entries) key:',
            await _convertTypeToJson(type.typeArguments.last,
                RawCode.fromString('value'), builder, introspectionData),
            '}',
          ]);
        case 'int' || 'double' || 'num' || 'String' || 'bool':
          return valueReference;
      }
    }
    return null;
  }

  // TODO à commenter
  Future<Code?>? _getToJsonMethod(
    ClassDeclaration classDeclaration,
    DefinitionBuilder builder,
    RawCode? nullCheck,
    Code valueReference,
  ) async {
    final methods = await builder.methodsOf(classDeclaration);
    final toJson = methods
        .firstWhereOrNull((m) => m.identifier.name == _toJsonMethodName)
        ?.identifier;
    if (toJson != null) {
      return RawCode.fromParts([
        if (nullCheck != null) nullCheck,
        valueReference,
        '.$_toJsonMethodName()'
      ]);
    }
    return null;
  }
}
