// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of transformer_test;

var thing1 = new Thing()
  ..name = "thing1"
  ..howMany = 42
  ..things = ["one", "two", "three"];

var thing2 = new OtherThing.constructor()
  ..a = 1
  ..b = 2
  ..c = {"something" : "orother"}
  ..map = {"a" : "A"};

var constructor =
    new ThingWithConstructor("a", "b", "whatever")..settable = "c"..other = "d";

Format format = const SimpleJsonFormat(storeRoundTripInfo: true);

main() {
  // Create separate serializations for reading and writing to make sure
  // nothing relies on common state.
  var serialization1 = new Serialization(format: format);
  var serialization2 = new Serialization(format: format);

  specificTests(serialization1, serialization2);

  test("Write and Read Thing", () {
    var written = serialization1.write(thing1);
    var read = serialization2.read(written);
    expect(read is Thing, isTrue);
    expect(read.name, "thing1");
    expect(read.howMany, 42);
    expect(read.things, ["one", "two", "three"]);
  });

  test("Write and Read Other Thing", () {
    var written = serialization1.write(thing2);
    var read = serialization2.read(written);
    expect(read is OtherThing, isTrue);
    expect(read.a, 1);
    expect(read.b, 2);
    expect(read.c, {"something" : "orother"});
    expect(read.map, {"a" : "A"});
  });

  test("Nested", () {
    var nested = new Thing()
      ..name = "nested"
      ..howMany = 1
      ..things = [thing1, thing2];
    var written = serialization1.write(nested);
    var read = serialization2.read(written);
    expect(read.things.first is Thing, isTrue);
    expect(read.things.last is OtherThing, isTrue);
    expect(read.things.first.name, "thing1");
    expect(read.things.last.map, {"a" : "A"});
  });

  test("Constructor", () {
    var written = serialization1.write(constructor);
    var read = serialization2.read(written);
    expect(read is ThingWithConstructor, isTrue);
    expect(read.pub, "b");
    expect(read.other, "d");
    expect(read.settable, "c");
    expect(read.verifyPrivate("a"), isTrue);
  });
}
