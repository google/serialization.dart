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
  OtherThing.constructor();
  int a, b;
  var c;
  Map map;
}

class ThingWithConstructor {
  var _priv;
  var pub;
  var other;
  var _settable;
  ThingWithConstructor(this._priv, this.pub, notAField, [somethingElse]) {
    print("notAField = $notAField");
  }

  get priv => _priv;
  get settable => _settable;
  set settable(x) => _settable = x;
  verifyPrivate(x) => _priv == x;
}

// to test the case in which a map has a null key
class ThingWithMap {
  Map<int, int> m = {null: 1, 10: 11};
}
