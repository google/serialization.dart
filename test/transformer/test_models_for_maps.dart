// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Very simple models used for testing the transformer that generates
/// serialization rules. This is identical to test_models.dart, but
/// we want the transformer to generate map format for it.
library test_models_for_maps;

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

/// Exercise a DateTime which we want to represent in a string format for
/// external consumption.
class ThingWithDate {
  String s;
  DateTime d;
}
