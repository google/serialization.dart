// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Very simple models used for testing the transformer that generates
/// serialization rules.
library test_models;

class Thing {
  int howMany;
  String name;
  List<String> things;
}

class OtherThing {
  int a, b;
  var c;
  Map map;
}