import 'package:collection/collection.dart';
import 'package:macros/macros.dart';

////////////////////////////////////////////////////////////////////////////////

class _CustomConstructor {
  final String name;
  final List<Object> params;
  final MethodDeclaration? superConstructor;

  const _CustomConstructor(this.name, this.params, this.superConstructor);

  List<Object> toParts() {
    bool hasParams = params.isNotEmpty;
    List<Object> parts = [
      // Don't use the identifier here because it should just be the raw name.
      name,
      '(',
      if (hasParams) '{',
      ...params,
      if (hasParams) '}',
      ')',
    ];
    if (superConstructor != null) {
      parts.addAll([' : super(']);
      for (var param in superConstructor!.positionalParameters) {
        parts.add('\n${param.identifier.name},');
      }
      if (superConstructor!.namedParameters.isNotEmpty) {
        for (var param in superConstructor!.namedParameters) {
          parts.add('\n${param.identifier.name}: ${param.identifier.name},');
        }
      }
      parts.add(')');
    }
    parts.add(';');
    return parts;
  }
}

////////////////////////////////////////////////////////////////////////////////

macro class AutoConstructor implements ClassDeclarationsMacro {
  const AutoConstructor();

  @override
  Future<void> buildDeclarationsForClass(
      ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    var constructors = await builder.constructorsOf(clazz);
    if (constructors.any((c) => c.identifier.name == '')) {
      throw ArgumentError(
          'Cannot generate an unnamed constructor because one already exists');
    }

    var params = <Object>[];
    // Add all the fields of `declaration` as named parameters.
    var fields = await builder.fieldsOf(clazz);
    if (fields.isNotEmpty) {
      for (var field in fields) {
        var requiredKeyword = field.type.isNullable ? '' : 'required ';
        params.addAll(['\n$requiredKeyword', field.identifier, ',']);
      }
    }

    // The object type from dart:core.
    var objectType = await builder.resolve(NamedTypeAnnotationCode(
        name:
        // ignore: deprecated_member_use
        await builder.resolveIdentifier(Uri.parse('dart:core'), 'Object')));

    // Add all super constructor parameters as named parameters.
    var superclass = clazz.superclass == null
        ? null
        : await builder.typeDeclarationOf(clazz.superclass!.identifier);
    var superType = superclass == null
        ? null
        : await builder
        .resolve(NamedTypeAnnotationCode(name: superclass.identifier));
    MethodDeclaration? superconstructor;
    if (superType != null && (await superType.isExactly(objectType)) == false) {
      superconstructor = (await builder.constructorsOf(superclass!))
          .firstWhereOrNull((c) => c.identifier.name == '');
      if (superconstructor == null) {
        throw ArgumentError(
            'Super class $superclass of $clazz does not have an unnamed '
                'constructor');
      }
      // We convert positional parameters in the super constructor to named
      // parameters in this constructor.
      for (var param in superconstructor.positionalParameters) {
        var requiredKeyword = param.isRequired ? 'required' : '';
        params.addAll([
          '\n$requiredKeyword',
          param.type.code,
          ' ${param.identifier.name},',
        ]);
      }
      for (var param in superconstructor.namedParameters) {
        var requiredKeyword = param.isRequired ? '' : 'required ';
        params.addAll([
          '\n$requiredKeyword',
          param.type.code,
          ' ${param.identifier.name},',
        ]);
      }
    }

    // Create custom constructors
    final customConstructors = _createConstructors(
      constructorsName: [
        clazz.identifier.name,
      ],
      params: params,
      superConstructor: superconstructor,
    );
    // Declare each constructor
    for(var customConstructor in customConstructors) {
      builder.declareInType(
        DeclarationCode.fromParts(customConstructor.toParts())
      );
    }
  }


  List<_CustomConstructor> _createConstructors({
    required List<String> constructorsName,
    required List<Object> params,
    MethodDeclaration? superConstructor,
  }) {
    return constructorsName.map((name) {
      return _CustomConstructor(name, params, superConstructor);
    }).toList();
  }
}