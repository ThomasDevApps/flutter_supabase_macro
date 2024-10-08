import 'dart:async';

import 'package:flutter_supabase_macro/flutter_supabase_macro.dart';
import 'package:macros/macros.dart';

macro class FlutterSupabaseMacro implements ClassDeclarationsMacro, ClassDefinitionMacro {
  const FlutterSupabaseMacro();

  @override
  FutureOr<void> buildDefinitionForClass(
    ClassDeclaration clazz,
    TypeDefinitionBuilder builder
  ) async {

  }

  @override
  FutureOr<void> buildDeclarationsForClass(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder
  ) async {
    await Future.wait([
      AutoConstructor().buildDeclarationsForClass(clazz, builder)
    ]);
  }
  
}