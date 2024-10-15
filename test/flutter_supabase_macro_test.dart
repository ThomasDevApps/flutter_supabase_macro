import 'package:flutter_supabase_macro/flutter_supabase_macro.dart';
import 'package:flutter_test/flutter_test.dart';

@FlutterSupabaseMacro(primaryKey: 'id')
class User {
  final String id;
  final String name;
  final int age;

  const User({required this.id, required this.name, required this.age});
}

void main() {
  test('Test that id is missing from the json because is empty', () {
    final user = User(id: '', name: 'Toto', age: 22);
    final json = user.toJsonSupabase();

    expect(json.keys.length, 2);
    expect(json['name'], 'Toto');
    expect(json['age'], 22);
  });

  test('Test that id is NOT missing from the json because is NOT empty', () {
    final user = User(id: 'id-123', name: 'Toto', age: 22);
    final json = user.toJsonSupabase();

    expect(json.keys.length, 3);
    expect(json['id'], 'id-123');
    expect(json['name'], 'Toto');
    expect(json['age'], 22);
  });
}
