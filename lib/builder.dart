import 'package:build/build.dart';
import 'package:flutter_fast_generators/src/dao_generator.dart';
import 'package:flutter_fast_generators/src/pref_generator.dart';
import 'package:flutter_fast_generators/src/queryable_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:flutter_fast_generators/src/bloc_event_state_generator.dart';

Builder generateBlocs(BuilderOptions options) =>
    SharedPartBuilder([BlocEventStateGenerator()], 'bloc_event_state_generator');

Builder generatePrefs(BuilderOptions options) => SharedPartBuilder([PrefGenerator()], 'pref_generator');

Builder generateDaos(BuilderOptions options) => SharedPartBuilder([DaoGenerator()], 'dao_generator');

Builder generateQueryables(BuilderOptions options) => SharedPartBuilder([QueryableGenerator()], 'queryable_generator');
