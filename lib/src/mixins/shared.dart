// ignore_for_file: deprecated_member_use

part of '../supabase_macro.dart';

/// Shared logic for all macros which run in the declarations phase.
mixin _Shared {
  /// Returns [type] as a [NamedTypeAnnotation] if it is one, otherwise returns
  /// `null` and emits relevant error diagnostics.
  NamedTypeAnnotation? _checkNamedType(TypeAnnotation type, Builder builder) {
    if (type is NamedTypeAnnotation) return type;
    if (type is OmittedTypeAnnotation) {
      builder.report(
        _createDiagnostic(
          type,
          message:
              'Only fields with explicit types are allowed on serializable '
              'classes, please add a type.',
        ),
      );
    } else {
      builder.report(
        _createDiagnostic(
          type,
          message: 'Only fields with named types are allowed on serializable '
              'classes.',
        ),
      );
    }
    return null;
  }

  /// Create a [Diagnostic] according with [type] and [message].
  Diagnostic _createDiagnostic(TypeAnnotation type, {required String message}) {
    return Diagnostic(
      DiagnosticMessage(message, target: type.asDiagnosticTarget),
      Severity.error,
    );
  }

  /// Does some basic validation on [clazz], and shared setup logic.
  ///
  /// Returns a code representation of the [Map<String, Object?>] class.
  Future<NamedTypeAnnotationCode> _setup(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    if (clazz.typeParameters.isNotEmpty) {
      throw DiagnosticException(
        Diagnostic(
          DiagnosticMessage(
            'Cannot be applied to classes with generic type parameters',
          ),
          Severity.error,
        ),
      );
    }

    final (map, string, object) = await (
      builder.resolveIdentifier(_dartCore, 'Map'),
      builder.resolveIdentifier(_dartCore, 'String'),
      builder.resolveIdentifier(_dartCore, 'Object'),
    ).wait;
    return NamedTypeAnnotationCode(
      name: map,
      typeArguments: [
        NamedTypeAnnotationCode(name: string),
        NamedTypeAnnotationCode(name: object).asNullable,
      ],
    );
  }
}
