// ignore_for_file: deprecated_member_use

part of '../../flutter_supabase_macro.dart';

extension HelperExtensionString on String {
  /// Set the first character to upper case.
  ///
  /// ```dart
  /// 'test of the function'.firstLetterUpperCase(); // 'Test of the function'
  /// ```
  String firstLetterToUpperCase() => "${this[0].toUpperCase()}${substring(1)}";
}

mixin _ToJsonSupabase on _Shared {
  String get primaryKey;

  /// Declare the [_toJsonMethodName] method.
  Future<void> _declareToJsonSupabase(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
    NamedTypeAnnotationCode mapStringObject,
  ) async {
    // Check that no toJsonSupabase method exist
    final checkNoToJson = await _checkNoToJson(builder, clazz);
    if (!checkNoToJson) return;
    final boolId = await builder.resolveIdentifier(_dartCore, 'bool');
    final boolCode = NamedTypeAnnotationCode(name: boolId);
    final fields = await builder.fieldsOf(clazz);
    builder.declareInType(
      DeclarationCode.fromParts([
        '  external ',
        mapStringObject,
        ' $_toJsonMethodName(',
        if (fields.isNotEmpty) '{\n',
        if (fields.isNotEmpty) ..._createNamedParams(boolCode, fields),
        if (fields.isNotEmpty) '\n  }',
        ');\n'
      ]),
    );
  }

  /// Create `List` of parts.
  ///
  /// Example : [fields] contain one element named `firstField`, it will add :
  /// ```dart
  /// '    bool? removeFirstField,'
  /// ```
  List _createNamedParams(
    NamedTypeAnnotationCode boolCode,
    List<FieldDeclaration> fields,
  ) {
    final list = [];
    for (final field in fields) {
      list.addAll([
        '    ',
        boolCode,
        '? ',
        'remove',
        field.identifier.name.firstLetterToUpperCase(),
        ',',
        if (field != fields.last) '\n',
      ]);
    }
    return list;
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

    // Initialize the map to return
    final parts = _initializeMap(introspectionData,
        superclassHasToJson: superclassHasToJson);

    // Get all fields
    final fields = introspectionData.fields;
    // Add entry for each fields
    parts.addAll(
      await Future.wait(
        fields.map(
          (field) => addEntryForField(
            field,
            builder,
            introspectionData,
          ),
        ),
      ),
    );

    parts.add('return json;\n  }');
    builder.augment(
      FunctionBodyCode.fromParts(parts),
      docComments: _createDocumentationForMethod(fields),
    );
  }

  /// Create the documentation for [_toJsonMethodName] method
  /// according with [fields].
  CommentCode _createDocumentationForMethod(List<FieldDeclaration> fields) {
    return CommentCode.fromParts([
      '  /// Map representing the model in json format for Supabase.\n',
      '  ///\n',
      '  /// The primary key [${fields.first.identifier.name}]',
      ' is exclude from the map if empty.\n',
      '  ///\n',
      '  /// ',
      ...fields.map((f) {
        return [
          '[remove',
          f.identifier.name.firstLetterToUpperCase(),
          ']',
          if (f != fields.last) ', '
        ].join();
      }),
      ' can be set for remove field\n'
          '  /// from the json.'
    ]);
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

  /// Check that [method] is a valid `toJsonSupabase` method, throws a
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
    if (!methodIsMap) {
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

  /// Initialize the map to return.
  ///
  /// Two cases are handled according with [superclassHasToJson].
  ///
  /// If [superclassHasToJson] is true :
  /// ```dart
  /// {
  ///   final json = super.toJsonSupabase();
  ///
  /// ```
  ///
  /// Otherwise :
  /// ```dart
  /// {
  ///   final json = <String, dynamic>{};
  ///
  /// ```
  ///
  /// (The last `}` is voluntarily omitted)
  List<Object> _initializeMap(
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

  /// Create JSON entries for [field].
  ///
  /// Example : for a field named `age`, the entry will be :
  ///
  /// ```dart
  /// if (age != null) { // Only if the field is nullable.
  ///   json[r'"age"'] = age!; // ! present only if the field is nullable by default.
  /// } // Only if the field is nullable.
  /// ```
  ///
  /// If `age` is a `String` and [isPrimaryKey] is true, then `age.isNotEmpty`
  /// will be added in the definition of the condition.
  Future<Code> addEntryForField(
    FieldDeclaration field,
    DefinitionBuilder builder,
    _SharedIntrospectionData introspectionData,
  ) async {
    final parts = <Object>[];
    final isPrimaryKey = field.identifier.name == primaryKey;
    final doNullCheck = field.type.isNullable;
    final needCondition = doNullCheck || isPrimaryKey;
    // Begin the definition of the condition
    final t = field.identifier.name.firstLetterToUpperCase();
    parts.addAll(['if (remove$t==null || !remove$t) {\n      ']);
    if (needCondition) {
      parts.addAll(['if (']);
    }
    // Check that the field is not null
    if (doNullCheck) parts.addAll([field.identifier, ' != null']);
    // Check that the field is not empty (if String)
    if (isPrimaryKey) {
      final type = _checkNamedType(field.type, builder);
      if (type != null) {
        parts.addAll([
          if (doNullCheck) ' && ',
          if (type.identifier.name == 'String')
            '${field.identifier.name}.isNotEmpty',
        ]);
      }
    }
    // Close definition of the condition and open it
    if (needCondition) parts.add(') {\n       ');
    // Add the field in the json
    parts.addAll([
      "json[r'",
      field.identifier.name,
      "'] = ",
      await _serializeValue(
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
    // Close the condition
    if (needCondition) {
      parts.add('  }\n    ');
    }
    parts.add('}\n    ');
    return RawCode.fromParts(parts);
  }

  /// Serialize the [valueReference] according with the [rawType].
  Future<Code> _serializeValue(
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
    final typeSerialized = await _serializeValueAccordingType(
        type,
        classDeclaration,
        nullCheck,
        valueReference,
        builder,
        introspectionData);
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
      "throw 'Unable to serialize type ${type.code.debugString}';",
    );
  }

  /// Function to serialize [valueReference] according with the
  /// [classDeclaration] identifier's name.
  ///
  /// Currently `List`, `Set`, `Map`, `int`, `double`, `num`,
  /// `String`, `bool` are handled.
  Future<Code?> _serializeValueAccordingType(
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
            await _serializeValue(type.typeArguments.single,
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
            await _serializeValue(type.typeArguments.last,
                RawCode.fromString('value'), builder, introspectionData),
            '}',
          ]);
        case 'int' || 'double' || 'num' || 'String' || 'bool':
          return valueReference;
      }
    }
    return null;
  }

  /// Returns [_toJsonMethodName] from the class (if exist).
  /// Returns null otherwise.
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
