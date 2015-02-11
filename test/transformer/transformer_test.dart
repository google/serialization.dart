// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library transformer_test;

import "package:serialization/serialization.dart";
import "test_models.dart";
import "test_models_serialization_rules.dart";
import "package:unittest/unittest.dart";

part "transformer_test_core.dart";

formatSpecificTests(serialization1, serialization2) {
  test("Verify that we are actually writing in simple JSON format as a list",
      () {
    var writer = serialization1.newWriter()..selfDescribing = false;
    var written = writer.write(thing1);
    expect(written is List, isTrue);
    expect(written[1], 'thing1');
  });
}