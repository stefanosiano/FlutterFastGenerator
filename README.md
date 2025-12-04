<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

Flutter Fast (**F**lutter **A**pp **S**implified developmen**T**) - Annotation Generators

This is the code generation part of [Flutter Fast](https://github.com/stefanosiano/FlutterFast).

Note:  
While this library should be safe to use, it has not been properly released and lacks tests, and it's still considered work in progress.

## Features


### BLoC generator: (BlocEventStateGenerator)
Annotation: `@BlocEventState`

Generate Provider, Event and State class to be used in a Bloc. It also generates a series of event classes and static methods to instantiate them.

```dart
@BlocEventState('My', [
  BlocEventDetail('increment', params: {Param<int>('by')}),
  BlocEventDetail('reset'),
], state: {
  Param<int>('counter'),
})
class MyBloc extends FastBloc<MyEvent, MyState> {
  MyBloc._() : super(MyState.create(counter: 0)) {
    // Bloc setup
  }
}

// Generated (conceptual):
// - MyBlocProvider extends FastBlocProvider<MyBloc, MyState>
// - MyEvent sealed class with static factories like `MyEvent.increment({required int by})`
// - concrete Event classes: `Increment`, `Reset`
// - MyState with `create` and `copyWith`
```


### Preferences generator: (PrefGenerator)
Annotation: `@Pref`

Generates a `PreferencesRepository` that instantiates annotated preference manager classes, load/save APIs, typed get/save methods, and stream/subscribe helpers for each declared FastPreference.
Handles deferred loading and registration of preferences.


```dart
@Pref(fileName: 'app_prefs.json', logEverything: false)
class AppPreferences extends FastPreferenceManager {
  final FastPreference<int> counter = FastPreference<int>('counter', defaultValue: 0);
  final FastPreference<String?> username = FastPreference<String?>('username', defaultValue: null, deferLoad: true);
}

// Generated (conceptual):
// - PreferencesRepository with methods:
//   - load() to initialize registered preferences
//   - getCounter(), saveCounter(), getCounterStream(onData)
//   - getUsername(), saveUsername(), getUsernameStream(onData)
```


### DAO generator: (DaoGenerator)
Annotation: `@Dao`, `@Query`

Generates: concrete DAO implementation classes, insert helpers, and query implementations that handle raw queries, updates, and streams. Validates method signatures and return types.


```dart
class User {
  final int id;
  final String name;
  User({required this.id, required this.name});
}

@Dao.table(entityClass: User, tableName: 'users')
abstract class UserDao implements FastDao {
  @Query('SELECT * FROM users WHERE id = :id')
  Future<User?> getById(int id);

  @Query('SELECT * FROM users')
  Future<Iterable<User?>> getAll();

  @Query.stream('SELECT * FROM users', tables: ['users'])
  Stream<Iterable<User?>> watchAll();

  @Query.update('UPDATE users SET name = :name WHERE id = :id', updateTable: 'users')
  Future<void> updateName(int id, String name);
}

// Generated (conceptual):
// - _UserDaoImpl extends UserDao with FastDaoMixin (singleton-like pattern)
// - Methods implemented using `db.rawQuery` / `db.rawUpdate` and converters
// - `parseUserFromDb(Map<String, Object?>)` and `parseUserToDb(User)` helpers
// - Convenience helpers for insert/replace if `tableName` provided
```

### Queryable generator: (QueryableGenerator)
Annotation: `@Queryable` and `@QueryableField`

Generates: parsing extension methods to convert DB maps to model instances and vice versa.

```dart
import 'package:flutter_fast/flutter_fast_annotations.dart';

@Queryable(constructorName: '')
class Note implements FastQueryable {
  final int id;
  final String title;
  // store tags as a string in DB; use custom fromDb/toDb helpers
  @QueryableField(fromDb: CustomConverters.fromStringToList, toDb: CustomConverters.fromListToString, columnName: 'tags_json')
  final Iterable<String> tags;

  Note({required this.id, required this.title, required this.tags});
}

class CustomConverters {
  static Iterable<String> fromStringToList(String raw) {
    return (raw.isEmpty) ? [] : (raw.split(','));
  }

  static String fromListToString(Iterable<String> tags) => tags.join(',');
}

// Generated (conceptual):
// Note FastDaoMixinNoteExtension.parseNoteFromDb(Map<String,Object?> map)
// Map<String,Object?> FastDaoMixinNoteExtension.parseNoteToDb(Note data)
```

## Getting started

The library is not published, yet, but can be used via git, by adding it to dev dependencies to your `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_fast_generators:
    git:
      url: https://github.com/stefanosiano/FlutterFastGenerator.git
  build_runner: ^2.4.13 # Use your preferred version
```

Then run the generators:

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```


## Usage

TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder.

```dart
const like = 'sample';
```
