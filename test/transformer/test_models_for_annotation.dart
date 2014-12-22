// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Very simple models used for testing the transformer that generates
/// serialization rules.
library test_models_for_annotation;

import "package:serialization/serialization.dart" show Serializable;

@Serializable()
class Thing {
  int howMany;
  String name;
  List<String> things;
}

@serializable
class OtherThing {
  OtherThing.constructor();
  int a, b;
  var c;
  Map map;
}

@Serializable()
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

class UnAnnotatedThing {
  UnAnnotatedThing.constructor();
  int a, b;
  var c;
  Map map;
}
