// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// An example/utility program that generates the serialization rules
/// for test_models standalone rather than
/// using the transformer. Useful for debugging the transformer, or as
/// a model if you want to generate the rules and modify them or use them
/// as examples. See the comment for transformer.dart for more details.
library generate_standalone;

import "dart:io";
import "package:serialization/src/custom_rule_generator.dart";

main() {
  var contents = new File("test_models.dart").readAsStringSync();
  var generated = generateCustomRulesFor(
      contents,
      listFormat : true,
      libraryName: 'test_models',
      originalImport: 'test_models.dart');
  var outFile = new File("test_models_serialization_rules.dart");
  outFile.writeAsStringSync(generated);

  contents = new File("test_models_for_maps.dart").readAsStringSync();
  generated = generateCustomRulesFor(
      contents,
      listFormat : false,
      libraryName: 'test_models_for_maps',
      originalImport: 'test_models_for_maps.dart');
  outFile = new File("test_models_for_maps_serialization_rules.dart");
  outFile.writeAsStringSync(generated);
}
