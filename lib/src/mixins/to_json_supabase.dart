part of '../supabase_macro.dart';

mixin _ToJsonSupabase on _Shared {
  Future<void> _buildToJsonSupabase(
    ClassDeclaration clazz,
    TypeDefinitionBuilder typeBuilder,
    _SharedIntrospectionData introspectionData,
  ) async {
    final methods = await typeBuilder.methodsOf(clazz);
    final toJsonSupabase = methods.firstWhereOrNull(
      (m) => m.identifier.name == _toJsonMethodName,
    );
    await _initialCheck(toJsonSupabase, typeBuilder, introspectionData);

    final superclassHasToJson =
        await _checkSuperclassHasToJson(introspectionData, typeBuilder);
    if (superclassHasToJson == null) return;

    final parts = _createParts(introspectionData,
        superclassHasToJson: superclassHasToJson);
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
            'Map<String, Object?>',
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
              '`Map<String, Object?> toJson()` method.',
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
        'super.toJson()'
      else ...[
        '<',
        introspectionData.stringCode,
        ', ',
        introspectionData.objectCode.asNullable,
        '>{}',
      ],
      ';\n    ',
    ];
  }

  Future<Code> addEntryForField(FieldDeclaration field) async {
    final parts = <Object>[];
    final doNullCheck = field.type.isNullable;
    if (doNullCheck) {
      parts.addAll([
        'if (',
        field.identifier,
        ' != null) {\n      ',
      ]);
    }
    parts.addAll(["json[r'", field.identifier.name, "'] = ", await _con]);
  }

  Future<Code> _convertTypeToJson(
    TypeAnnotation rawType,
    Code valueReference,
    DefinitionBuilder builder,
    _SharedIntrospectionData introspectionData,
  ) async {
    final type = _checkNamedType(rawType, builder);
    if (type == null) {
      return RawCode.fromString(
        "throw 'Unable to serialize type ${rawType.code.debugString}'",
      );
    }
    // TODO à continuer
  }
}
