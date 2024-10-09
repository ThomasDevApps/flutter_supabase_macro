import 'package:flutter_supabase_macro/flutter_supabase_macro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json/json.dart';

@FlutterSupabaseMacro(idLabel: 'id')
class User {
  final String id;
  final String name;
  final int age;

  const User({required this.id, required this.name, required this.age});
}

@JsonCodable()
class Test {}

void main() {
  test('a', () {
    final user = User(id: 'id', name: 'Toto', age: 22);
    final json = user.toJsonSupabase();

    expect(json.keys.length, 2);
    expect(json['name'], 'Toto');
    expect(json['age'], 22);
  });
}
