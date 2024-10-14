part of '../../flutter_supabase_macro.dart';

extension on NamedTypeAnnotation {
  /// Follows the declaration of this type through any type aliases, until it
  /// reaches a [ClassDeclaration], or returns null if it does not bottom out on
  /// a class.
  Future<ClassDeclaration?> classDeclaration(DefinitionBuilder builder) async {
    var typeDeclaration = await builder.typeDeclarationOf(identifier);
    while (typeDeclaration is TypeAliasDeclaration) {
      final aliasedType = typeDeclaration.aliasedType;
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
      typeDeclaration = await builder.typeDeclarationOf(aliasedType.identifier);
    }
    if (typeDeclaration is! ClassDeclaration) {
      builder.report(
        Diagnostic(
          DiagnosticMessage(
            'Only classes are supported as field types for serializable '
            'classes',
            target: asDiagnosticTarget,
          ),
          Severity.error,
        ),
      );
      return null;
    }
    return typeDeclaration;
  }
}
