part of '../supabase_macro.dart';

mixin _ToJsonSupabase on _Shared {
  Future<void> _buildToJson(
    ClassDeclaration clazz,
    TypeDefinitionBuilder typeBuilder,
    _SharedIntrospectionData introspectionData,
  ) async {
    final methods = await typeBuilder.methodsOf(clazz);
    final toJsonSupabase = methods.firstWhereOrNull(
      (m) => m.identifier.name == 'toJsonSupabase',
    );
    await _initialCheck(toJsonSupabase, typeBuilder, introspectionData);
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
}
