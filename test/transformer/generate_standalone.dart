// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// An example/utility program that generates the serialization rules
/// for test_models standalone rather than
/// using the transformer. Useful for debugging the transformer, or as
/// a model if you want to generate the rules and modify them or use them
/// as examples. See the comment for transformer.dart for more details.
/// This should be executed from the root of the test folder.
library generate_standalone;

import "dart:io";
import "package:serialization/src/custom_rule_generator.dart";

main() {
  var contents = new File("transformer/test_models.dart").readAsStringSync();
  var results = analyzeAsset(
      contents,
      listFormat : true,
      processAllClasses: true);
  results.setImportStatementFromPath("transformer/test_models.dart");
  var outFile = new File("test_models_serialization_rules.dart");
  String fileCode = generateSerializationRulesFileCode([results]);
  outFile.writeAsStringSync(fileCode);

  contents = new File("transformer/test_models_for_maps.dart")
      .readAsStringSync();
  results = analyzeAsset(
      contents,
      listFormat : false,
      processAllClasses: true);
  results.setImportStatementFromPath("transformer/test_models_for_maps.dart");
  outFile = new File("test_models_for_maps_serialization_rules.dart");
  fileCode = generateSerializationRulesFileCode([results]);
  outFile.writeAsStringSync(fileCode);

  contents = new File("transformer/test_models_for_annotation.dart")
      .readAsStringSync();
  results = analyzeAsset(
      contents,
      listFormat : false,
      processAllClasses: false,
      processAnnotatedClasses: true);
  results.setImportStatementFromPath(
      "transformer/test_models_for_annotation.dart");
  outFile = new File("test_models_for_annotation_serialization_rules.dart");
  fileCode = generateSerializationRulesFileCode([results]);
  outFile.writeAsStringSync(fileCode);
}
