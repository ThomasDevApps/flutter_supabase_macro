part of '../../flutter_supabase_macro.dart';

extension _StringExtension on String {
  /// Set the first character to upper case.
  ///
  /// ```dart
  /// 'test of the function'.firstLetterUpperCase(); // 'Test of the function'
  /// ```
  String _firstLetterToUpperCase() => "${this[0].toUpperCase()}${substring(1)}";
}
