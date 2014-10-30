// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library transformer_test;

import "package:serialization/serialization.dart";
import "test_models_for_maps.dart";
import "test_models_for_maps_serialization_rules.dart";
import "package:unittest/unittest.dart";

part "transformer_test_core.dart";

formatSpecificTests(serialization1, serialization2) {
  test("Verify that we are actually writing in map format", () {
    var written = serialization1.write(thing1);
    expect(written is Map, isTrue);
    expect(written['name'], 'thing1');
  });
}