import 'package:flutter_supabase_macro/flutter_supabase_macro.dart';
import 'package:flutter_test/flutter_test.dart';

@FlutterSupabaseMacro()
class TestMacro {
  final String id;
}

void main() {
  test('a', () {
    final test = TestMacro(id: 'daa');
  });
}
