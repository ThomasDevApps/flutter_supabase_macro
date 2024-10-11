<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->
# Flutter Supabase Macro

Package greatly inspired by `JsonCodable` (from Dart), makes it easy to create a JSON format of a template for Supabase.

## 🚀 Getting started

Because the macros are still under development, you need to follow these instructions to be able to test this package : https://dart.dev/language/macros#set-up-the-experiment

Then add in your `pubspec.yaml` : 

```yaml
flutter_supabase_macro:
  git:
    url: https://github.com/ThomasDevApps/flutter_supabase_macro.git
```

## 🔎 How it work
Let's imagine the `User` class :

```dart
class User {
  final String id;
  final String name;
  final int age;

  const User({required this.id, required this.name, required this.age});
}
```
Let's assume that in your Supabase `users` table, the primary key is named `id`.

All you need to do is add the following : 

```dart
@FlutterSupabaseMacro(primaryKey: 'id') // Add this (primaryKey is 'id' by default)
class User {
  // ...
}
```
It will generate a `toJsonSupabase()` method that returns a Map 
that does not contain the `primaryKey` (`id` in this case) : 

```dart
final user = User(id: 'id', name: 'Toto', age: 22);
final json = user.toJsonSupabase(); // Map<String, dynamic>
```

## 📖 Additional information

This package is still undergoing experimentation, and is in no way intended for use in production apps.
