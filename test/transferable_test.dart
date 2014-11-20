// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library transferable_test;

import 'package:unittest/unittest.dart';
import 'package:serialization/serialization.dart';
import 'dart:typed_data';
import 'dart:html';

class Something {
  String name;
  List<Something> children = [];
}

class SomethingRule extends CustomRule {
  appliesTo(x, _) => x is Something;
  getState(instance) => [instance.name, instance.children];
  create(state) => new Something();
  setState(instance, state) {
      instance.name = state[0];
      instance.children = state[1];
  }
}


void main() {
  test('Serialize to a transferable Uint32List', () {
    var something = new Something()..name = 'One';
    var somethingElse = new Something()..name = 'Two';
    something.children.add(somethingElse);
    var s = new Serialization(format: const TypedListFormat())
        ..addRule(new SomethingRule());
    var bytes = s.write(something);
    expect(bytes is Uint32List, isTrue);
    var s2 = new Serialization(format: const TypedListFormat())
        ..addRule(new SomethingRule());
    var read = s2.read(bytes);
    expect(read.name, 'One');
    expect(read.children.first.name, 'Two');
    expect(read.children.length, 1);
    expect(read.children.first.children.length, 0);
    testTransfer(bytes);


  });
}

testTransfer(bytes) {
  if (!Platform.supportsTypedData) {
      return null;
   }
  // How to exercise this?
}
