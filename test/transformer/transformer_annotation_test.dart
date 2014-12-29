// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library transformer_test;

import "test_models_for_annotation.dart";
import "package:serialization/serialization.dart";
import "package:unittest/unittest.dart";

part "transformer_test_core.dart";

specificTests(serialization1, serialization2) {
  test("Verify that there is no serializtion rule for the un-annotated class",
      () {
    var written = Serialization.automaticRules[UnAnnotatedThing];
    expect(written, null);
  });
}
