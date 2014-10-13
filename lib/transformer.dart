// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library serialization_transformer;

import "package:barback/barback.dart";
import "package:analyzer/analyzer.dart";
import "package:path/path.dart" as path;

/// A transformer for generating [SerializationRule]s. Usage is as follows.
/// In your pubpsec
///      transformers:
///        - serialization :
///          $include: lib/stuff.dart lib/more_stuff.dart
///          format: <lists|maps>
/// For each library 'foo' listed in the $include section this will
/// generate a 'foo\_serialization\_rules.dart' library with serialization
/// rules for those classes.
///
/// The format option should be either 'lists' or 'maps'. If
/// lists, then the generated rule reads and writes lists of all
/// fields where the values must all be present and are expected
/// to be positional in alphabetical order. This is the more efficient
/// format.
/// If maps, then the generated rule reads and writes maps from field
/// names to field values. This format is easier to debug.
///
///  You can use the generated rules by adding them to a [Serialization].
///       import 'package:my_package/stuff_serialization_rules.dart' as foo;
///       ...
///       var serialization = new Serialization();
///       foo.rules.values.forEach(serialization.addRule);
/// For an example, see the example directory in the serialization package.
///
/// Note that right now this is very limited. It can only handle classes
/// with default constructors, will only serialize public fields, and
/// does not handle inheritance.
///
/// The format option should be either 'lists' or 'maps'. If
/// lists, then the generated rule reads and writes lists of all
/// fields where the values must all be present and are expected
/// to be positional in alphabetical order.
/// If maps, then the generated rule reads and writes maps from field
/// names to field values.
class SerializationTransformer extends Transformer {
  BarbackSettings _settings;

  get allowedExtensions => ".dart";

  SerializationTransformer.asPlugin(this._settings);

  apply(Transform t) {
    return t.readInputAsString(t.primaryInput.id).then((contents) {
        var lib = parseCompilationUnit(contents);
        var classes = lib.declarations.where((x) => x is ClassDeclaration);
        var rules = classes
          .map((each) => new _CustomRuleGenerator(each,
              _settings.configuration['format']))
          .toList();
        var fileName = path.withoutExtension(t.primaryInput.id.path);
        var newId =
            new AssetId(t.primaryInput.id.package,
                "${fileName}_serialization_rules.dart");
        var id = t.primaryInput.id;
        // Remove the leading /lib on the file name.
        var fileNameInPackage = path.joinAll(path.split(id.path)..removeAt(0));
        var text = '''
// Generated serialization rules. *** DO NOT EDIT ***
// See transformer.dart in package serialization.
library ${path.basenameWithoutExtension(fileName)}_serialization_rules;

import "package:serialization/serialization.dart";
import "${path.basename(id.path)}";

get rules => {
${rules.map((x) => "    '${x.declaration.name}' : new "
    "${x.ruleName}()").join(",\n")}
};

${rules.map((x) => x.rule).join("\n\n")}

''';
        if (_settings.mode == BarbackMode.DEBUG) {
          print("Generated serialization rules in $newId");
        }
        t.addOutput(new Asset.fromString(newId, text));
      });
  }
}

/// Generates serialization rules for simple classes.
// TODO(alanknight): Generalize to be able to to handle more complex
// cases similarly to BasicRule.
class _CustomRuleGenerator {
  ClassDeclaration declaration;
  String _format;
  List<String> publicFieldNames;

  _CustomRuleGenerator(this.declaration, this._format) {
    publicFieldNames = declaration.members
      .where((each) => each is FieldDeclaration)
      .expand((x) => x.fields.variables)
      .where((each) => !each.name.name.startsWith("_"))
      .map((each) => each.name.name)
      .toList()
      ..sort();
  }

  get listFormat => _format == null || _format == 'lists';
  get collectionStart => listFormat ? '[' : '{';
  get collectionEnd => listFormat ? ']' : '}';
  nameInQuotes(field) => listFormat ? '' : "'$field' : ";
  deref(field) => listFormat ? publicFieldNames.indexOf(field) : "'$field'";

  get targetName => declaration.name.name;
  get ruleName => targetName + 'SerializationRule';

  get header => '''
class $ruleName extends CustomRule {
  bool appliesTo(instance, _) => instance.runtimeType == $targetName;
  create(state) => new $targetName();
  getState(instance) => $collectionStart
''';

  get fields => publicFieldNames
      .map((field) => "    ${nameInQuotes(field)}instance.$field").join(",\n");

  get setFields => publicFieldNames
      .map((field) =>
          "    instance.$field = state[${deref(field)}]").join(";\n");

  get footer => '''$collectionEnd;
  void setState($targetName instance, state) {
$setFields;
  }
}''';

  get rule => """$header$fields$footer""";
}
